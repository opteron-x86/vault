output "ubuntu_22_04" {
  description = "Ubuntu 22.04 LTS image self link"
  value       = data.google_compute_image.ubuntu_22_04.self_link
}

output "ubuntu_22_04_name" {
  description = "Ubuntu 22.04 LTS image name"
  value       = data.google_compute_image.ubuntu_22_04.name
}

output "ubuntu_24_04" {
  description = "Ubuntu 24.04 LTS image self link"
  value       = data.google_compute_image.ubuntu_24_04.self_link
}

output "ubuntu_24_04_name" {
  description = "Ubuntu 24.04 LTS image name"
  value       = data.google_compute_image.ubuntu_24_04.name
}

output "debian_12" {
  description = "Debian 12 image self link"
  value       = data.google_compute_image.debian_12.self_link
}

output "debian_12_name" {
  description = "Debian 12 image name"
  value       = data.google_compute_image.debian_12.name
}

output "debian_11" {
  description = "Debian 11 image self link"
  value       = data.google_compute_image.debian_11.self_link
}

output "debian_11_name" {
  description = "Debian 11 image name"
  value       = data.google_compute_image.debian_11.name
}

output "rocky_9" {
  description = "Rocky Linux 9 image self link"
  value       = data.google_compute_image.rocky_9.self_link
}

output "rocky_9_name" {
  description = "Rocky Linux 9 image name"
  value       = data.google_compute_image.rocky_9.name
}

output "rocky_8" {
  description = "Rocky Linux 8 image self link"
  value       = data.google_compute_image.rocky_8.self_link
}

output "rocky_8_name" {
  description = "Rocky Linux 8 image name"
  value       = data.google_compute_image.rocky_8.name
}

output "windows_server_2022" {
  description = "Windows Server 2022 image self link"
  value       = data.google_compute_image.windows_server_2022.self_link
}

output "windows_server_2022_name" {
  description = "Windows Server 2022 image name"
  value       = data.google_compute_image.windows_server_2022.name
}

output "windows_server_2019" {
  description = "Windows Server 2019 image self link"
  value       = data.google_compute_image.windows_server_2019.self_link
}

output "windows_server_2019_name" {
  description = "Windows Server 2019 image name"
  value       = data.google_compute_image.windows_server_2019.name
}

output "cos_stable" {
  description = "Container-Optimized OS stable image self link"
  value       = data.google_compute_image.cos_stable.self_link
}

output "cos_stable_name" {
  description = "Container-Optimized OS stable image name"
  value       = data.google_compute_image.cos_stable.name
}