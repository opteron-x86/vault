variable "availability_zone" {
  description = "The availability zone in which to create the resources"
  type        = string
}

variable "ami_attacker_01" {
  description = "AMI ID for the Attacker VM"
  type        = string
}

variable "instance_type_attacker" {
  description = "Instance type for the Attacker VM"
  type        = string
}

variable "subnet_id_attacker" {
  description = "Subnet ID for the Attacker VM"
  type        = string
}

variable "vpc_id_attacker" {
  description = "VPC ID for the Attacker VM"
  type        = string
}

variable "security_group_attacker" {
  description = "Security group ID for the Attacker VM"
  type        = string
}

variable "attacker_vm_name" {
  description = "Name for the Attacker VM"
  type        = string
}

variable "volume_size_attacker" {
  description = "Volume size for the Attacker VM"
  type        = number
}

variable "ami_target_01" {
  description = "AMI ID for the Target VM"
  type        = string
}

variable "instance_type_target" {
  description = "Instance type for the Target VM"
  type        = string
}

variable "subnet_id_target" {
  description = "Subnet ID for the Target VM"
  type        = string
}

variable "vpc_id_target" {
  description = "VPC ID for the Target VM"
  type        = string
}

variable "security_group_target" {
  description = "Security group ID for the Target VM"
  type        = string
}

variable "target_vm_name" {
  description = "Name for the Target VM"
  type        = string
}

variable "volume_size_target" {
  description = "Volume size for the Target VM"
  type        = number
}

variable "user_data" {
  description = "User data script for the VM"
  type        = string
  default     = ""
}

variable "iam_instance_profile" {
  description = "The IAM instance profile to associate with the EC2 instance"
  type        = string
  default     = ""
}

variable "target_volume_id" {
  description = "The EBS volume attached to the target VM"
  type        = string
  default     = ""
}

variable "create_target_volume" {
  type        = string
}

variable "lab_name" {
  type        = string
}