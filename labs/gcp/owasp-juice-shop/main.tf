resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  common_labels = {
    environment  = "development"
    destroyable  = "true"
    application  = "juice-shop"
    auto_shutdown = "4hours"
  }
  machine_type = var.machine_type
  zone         = data.google_compute_zones.available.names[0]
}

resource "google_compute_network" "juice_shop" {
  name                    = "${var.lab_prefix}-network-${random_string.suffix.result}"
  auto_create_subnetworks = false
  
  description = "Network for Juice Shop lab"
}

resource "google_compute_subnetwork" "juice_shop" {
  name          = "${var.lab_prefix}-subnet-${random_string.suffix.result}"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.gcp_region
  network       = google_compute_network.juice_shop.id
  
  description = "Subnet for Juice Shop instances"
}

resource "google_compute_firewall" "juice_shop_ssh" {
  name    = "${var.lab_prefix}-ssh-${random_string.suffix.result}"
  network = google_compute_network.juice_shop.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_source_ips
  target_tags   = ["juice-shop"]
  
  description = "Allow SSH from specified IPs"
}

resource "google_compute_firewall" "juice_shop_web" {
  name    = "${var.lab_prefix}-web-${random_string.suffix.result}"
  network = google_compute_network.juice_shop.name

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  source_ranges = var.allowed_source_ips
  target_tags   = ["juice-shop"]
  
  description = "Allow web traffic to Juice Shop"
}