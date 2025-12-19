resource "google_compute_instance" "webapp" {
  name         = "${var.lab_prefix}-webapp-${random_string.suffix.result}"
  machine_type = var.machine_type
  zone         = local.zone

  tags = [module.vpc.ssh_target_tag, module.vpc.web_target_tag]

  boot_disk {
    initialize_params {
      image = module.images.debian_12
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = module.vpc.public_subnet_id

    access_config {}
  }

  service_account {
    email  = google_service_account.webapp.email
    scopes = ["cloud-platform"]
  }

metadata = {
    data-processor-sa = google_service_account.data_processor.email
    startup-script = templatefile("${path.module}/startup_script.sh", {
      data_processor_sa = google_service_account.data_processor.email
      gcp_project       = var.gcp_project
    })
  }

  labels = local.common_labels

  lifecycle {
    ignore_changes = [metadata]
  }
}