# variables.tf for ssrf-metadata lab

variable "aws_region" {
  description = "AWS region for lab deployment"
  type        = string
  default     = "us-gov-east-1"
}

variable "allowed_source_ips" {
  description = "IP addresses allowed to access lab resources"
  type        = list(string)
  validation {
    condition     = length(var.allowed_source_ips) > 0
    error_message = "At least one allowed IP must be specified."
  }
}

variable "ssh_key_name" {
  description = "AWS SSH key pair name for EC2 access"
  type        = string
  default     = "cnc-all-access"
}

variable "lab_prefix" {
  description = "Prefix for all lab resources"
  type        = string
  default     = "lab-ssrf"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.lab_prefix))
    error_message = "Lab prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "instance_type" {
  description = "EC2 instance type for lab VMs"
  type        = string
  default     = "t2.micro"
}

variable "auto_shutdown_hours" {
  description = "Hours until automatic instance shutdown"
  type        = number
  default     = 4
  validation {
    condition     = var.auto_shutdown_hours >= 1 && var.auto_shutdown_hours <= 24
    error_message = "Auto shutdown must be between 1 and 24 hours."
  }
}

variable "enable_cost_controls" {
  description = "Enable automatic cost control measures"
  type        = bool
  default     = true
}

variable "lab_difficulty" {
  description = "Difficulty level of the lab"
  type        = string
  default     = "easy-medium"
  validation {
    condition     = contains(["easy", "easy-medium", "medium", "medium-hard", "hard"], var.lab_difficulty)
    error_message = "Difficulty must be one of: easy, easy-medium, medium, medium-hard, hard."
  }
}