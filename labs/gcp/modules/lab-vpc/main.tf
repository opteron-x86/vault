resource "google_compute_network" "lab" {
  name                    = "${var.name_prefix}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
  name                     = "${var.name_prefix}-public"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.lab.id
  ip_cidr_range            = var.network_cidr
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "private" {
  count = var.enable_private_subnet ? 1 : 0

  name                     = "${var.name_prefix}-private"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.lab.id
  ip_cidr_range            = var.private_subnet_cidr
  private_ip_google_access = true
}

resource "google_compute_router" "lab" {
  count = var.enable_cloud_nat ? 1 : 0

  name    = "${var.name_prefix}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.lab.id
}

resource "google_compute_router_nat" "lab" {
  count = var.enable_cloud_nat ? 1 : 0

  name                               = "${var.name_prefix}-nat"
  project                            = var.project_id
  router                             = google_compute_router.lab[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private[0].id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_firewall" "ssh" {
  count = var.create_ssh_firewall ? 1 : 0

  name    = "${var.name_prefix}-allow-ssh"
  project = var.project_id
  network = google_compute_network.lab.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = length(var.allowed_ssh_cidrs) > 0 ? var.allowed_ssh_cidrs : ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}

resource "google_compute_firewall" "web" {
  count = var.create_web_firewall ? 1 : 0

  name    = "${var.name_prefix}-allow-web"
  project = var.project_id
  network = google_compute_network.lab.id

  allow {
    protocol = "tcp"
    ports    = [for p in var.web_ports : tostring(p)]
  }

  source_ranges = length(var.allowed_web_cidrs) > 0 ? var.allowed_web_cidrs : ["0.0.0.0/0"]
  target_tags   = ["web"]
}

resource "google_compute_firewall" "internal" {
  name    = "${var.name_prefix}-allow-internal"
  project = var.project_id
  network = google_compute_network.lab.id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = compact([
    var.network_cidr,
    var.enable_private_subnet ? var.private_subnet_cidr : ""
  ])
}

resource "google_compute_firewall" "deny_all_ingress" {
  name     = "${var.name_prefix}-deny-all"
  project  = var.project_id
  network  = google_compute_network.lab.id
  priority = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}