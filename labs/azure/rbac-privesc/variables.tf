variable "azure_region" {
  description = "Azure region for lab deployment"
  type        = string
  default     = "usgovvirginia"
}

variable "lab_prefix" {
  description = "Prefix for all lab resources"
  type        = string
  default     = "lab-rbac"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.lab_prefix))
    error_message = "Lab prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "lab_difficulty" {
  description = "Difficulty level of the lab"
  type        = string
  default     = "easy-medium"
  validation {
    condition     = contains(["easy", "easy-medium", "medium", "medium-hard", "hard"], var.lab_difficulty)
    error_message = "Difficulty must be one of: easy, easy-medium, medium, medium-hard, hard."
  }
}