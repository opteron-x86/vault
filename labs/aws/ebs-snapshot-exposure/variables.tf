variable "aws_region" {
  description = "AWS region for lab deployment"
  type        = string
  default     = "us-gov-east-1"
}

variable "lab_prefix" {
  description = "Prefix for lab resources"
  type        = string
  default     = "ebs-snapshot-lab"
}