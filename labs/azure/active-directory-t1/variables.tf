variable "azure_region" {
  description = "Azure region for lab deployment"
  type        = string
  default     = "usgovvirginia"
}

variable "allowed_source_ips" {
  description = "CIDR blocks allowed to access resources"
  type        = list(string)
}

variable "lab_prefix" {
  description = "Prefix for lab resource naming"
  type        = string
  default     = "ad-lab"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.lab_prefix))
    error_message = "Lab prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vm_size" {
  description = "Azure VM size for domain controller"
  type        = string
  default     = "Standard_B2ms"
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

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureadmin"
}