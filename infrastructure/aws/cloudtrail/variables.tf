variable "aws_region" {
  description = "AWS region for CloudTrail"
  type        = string
  default     = "us-gov-east-1"
}

variable "name_prefix" {
  description = "Prefix for all resources (should match VAULT lab_prefix)"
  type        = string
  default     = "vault"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "Name prefix must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "log_retention_days" {
  description = "Number of days to retain CloudTrail logs"
  type        = number
  default     = 7
  
  validation {
    condition     = var.log_retention_days >= 1 && var.log_retention_days <= 365
    error_message = "Log retention must be between 1 and 365 days"
  }
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch Logs integration for real-time log analysis"
  type        = bool
  default     = false
}