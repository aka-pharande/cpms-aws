# AWS Configuration
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Naming Convention Variables
variable "product_name" {
  description = "Name of the product/application"
  type        = string
  default     = "cpms"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.product_name))
    error_message = "Product name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment_kind" {
  description = "Environment type (dev, stage, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition = contains([
      "dev", "stage", "prod", "test"
    ], var.environment_kind)
    error_message = "Environment kind must be one of: dev, stage, prod, test"
  }
}

variable "component_name" {
  description = "Component name (optional, for specific components within the product)"
  type        = string
  default     = "infra"
  
  validation {
    condition     = var.component_name == "" || can(regex("^[a-z0-9-]+$", var.component_name))
    error_message = "Component name must be empty or contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment_instance" {
  description = "Environment instance identifier (optional, for multiple environments of same kind)"
  type        = string
  default     = ""
  
  validation {
    condition     = var.environment_instance == "" || can(regex("^[a-z0-9-]+$", var.environment_instance))
    error_message = "Environment instance must be empty or contain only lowercase letters, numbers, and hyphens."
  }
}

# EKS Cluster Configuration
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"

  validation {
    condition = contains([
      "1.31", "1.32", "1.33"
    ], var.kubernetes_version)
    error_message = "Kubernetes version must be one of: 1.31, 1.32, 1.33"
  }
}

# Network Configuration
variable "network_config" {
  description = "Network configuration object containing VPC and subnet CIDRs"
  type = object({
    vpc_cidr        = string
    private_subnets = list(string)
    public_subnets  = list(string)
    database_subnets= list(string)
  })
  default = {
    vpc_cidr        = "10.0.0.0/16"
    private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
    database_subnets= ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
  }
  
  validation {
    condition = can(cidrhost(var.network_config.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid CIDR block."
  }
}

variable "availability_zones_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 3
  
  validation {
    condition     = var.availability_zones_count >= 2 && var.availability_zones_count <= 6
    error_message = "Availability zones count must be between 2 and 6."
  }
}

# NAT Gateway Configuration
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

# EKS Cluster Access
variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Enable cluster creator admin permissions"
  type        = bool
  default     = true
}

# Common tags
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "dev"
    Product     = "migrator"
  }
}