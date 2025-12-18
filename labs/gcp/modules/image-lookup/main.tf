data "google_compute_image" "ubuntu_22_04" {
  family  = "ubuntu-2204-lts"
  project = "ubuntu-os-cloud"
}

data "google_compute_image" "ubuntu_24_04" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}

data "google_compute_image" "debian_12" {
  family  = "debian-12"
  project = "debian-cloud"
}

data "google_compute_image" "debian_11" {
  family  = "debian-11"
  project = "debian-cloud"
}

data "google_compute_image" "rocky_9" {
  family  = "rocky-linux-9"
  project = "rocky-linux-cloud"
}

data "google_compute_image" "rocky_8" {
  family  = "rocky-linux-8"
  project = "rocky-linux-cloud"
}

data "google_compute_image" "windows_server_2022" {
  family  = "windows-2022"
  project = "windows-cloud"
}

data "google_compute_image" "windows_server_2019" {
  family  = "windows-2019"
  project = "windows-cloud"
}

data "google_compute_image" "cos_stable" {
  family  = "cos-stable"
  project = "cos-cloud"
}