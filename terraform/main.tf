############################################
# Data source for availability zones
############################################
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

############################################
# Locals (naming, DB defaults, etc.)
############################################
locals {
  # Convert AWS region by dropping hyphens
  region_code = replace(var.aws_region, "-", "")
  rds_devuser = "devuser"
  rds_dbport  = 3306
  rds_dbname  = "HospitalManagement"

  # Build naming components conditionally
  component_part = var.component_name != "" ? "-${var.component_name}" : ""
  instance_part  = var.environment_instance != "" ? "-${var.environment_instance}" : ""

  # Naming convention: <resource_type>-<product>[-<component_name>][-<environment_instance>]-<environment_kind>-<aws_region>
  base_name = "${var.product_name}${local.component_part}${local.instance_part}-${var.environment_kind}-${local.region_code}"

  vpc_name        = "vpc-${local.base_name}"
  cluster_name    = "eks-${local.base_name}"
  node_group_name = "ng-${var.product_name}-main${local.instance_part}-${var.environment_kind}-${local.region_code}"
}

############################################
# VPC
############################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name = local.vpc_name
  cidr = var.network_config.vpc_cidr

  azs              = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_count)
  private_subnets  = var.network_config.private_subnets
  public_subnets   = var.network_config.public_subnets
  database_subnets = var.network_config.database_subnets

  enable_nat_gateway   = var.enable_nat_gateway
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = true

  # Required for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb"                         = 1
    "kubernetes.io/cluster/${local.cluster_name}"    = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                = 1
    "kubernetes.io/cluster/${local.cluster_name}"    = "shared"
  }

  tags = merge(var.tags, {
    Name = local.vpc_name
  })
}

############################################
# Random passwords
############################################
resource "random_password" "rds_master" {
  length  = 24
  special = false
}

resource "random_password" "rds_devuser" {
  length  = 24
  special = false
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

############################################
# RDS Security Group (allows EKS nodes)
############################################
resource "aws_security_group" "rds" {
  name        = "SG-${local.base_name}-rds"
  description = "Allow MySQL from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "MySQL from EKS nodes"
    from_port       = local.rds_dbport
    to_port         = local.rds_dbport
    protocol        = "tcp"
    security_groups = [module.eks.cluster_primary_security_group_id]
  }

  ingress {
    from_port   = local.rds_dbport
    to_port     = local.rds_dbport
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "sg-${local.base_name}-rds"
  })
}

############################################
# RDS (MySQL)
############################################
module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.12.0"

  identifier = "rds-${local.base_name}"

  engine                 = "mysql"
  family                 = "mysql8.0"
  major_engine_version   = "8.0"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 50

  username                      = "admin"
  password                      = random_password.rds_master.result
  port                          = local.rds_dbport
  manage_master_user_password   = false

  multi_az            = false
  monitoring_interval = 0
  publicly_accessible = true
  skip_final_snapshot = true 
  deletion_protection = false

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = module.vpc.database_subnet_group

  tags = merge(var.tags, {
    Name = "rds-${local.base_name}"
  })
}

