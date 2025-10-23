variable "aws_region" {
  description = "AWS region for lab deployment"
  type        = string
  default     = "us-gov-east-1"
}

variable "lab_prefix" {
  description = "Prefix for all lab resources"
  type        = string
  default     = "lab-lambda-injection"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.lab_prefix))
    error_message = "Lab prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "lab_difficulty" {
  description = "Difficulty rating (1-10)"
  type        = number
  default     = 4
  validation {
    condition     = var.lab_difficulty >= 1 && var.lab_difficulty <= 10
    error_message = "Difficulty must be between 1 and 10."
  }
}

variable "enable_cost_controls" {
  description = "Enable automatic cost control measures"
  type        = bool
  default     = true
}