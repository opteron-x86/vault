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
  default     = "ad-lab"
}

variable "default_tags" {
  description = "Default tags for all resources"
  type        = map(string)
  default     = {}
}

variable "instance_type" {
  description = "EC2 instance type for domain controller"
  type        = string
  default     = "t3.medium"
}

variable "domain_name" {
  description = "Active Directory domain name"
  type        = string
  default     = "psychocorp.local"
}

variable "domain_netbios" {
  description = "NetBIOS name for the domain"
  type        = string
  default     = "PSYCHOCORP"
}

variable "ssh_key_name" {
  description = "EC2 key pair name for Windows password retrieval"
  type        = string
  default     = null
}