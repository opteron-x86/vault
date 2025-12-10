variable "name" {
  description = "VM name"
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

variable "subnet_id" {
  description = "Subnet ID for the VM"
  type        = string
}

variable "vm_size" {
  description = "VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "os_type" {
  description = "Operating system type: linux or windows"
  type        = string
  validation {
    condition     = contains(["linux", "windows"], var.os_type)
    error_message = "os_type must be 'linux' or 'windows'"
  }
}

variable "source_image" {
  description = "Source image reference (publisher, offer, sku, version)"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
}

variable "admin_username" {
  description = "Admin username"
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Admin password (required for Windows, optional for Linux with SSH key)"
  type        = string
  default     = null
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for Linux VMs"
  type        = string
  default     = null
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 30
}

variable "os_disk_type" {
  description = "OS disk storage account type"
  type        = string
  default     = "Standard_LRS"
}

variable "network_security_group_id" {
  description = "NSG ID to associate with the NIC"
  type        = string
  default     = null
}

variable "assign_public_ip" {
  description = "Assign a public IP to the VM"
  type        = bool
  default     = true
}

variable "custom_data" {
  description = "Custom data script (base64 encoded for Linux, raw for Windows)"
  type        = string
  default     = null
}

variable "user_assigned_identity_ids" {
  description = "List of user-assigned managed identity IDs"
  type        = list(string)
  default     = []
}

variable "enable_system_identity" {
  description = "Enable system-assigned managed identity"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}