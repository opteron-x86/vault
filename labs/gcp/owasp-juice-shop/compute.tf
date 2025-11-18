resource "google_compute_instance" "juice_shop" {
  name         = "${var.lab_prefix}-instance-${random_string.suffix.result}"
  machine_type = local.machine_type
  zone         = local.zone

  tags = ["juice-shop"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.juice_shop.id
    
    access_config {
      // Ephemeral external IP
    }
  }

  service_account {
    email  = google_service_account.juice_shop.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    startup-script = templatefile("${path.module}/startup_script.sh", {
      db_password = random_password.db_password.result
      admin_token = random_password.admin_token.result
      bucket_name = google_storage_bucket.juice_data.name
      secret_id   = google_secret_manager_secret.juice_config.secret_id
    })
  }

  labels = local.common_labels
  
  lifecycle {
    ignore_changes = [metadata]
  }
}