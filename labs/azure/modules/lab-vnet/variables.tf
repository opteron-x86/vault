variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vnet_cidr" {
  description = "CIDR block for VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_count" {
  description = "Number of subnets to create"
  type        = number
  default     = 1
  validation {
    condition     = var.subnet_count >= 1 && var.subnet_count <= 3
    error_message = "Subnet count must be between 1 and 3"
  }
}

variable "enable_private_subnets" {
  description = "Create private subnets without public IPs"
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway for private subnets"
  type        = bool
  default     = false
}

variable "create_ssh_nsg" {
  description = "Create NSG for SSH access"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed SSH access"
  type        = list(string)
  default     = []
}

variable "create_rdp_nsg" {
  description = "Create NSG for RDP access"
  type        = bool
  default     = false
}

variable "allowed_rdp_cidrs" {
  description = "CIDR blocks allowed RDP access"
  type        = list(string)
  default     = []
}

variable "create_web_nsg" {
  description = "Create NSG for web access"
  type        = bool
  default     = false
}

variable "allowed_web_cidrs" {
  description = "CIDR blocks allowed web access"
  type        = list(string)
  default     = []
}

variable "web_ports" {
  description = "Ports to open for web NSG"
  type        = list(number)
  default     = [80, 443, 8080]
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}