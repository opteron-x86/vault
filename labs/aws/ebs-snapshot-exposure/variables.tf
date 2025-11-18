variable "aws_region" {
  description = "AWS region for lab deployment"
  type        = string
  default     = ""
}

variable "allowed_source_ips" {
  description = "CIDR blocks allowed to access resources (not used in this lab but required by common config)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "lab_prefix" {
  description = "Prefix for lab resource naming"
  type        = string
  default     = "ebs-snapshot-lab"
}