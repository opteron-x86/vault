variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "instance_type_attacker" {
  type = string
}

variable "subnet_id_attacker" {
  type = string
}

variable "security_group_attacker" {
  type = string
}

variable "attacker_vm_name" {
  type = string
}

variable "volume_size_attacker" {
  type = number
}

variable "instance_type_target" {
  type = string
}

variable "subnet_id_target" {
  type = string
}

variable "security_group_target" {
  type = string
}

variable "target_vm_name" {
  type = string
}

variable "volume_size_target" {
  type = number
}

variable "user_data" {
  type = string
}

variable "identity_ids" {
  type = list(string)
}
