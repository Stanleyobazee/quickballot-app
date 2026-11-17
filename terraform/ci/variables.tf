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

variable "github_repository" {
  description = "GitHub repository allowed to assume the CI plan role, in owner/repo form"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must be in owner/repo form."
  }
}

variable "github_owner_id" {
  description = "Numeric ID of the GitHub account or organization that owns the repository"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_owner_id))
    error_message = "github_owner_id must contain digits only."
  }
}

variable "github_repository_id" {
  description = "Numeric ID of the GitHub repository"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "github_repository_id must contain digits only."
  }
}
