data "google_project" "current" {
  project_id = var.gcp_project
}

data "google_compute_zones" "available" {
  region = var.gcp_region
  status = "UP"
}

module "images" {
  source = "../modules/image-lookup"
}