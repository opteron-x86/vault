variable "gcp_project" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for lab deployment"
  type        = string
  default     = "us-east4"
}

variable "lab_prefix" {
  description = "Prefix for all lab resources"
  type        = string
  default     = "lab-ssrf"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.lab_prefix))
    error_message = "Lab prefix must start with a letter and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "e2-micro"
}

variable "allowed_source_ips" {
  description = "IP addresses allowed to access lab resources"
  type        = list(string)
  default     = []
}

variable "enable_audit_logging" {
  description = "Enable Cloud Audit Logging"
  type        = bool
  default     = false
}