variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "network_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "enable_private_subnet" {
  description = "Create a private subnet without external IPs"
  type        = bool
  default     = false
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "enable_cloud_nat" {
  description = "Create Cloud NAT for private subnet egress"
  type        = bool
  default     = false
}

variable "create_ssh_firewall" {
  description = "Create firewall rule for SSH access"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed SSH access"
  type        = list(string)
  default     = []
}

variable "create_web_firewall" {
  description = "Create firewall rule for web access"
  type        = bool
  default     = false
}

variable "allowed_web_cidrs" {
  description = "CIDR blocks allowed web access"
  type        = list(string)
  default     = []
}

variable "web_ports" {
  description = "Ports to open for web firewall rule"
  type        = list(number)
  default     = [80, 443, 8080]
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}