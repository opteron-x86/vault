variable "workshop_user_username" {
  type    = string
}

variable "notebook_instance_name" {
  type    = string
}

variable "notebook_instance_role_name" {
  type    = string
}

variable "user_ip" {
  type    = string
}

variable "admin_ip" {
  type    = string
}

variable "kali_image_id" {
  type    = string
}

variable "create_target_volume" {
  type    = bool
  default = false
}

variable "lab_name" {
  type    = string
}
