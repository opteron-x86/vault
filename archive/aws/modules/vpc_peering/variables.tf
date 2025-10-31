variable "vpc_id_attacker" {
  description = "ID of the attacker VPC"
  type        = string
}

variable "vpc_id_target" {
  description = "ID of the target VPC"
  type        = string
}

variable "peering_name" {
  description = "Name of the peering connection"
  type        = string
}

variable "public_rt_attacker" {
  description = "ID of the route table for the attacker VPC"
  type        = string
}

variable "public_rt_target" {
  description = "ID of the route table for the target VPC"
  type        = string
}

variable "cidr_block_attacker" {
  description = "CIDR block of the attacker VPC"
  type        = string
}

variable "cidr_block_target" {
  description = "CIDR block of the target VPC"
  type        = string
}