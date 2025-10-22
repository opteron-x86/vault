# Outputs from the vpc module
output "vpc_id_target" {
  value = module.vpc.vpc_id_target
}

output "vpc_id_attacker" {
  value = module.vpc.vpc_id_attacker
}

output "public_subnet_attacker" {
  value = module.vpc.public_subnet_attacker
}

output "public_subnet_target" {
  value = module.vpc.public_subnet_target
}

output "public_rt_attacker" {
  value = module.vpc.public_rt_attacker
}

output "public_rt_target" {
  value = module.vpc.public_rt_target
}

output "cidr_block_attacker" {
  value = module.vpc.cidr_block_attacker
}

output "cidr_block_target" {
  value = module.vpc.cidr_block_target
}

# Outputs from the vm module
output "attacker_vm_private_ip" {
  value = module.vm.attacker_vm_private_ip
}

output "attacker_vm_public_ip" {
  value = module.vm.attacker_vm_public_ip
}

output "target_vm_private_ip" {
  value = module.vm.target_vm_private_ip
}

output "target_vm_public_ip" {
  value = module.vm.target_vm_public_ip
}

output "target_private_key" {
  value     = module.vm.target_private_key
  sensitive = true
}

output "iam_workshop_user_username" {
  value = module.iam_workshop_user.username
}

output "signin_url" {
  value = module.iam_workshop_user.signin_url
}

output "iam_workshop_user_password" {
  value = module.iam_workshop_user.password
}

output "user_ip" {
  value = var.user_ip
}

output "admin_ip" {
  value = var.admin_ip
}

output "lab_name" {
  value = var.lab_name
}

output "kali_ami" {
  value = var.kali_ami
}

output "flask_app_bucket_name" {
  value = aws_s3_bucket.flask_app_bucket.bucket
  description = "The name of the dynamically generated S3 bucket"
}