resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  common_labels = {
    environment   = "lab"
    destroyable   = "true"
    application   = "url-inspector"
    auto_shutdown = "4hours"
  }
  zone = data.google_compute_zones.available.names[0]
}

module "vpc" {
  source = "../modules/lab-vpc"

  name_prefix       = var.lab_prefix
  project_id        = var.gcp_project
  region            = var.gcp_region
  network_cidr      = "10.0.0.0/24"
  allowed_ssh_cidrs = var.allowed_source_ips

  create_web_firewall = true
  allowed_web_cidrs   = var.allowed_source_ips
  web_ports           = [8080]

  labels = local.common_labels
}