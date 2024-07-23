variable "availability_zone" {
  description = "The availability zone in which to create the resources"
  type        = string
}

variable "cidr_block_target" {
  description = "CIDR block for the Target VPC"
  type        = string
}

variable "public_subnet_target" {
  description = "List of public subnet CIDR blocks"
  type        = string
}

variable "vpc_name_target" {
  description = "Name of the Target VPC"
  type        = string
}

variable "cidr_block_attacker" {
    description = "CIDR Block for the Attacker VPC"
    type        = string
}

variable "public_subnet_attacker" {
    description = "List of public subnet CIDR blocks"
    type        = string
}

variable "vpc_name_attacker" {
  description = "Name of the Attacker VPC"
  type  = string
}