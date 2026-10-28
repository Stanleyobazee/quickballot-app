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
}

variable "public_subnet_cidrs" {
  description = "Public subnets, one per availability zone"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.10.0/24", "10.0.20.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnets for EKS nodes and pods, one per availability zone"
  type        = list(string)
  default     = ["10.0.32.0/20", "10.0.48.0/20", "10.0.64.0/20"]
}

variable "database_subnet_cidrs" {
  description = "Database subnets, one per availability zone"
  type        = list(string)
  default     = ["10.0.96.0/24", "10.0.97.0/24", "10.0.98.0/24"]
}
