variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vpc_name_attacker" {
  type = string
}

variable "cidr_block_attacker" {
  type = string
}

variable "public_subnet_attacker" {
  type = string
}

variable "vpc_name_target" {
  type = string
}

variable "cidr_block_target" {
  type = string
}

variable "public_subnet_target" {
  type = string
}
