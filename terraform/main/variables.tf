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
