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

  enable_nat_gateway   = var.enable_nat_gateway
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

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

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose", "system"]
  }

  access_entries = {
    aakanksha-admin = {
      principal_arn     = "arn:aws:iam::786193448664:user/aakankshaph"
      policy_associations = {
        example = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
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