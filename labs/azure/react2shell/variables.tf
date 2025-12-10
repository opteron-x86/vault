variable "azure_region" {
  description = "Azure region for lab deployment"
  type        = string
  default     = "usgovvirginia"
}

variable "allowed_source_ips" {
  description = "IP addresses allowed to access resources"
  type        = list(string)
  validation {
    condition     = length(var.allowed_source_ips) > 0
    error_message = "At least one allowed IP must be specified."
  }
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = ""
}

variable "admin_password" {
  description = "Admin password (used if ssh_public_key not provided)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "lab_prefix" {
  description = "Prefix for resource naming"
  type        = string
  default     = "saas-portal"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.lab_prefix))
    error_message = "Prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "auto_shutdown_hours" {
  description = "Hours until automatic VM shutdown"
  type        = number
  default     = 4
  validation {
    condition     = var.auto_shutdown_hours >= 1 && var.auto_shutdown_hours <= 24
    error_message = "Auto shutdown must be between 1 and 24 hours."
  }
}

variable "enable_logging" {
  description = "Enable Log Analytics, Storage diagnostics, Key Vault audit logs, and NSG flow logs"
  type        = bool
  default     = false
}