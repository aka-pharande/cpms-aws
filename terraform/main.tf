# Data source for availability zones
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Local values for naming convention
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

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name = local.vpc_name
  cidr = var.network_config.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_count)
  private_subnets = var.network_config.private_subnets
  public_subnets  = var.network_config.public_subnets
  database_subnets= var.network_config.database_subnets

  enable_nat_gateway   = var.enable_nat_gateway
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = true

  # Required for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  tags = merge(var.tags, {
    Name = local.vpc_name
  })
}

# Generate a random password for the RDS master user
resource "random_password" "rds_master" {
  length  = 24
  special = false
}

# Generate a random password for the RDS master user
resource "random_password" "rds_devuser" {
  length  = 24
  special = false
}

# Security group for RDS allowing MySQL from EKS nodes
resource "aws_security_group" "rds" {
  name        = "SG-${local.base_name}-rds"
  description = "Allow MySQL from EKS nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "MySQL from EKS nodes"
    from_port        = local.rds_dbport
    to_port          = local.rds_dbport
    protocol         = "tcp"
    security_groups  = [module.eks.cluster_primary_security_group_id]
  }

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "mysql/aurora"
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

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.12.0"

  identifier = "rds-${local.base_name}"

  engine            = "mysql"
  family            = "mysql8.0"
  major_engine_version = "8.0"
  instance_class    = "db.t4g.micro"
  allocated_storage = 50

  username = "admin"
  password = random_password.rds_master.result
  port     = local.rds_dbport
  manage_master_user_password = false

  multi_az                        = false
  monitoring_interval             = 0
  publicly_accessible             = true
  deletion_protection             = false

  vpc_security_group_ids = [aws_security_group.rds.id]

  db_subnet_group_name = module.vpc.database_subnet_group

  tags = merge(var.tags, {
    Name = "rds-${local.base_name}"
  })
}

# EKS Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.0.8"

  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  # Cluster access settings
  endpoint_public_access                   = var.endpoint_public_access
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # compute_config = {
  #   enabled    = true
  #   node_pools = ["general-purpose", "system"]
  # }

  addons = var.eks_addons
  
  eks_managed_node_groups = {
    main = {
      name           = local.node_group_name
      iam_role_use_name_prefix = false
      instance_types = var.node_instance_types

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

  access_entries = {
    aakanksha-admin = {
      principal_arn     = "arn:aws:iam::786193448664:user/aakankshaph"
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


# Configure Kubernetes provider to use EKS cluster
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Create Kubernetes secrets for database credentials
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
    name      = "cpms-db-secret"  # Same name as your original secret
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

# Your other application secrets (these can stay as-is or also be managed by Terraform)
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
    PORT                         = "3000"
    AZURE_STORAGE_ACCOUNT_NAME   = "stdocumentscpms"
    AZURE_STORAGE_ACCOUNT_KEY    = "Yxr+yM+3tX3HRWgM3R48Xfu3qbGv8GUajM5gbARpboA/k6M9SKrCO7Akiy+T777FaeUpXTe24+g5+AStRjIzVw=="
    AZURE_STORAGE_CONTAINER_NAME = "documents"
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
    JWT_SECRET = "4898b1d752b01754c0c0cafd345f8e0cddfb148d0660e65dfe328e84053d2154154d886eb85dd8d90c93d35ddaef2710b5806b94f5dd9bfc1bea73489db0c7dd"
  }

  type = "Opaque"
}

# ConfigMap with database initialization scripts
resource "kubernetes_config_map" "database_init_scripts" {
  depends_on = [module.eks]
  
  metadata {
    name      = "database-init-scripts"
    namespace = "default"
  }

  data = {
    # Your schema.sql already has CREATE DATABASE, so we'll use it directly
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

# Service account for database initialization job
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

# Database initialization job
resource "kubernetes_job_v1" "database_init" {
  depends_on = [
    kubernetes_config_map.database_init_scripts,
    kubernetes_secret.cpms_db_admin,
    kubernetes_secret.cpms_db_secret,
    module.db  # Ensure RDS is ready
  ]
  
  metadata {
    name      = "database-init-${formatdate("YYYYMMDD-hhmm", timestamp())}"  # Unique name for each run
    namespace = "default"
    labels = {
      "app.kubernetes.io/name"       = "database-init"
      "app.kubernetes.io/component"  = "database"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  spec {
    # Important: Set to 0 so job doesn't get cleaned up immediately
    ttl_seconds_after_finished = 3600  # Keep for 1 hour for debugging
    backoff_limit              = 3     # Retry up to 3 times
    
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
        
        # Wait for database to be ready before starting
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
            secret_ref {
              name = kubernetes_secret.cpms_db_admin.metadata[0].name
            }
          }
          
          resources {
            requests = {
              memory = "64Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "128Mi"
              cpu    = "100m"
            }
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
            
            # Execute all SQL scripts in order
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
            
            # Test connection with devuser to verify it was created
            echo "Testing devuser connection..."
            mysql --host=$DB_HOST --port=$DB_PORT --user=${local.rds_devuser} --password='${random_password.rds_devuser.result}' --execute="SELECT 'DevUser connection successful' as test;" ${local.rds_dbname}
            
            echo "All database setup tasks completed!"
            EOT
          ]
          
          env_from {
            secret_ref {
              name = kubernetes_secret.cpms_db_admin.metadata[0].name
            }
          }
          
          volume_mount {
            name       = "init-scripts"
            mount_path = "/scripts"
            read_only  = true
          }
          
          resources {
            requests = {
              memory = "128Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "256Mi"
              cpu    = "200m"
            }
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

# Optional: Output the job status for monitoring
output "database_init_job_name" {
  description = "Name of the database initialization job"
  value       = kubernetes_job_v1.database_init.metadata[0].name
}

output "database_connection_info" {
  description = "Database connection information"
  value = {
    host     = module.db.db_instance_address
    port     = local.rds_dbport
    database = local.rds_dbname
    # Don't output passwords in logs
  }
  sensitive = false
}