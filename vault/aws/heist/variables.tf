variable "user_ip" {
  type    = string
}

variable "admin_ip" {
  type    = string
}

variable "kali_ami" {
  type    = string
}

variable "create_target_volume" {
  type    = bool
  default = false
}

variable "lab_name" {
  type    = string
}