variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "lab_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "allowed_source_ips" {
  description = "CIDR blocks allowed to access resources"
  type        = list(string)
}

variable "ssh_key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "default_tags" {
  description = "Default tags for resources"
  type        = map(string)
  default     = {}
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}