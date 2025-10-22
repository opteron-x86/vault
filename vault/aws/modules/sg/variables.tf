variable "vpc_id" {
  description = "The VPC ID where the security group will be created"
  type        = string
}

variable "admin_ip" {
  description = "Public IP address of the administrator for SSH access (Optional)"
  type        = string
  default     = null
}

variable "user_ip" {
  description = "Public IP address of the user accessing the attacker VM via VNC (Optional)"
  type        = string
  default     = null
}

variable "allowed_cidr_blocks" {
  description = "The list of CIDR blocks that are allowed to connect"
  type        = list(string)
  default     = [] # No default CIDR blocks
}
