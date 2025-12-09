variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-gov-east-1"
}

variable "lab_prefix" {
  description = "Prefix for resource naming"
  type        = string
  default     = "vault"
}

variable "allowed_source_ips" {
  description = "CIDR blocks allowed to access the lab"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ami_id" {
  description = "Optional AMI ID override"
  type        = string
  default     = ""
}

variable "default_tags" {
  description = "Default tags for all resources"
  type        = map(string)
  default = {
    Project     = "VAULT"
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}