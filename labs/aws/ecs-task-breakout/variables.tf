variable "aws_region" {
  description = "AWS region for lab deployment"
  type        = string
  default     = "us-gov-east-1"
}

variable "lab_prefix" {
  description = "Prefix for all lab resources"
  type        = string
  default     = "ecs-task-breakout"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.lab_prefix))
    error_message = "Lab prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "lab_difficulty" {
  description = "Difficulty rating (1-10)"
  type        = number
  default     = 7
  validation {
    condition     = var.lab_difficulty >= 1 && var.lab_difficulty <= 10
    error_message = "Difficulty must be between 1 and 10."
  }
}

variable "allowed_source_ips" {
  description = "IP addresses allowed to access lab resources"
  type        = list(string)
  validation {
    condition     = length(var.allowed_source_ips) > 0
    error_message = "At least one allowed IP must be specified."
  }
}

variable "enable_cost_controls" {
  description = "Enable automatic cost control measures"
  type        = bool
  default     = true
}