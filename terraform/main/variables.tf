variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-north-1"
}

variable "project" {
  description = "Name prefix and tag value"
  type        = string
  default     = "quickballot"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnets, one per availability zone"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.10.0/24", "10.0.20.0/24"]

  validation {
    condition     = alltrue([for cidr in var.public_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Every entry in public_subnet_cidrs must be a valid CIDR block."
  }

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "public_subnet_cidrs must contain at least two entries."
  }

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.private_subnet_cidrs) && length(var.public_subnet_cidrs) == length(var.database_subnet_cidrs)
    error_message = "public_subnet_cidrs, private_subnet_cidrs and database_subnet_cidrs must have the same number of entries."
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnets for EKS nodes and pods, one per availability zone"
  type        = list(string)
  default     = ["10.0.32.0/20", "10.0.48.0/20", "10.0.64.0/20"]

  validation {
    condition     = alltrue([for cidr in var.private_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Every entry in private_subnet_cidrs must be a valid CIDR block."
  }

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "private_subnet_cidrs must contain at least two entries."
  }
}

variable "database_subnet_cidrs" {
  description = "Database subnets, one per availability zone"
  type        = list(string)
  default     = ["10.0.96.0/24", "10.0.97.0/24", "10.0.98.0/24"]

  validation {
    condition     = alltrue([for cidr in var.database_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Every entry in database_subnet_cidrs must be a valid CIDR block."
  }

  validation {
    condition     = length(var.database_subnet_cidrs) >= 2
    error_message = "database_subnet_cidrs must contain at least two entries."
  }
}

variable "enable_nat_gateway" {
  description = "Create the NAT gateway and its Elastic IP (billed by the hour). Keep false when nothing in the private subnets needs the internet."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway (cheapest) or one per availability zone (resilient, about three times the hourly cost)"
  type        = bool
  default     = true
}

variable "services" {
  description = "Services that get their own container repository"
  type        = list(string)
  default     = ["vote-ui", "vote-api", "results-api"]
}

variable "ecr_force_delete" {
  description = "Allow Terraform to delete container repositories that still contain images. Keep false outside disposable environments."
  type        = bool
  default     = false
}

variable "enable_database" {
  description = "Create the PostgreSQL database (billed by the hour). Keep false when nothing uses it."
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "quickballot"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GiB"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "PostgreSQL engine version, matching the version used in docker-compose.yml"
  type        = string
  default     = "16"
}

variable "enable_eks" {
  description = "Create the EKS cluster and node group (billed by the hour). Requires enable_nat_gateway."
  type        = bool
  default     = false
}

variable "eks_cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  type        = string
  default     = "1.37"
}

variable "eks_node_instance_type" {
  description = "Instance type of the managed node group"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_count" {
  description = "Number of nodes in the managed node group (minimum, desired and maximum)"
  type        = number
  default     = 2

  validation {
    condition     = var.eks_node_count >= 1
    error_message = "eks_node_count must be at least 1."
  }
}

variable "eks_admin_role_arn" {
  description = "Real ARN of the IAM role that receives cluster administrator access, including any path. Required when enable_eks is true. For an IAM Identity Center (SSO) role this is arn:aws:iam::<account>:role/aws-reserved/sso.amazonaws.com/<region>/AWSReservedSSO_<name>_<hash>. EKS access entries do not accept the path-less form."
  type        = string
  default     = null
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public cluster endpoint. Required when enable_eks is true; 0.0.0.0/0 is rejected."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.eks_public_access_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Every entry in eks_public_access_cidrs must be a valid CIDR block."
  }

  validation {
    condition     = !contains(var.eks_public_access_cidrs, "0.0.0.0/0")
    error_message = "eks_public_access_cidrs must not contain 0.0.0.0/0. List the specific ranges that need access."
  }
}
