/*

module "lab_vpc" {
  source = "./lab_vpc"

  aws_region = var.aws_region
  name_prefix = 
}

*/

module "mirror_vpc" {
    source = "./mirror_vpc"
}

module "mirror_target_ec2" {
    source = "./mirror_target_ec2"

    key_name = var.key_name
    mirror_subnet_id = module.mirror_vpc.public_subnet_id
    mirror_vpc_id = module.mirror_vpc.mirror_vpc_id

}

module "mirror_collector_ec2" {
    source = "./mirror_collector_ec2"

    key_name = var.key_name
    vpc_cidr = module.mirror_vpc.mirror_vpc_cidr
    mirror_subnet_id = module.mirror_vpc.public_subnet_id
    mirror_vpc_id = module.mirror_vpc.mirror_vpc_id
}

module "mirror_config" {
    source = "./mirror_config"

    collector_instance_primary_interface_id = module.mirror_collector_ec2.collector_instance_primary_network_interface_id
    target_instance_primary_interface_id = module.mirror_target_ec2.target_instance_primary_network_interface_id
    target_instance_public_ip = module.mirror_target_ec2.target_instance_public_ip
}