############################################
# EKS Cluster (with IRSA enabled)
############################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.0.8"

  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  # Cluster access settings
  endpoint_public_access                   = var.endpoint_public_access
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  # IRSA explicit enablement
  enable_irsa = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  addons = var.eks_addons

  eks_managed_node_groups = {
    main = {
      name                       = local.node_group_name
      iam_role_use_name_prefix   = false
      instance_types             = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      disk_size = var.node_disk_size
      ami_type  = var.node_ami_type

      labels = {
        role = "main"
      }

      tags = merge(var.tags, {
        Name = local.node_group_name
      })
    }
  }

  # Adding myself as an admin for testing
  access_entries = {
    aakanksha-admin = {
      principal_arn = "arn:aws:iam::786193448664:user/aakankshaph"
      policy_associations = {
        example = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = merge(var.tags, {
    Name = local.cluster_name
  })
}

############################################
# --- IRSA + S3 for Documents (Integrated) ---
############################################

# Unique suffix so bucket name is globally unique
resource "random_id" "s3" {
  byte_length = 3
}

# ServiceAccount naming for IRSA
locals {
  irsa_sa_namespace = "default"
  irsa_sa_name      = "s3-reader"
  s3_bucket_name    = lower("s3-${local.base_name}-${random_id.s3.hex}")
  s3_bucket_arn     = "arn:aws:s3:::${local.s3_bucket_name}"
  s3_objects_arn    = "${local.s3_bucket_arn}/*"
}

# S3 bucket (private, versioned, SSE, public blocked)
resource "aws_s3_bucket" "docs" {
  bucket        = local.s3_bucket_name
  force_destroy = true
  tags          = merge(var.tags, { Name = local.s3_bucket_name })
}

resource "aws_s3_bucket_versioning" "docs" {
  bucket = aws_s3_bucket.docs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "docs" {
  bucket = aws_s3_bucket.docs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "docs" {
  bucket                  = aws_s3_bucket.docs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id

  cors_rule {
    id = "cpms-docs-cors"
    allowed_methods = ["PUT", "GET", "HEAD"]
    allowed_headers = ["*"]
    allowed_origins = ["https://cpms.aakankshapharande.com", "http://cpms.aakankshapharande.com", "http://localhost"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}


# IRSA trust policy (restrict to one SA + audience)
data "aws_iam_policy_document" "s3_irsa_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${local.irsa_sa_namespace}:${local.irsa_sa_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# S3 bucket-scoped policy (RW on objects, list bucket)
data "aws_iam_policy_document" "s3_rw_policy_doc" {
  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [local.s3_bucket_arn]
  }

  statement {
    sid       = "RWObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [local.s3_objects_arn]
  }
}

resource "aws_iam_policy" "s3_rw_policy" {
  name        = "irsa-${local.base_name}-s3-rw"
  description = "IRSA policy for pods to access ${local.s3_bucket_name}"
  policy      = data.aws_iam_policy_document.s3_rw_policy_doc.json
  tags        = var.tags
}

resource "aws_iam_role" "s3_irsa_role" {
  name               = "irsa-${local.base_name}-s3"
  assume_role_policy = data.aws_iam_policy_document.s3_irsa_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "s3_rw_attach" {
  role       = aws_iam_role.s3_irsa_role.name
  policy_arn = aws_iam_policy.s3_rw_policy.arn
}

# Bucket policy: enforce TLS and allow only IRSA role
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals { 
      identifiers = ["*"]
      type = "*"
      }
    resources = [local.s3_bucket_arn, local.s3_objects_arn]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid     = "AllowIRSAOnly"
    effect  = "Allow"
    actions = ["s3:*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.s3_irsa_role.arn]
    }
    resources = [local.s3_bucket_arn, local.s3_objects_arn]
  }
}

resource "aws_s3_bucket_policy" "docs" {
  bucket = aws_s3_bucket.docs.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

# Kubernetes ServiceAccount annotated with the IRSA role
resource "kubernetes_service_account" "s3_reader" {
  depends_on = [module.eks]

  metadata {
    name      = local.irsa_sa_name
    namespace = local.irsa_sa_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.s3_irsa_role.arn
    }
    labels = {
      "app.kubernetes.io/name" = "s3-reader"
    }
  }
}

############################################
# Kubernetes Secrets (DB creds + app secrets)
############################################
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

resource "kubernetes_secret" "cpms_db_admin" {
  depends_on = [module.eks]

  metadata {
    name      = "cpms-db-admin-secret"
    namespace = "default"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "database-admin"
    }
  }

  data = {
    DB_HOST = module.db.db_instance_address
    DB_PORT = "${local.rds_dbport}"
    DB_NAME = local.rds_dbname
    DB_USER = "admin"
    DB_PASS = random_password.rds_master.result
  }

  type = "Opaque"
}

resource "kubernetes_secret" "cpms_db_secret" {
  depends_on = [module.eks]

  metadata {
    name      = "cpms-db-secret"
    namespace = "default"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "application"
    }
  }

  data = {
    DB_HOST = module.db.db_instance_address
    DB_PORT = "${local.rds_dbport}"
    DB_NAME = local.rds_dbname
    DB_USER = local.rds_devuser
    DB_PASS = random_password.rds_devuser.result
  }

  type = "Opaque"
}

resource "kubernetes_secret" "cpms_patients_secret" {
  depends_on = [module.eks]

  metadata {
    name      = "cpms-patients-secret"
    namespace = "default"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    S3_BUCKET_NAME = aws_s3_bucket.docs.bucket
  }

  type = "Opaque"
}

resource "kubernetes_secret" "cpms_auth_secret" {
  depends_on = [module.eks]

  metadata {
    name      = "cpms-auth-secret"
    namespace = "default"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    JWT_SECRET = random_password.jwt_secret.result
  }

  type = "Opaque"
}

############################################
# DB Init (ConfigMap + SA + Job)
############################################
resource "kubernetes_config_map" "database_init_scripts" {
  depends_on = [module.eks]

  metadata {
    name      = "database-init-scripts"
    namespace = "default"
  }

  data = {
    "01-schema.sql" = file("${path.module}/scripts/schema.sql")

    "02-create-devuser.sql" = <<-EOT
      USE ${local.rds_dbname};

      -- Create devuser with limited privileges
      CREATE USER IF NOT EXISTS '${local.rds_devuser}'@'%' IDENTIFIED BY '${random_password.rds_devuser.result}';
      GRANT SELECT, INSERT, UPDATE, DELETE ON ${local.rds_dbname}.* TO '${local.rds_devuser}'@'%';

      -- Grant DDL operations for migrations (CREATE, ALTER, INDEX, DROP)
      GRANT CREATE, ALTER, INDEX, DROP ON ${local.rds_dbname}.* TO '${local.rds_devuser}'@'%';

      FLUSH PRIVILEGES;

      -- Verify user creation
      SELECT User, Host FROM mysql.user WHERE User = '${local.rds_devuser}';
      SHOW GRANTS FOR '${local.rds_devuser}'@'%';
    EOT

    "03-dummy-data.sql" = file("${path.module}/scripts/dummy_data.sql")
  }
}

resource "kubernetes_service_account" "db_init" {
  depends_on = [module.eks]

  metadata {
    name      = "db-init-service-account"
    namespace = "default"
    labels = {
      "app.kubernetes.io/name" = "database-init"
    }
  }
}

resource "kubernetes_job_v1" "database_init" {
  depends_on = [
    kubernetes_config_map.database_init_scripts,
    kubernetes_secret.cpms_db_admin,
    kubernetes_secret.cpms_db_secret,
    module.db
  ]

  metadata {
    name      = "database-init-${formatdate("YYYYMMDD-hhmm", timestamp())}"
    namespace = "default"
    labels = {
      "app.kubernetes.io/name"       = "database-init"
      "app.kubernetes.io/component"  = "database"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    ttl_seconds_after_finished = 3600
    backoff_limit              = 3

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "database-init"
          "app.kubernetes.io/component" = "database"
        }
      }

      spec {
        restart_policy       = "Never"
        service_account_name = kubernetes_service_account.db_init.metadata[0].name

        init_container {
          name  = "wait-for-db"
          image = "mysql:8.0"

          command = [
            "sh", "-c",
            <<-EOT
            echo "Waiting for database to be ready..."
            until mysql --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASS --execute="SELECT 1" 2>/dev/null; do
              echo "Database not ready, waiting 10 seconds..."
              sleep 10
            done
            echo "Database is ready!"
            EOT
          ]

          env_from {
            secret_ref { name = kubernetes_secret.cpms_db_admin.metadata[0].name }
          }

          resources {
            requests = { memory = "64Mi",  cpu = "50m"  }
            limits   = { memory = "128Mi", cpu = "100m" }
          }
        }

        container {
          name  = "database-setup"
          image = "mysql:8.0"

          command = [
            "sh", "-c",
            <<-EOT
            set -e
            echo "Starting database initialization..."

            for script in /scripts/*.sql; do
              script_name=$(basename "$script")
              echo "Executing $script_name..."
              mysql --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASS < "$script"
              if [ $? -eq 0 ]; then
                echo "✓ $script_name completed successfully"
              else
                echo "✗ $script_name failed"
                exit 1
              fi
            done

            echo "Database initialization completed successfully!"
            echo "Testing devuser connection..."
            mysql --host=$DB_HOST --port=$DB_PORT --user=${local.rds_devuser} --password='${random_password.rds_devuser.result}' --execute="SELECT 'DevUser connection successful' as test;" ${local.rds_dbname}
            echo "All database setup tasks completed!"
            EOT
          ]

          env_from {
            secret_ref { name = kubernetes_secret.cpms_db_admin.metadata[0].name }
          }

          volume_mount {
            name       = "init-scripts"
            mount_path = "/scripts"
            read_only  = true
          }

          resources {
            requests = { memory = "128Mi", cpu = "100m" }
            limits   = { memory = "256Mi", cpu = "200m" }
          }
        }

        volume {
          name = "init-scripts"
          config_map {
            name         = kubernetes_config_map.database_init_scripts.metadata[0].name
            default_mode = "0755"
          }
        }
      }
    }
  }
}

############################################
# Providers (Helm wired to your EKS cluster)
############################################
# You already have a kubernetes provider; this Helm provider mirrors it.
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

locals {
  ingress_nginx_chart_version = "4.11.3" # update as desired
  cert_manager_chart_version  = "v1.14.4" # chart app version
}

############################################
# Namespaces
############################################
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
    labels = {
      "app.kubernetes.io/name" = "ingress-nginx"
    }
  }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
    labels = {
      "app.kubernetes.io/name" = "cert-manager"
    }
  }
}

############################################
# ingress-nginx (Helm)
############################################
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = local.ingress_nginx_chart_version

  # Basic, production-sane defaults
  values = [
    yamlencode({
      controller = {
        replicaCount = 2
        service = {
          type = "LoadBalancer"
        }
        # Watch all namespaces (empty string)
        watchNamespace = ""
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
    })
  ]

  timeout  = 600
  wait     = true
  cleanup_on_fail = true
}

############################################
# cert-manager (Helm) - install CRDs too
############################################
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = local.cert_manager_chart_version

  # Equivalent to: set { name = "installCRDs" value = "true" }
  values = [
    yamlencode({
      installCRDs = true
    })
  ]

  timeout        = 600
  wait           = true
  cleanup_on_fail = true
}