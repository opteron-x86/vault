variable "gcp_project" {
  description = "GCP project ID for lab deployment"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for lab deployment"
  type        = string
  default     = "us-east4"
}

variable "allowed_source_ips" {
  description = "IP addresses allowed to access resources"
  type        = list(string)
  validation {
    condition     = length(var.allowed_source_ips) > 0
    error_message = "At least one allowed IP must be specified."
  }
}

variable "ssh_key_name" {
  description = "SSH public key for instance access"
  type        = string
  default     = ""
}

variable "lab_prefix" {
  description = "Prefix for resource naming"
  type        = string
  default     = "juice-shop"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.lab_prefix))
    error_message = "Prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "e2-medium"
}

variable "lab_difficulty" {
  description = "Difficulty rating (1-10)"
  type        = number
  default     = 3
  validation {
    condition     = var.lab_difficulty >= 1 && var.lab_difficulty <= 10
    error_message = "Difficulty must be between 1 and 10."
  }
}