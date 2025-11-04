variable "aws_region" {
  description = "AWS region for lab deployment"
  type        = string
}

variable "allowed_source_ips" {
  description = "CIDR blocks allowed to access resources"
  type        = list(string)
}

variable "lab_prefix" {
  description = "Prefix for lab resource naming"
  type        = string
}

variable "default_tags" {
  description = "Default tags for all resources"
  type        = map(string)
  default     = {}
}