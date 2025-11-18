output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.caldera.id
}

output "public_ip" {
  description = "Public IP address"
  value       = aws_instance.caldera.public_ip
}

output "ssh_command" {
  description = "SSH connection command"
  value       = "ssh ubuntu@${aws_instance.caldera.public_ip}"
}

output "rdp_connection" {
  description = "RDP connection information"
  value       = {
    host     = aws_instance.caldera.public_ip
    port     = 3389
    username = "ubuntu"
    password = "Use VNC password"
  }
}

output "vnc_connection" {
  description = "VNC connection information"
  value       = {
    host    = aws_instance.caldera.public_ip
    port    = 5901
    display = ":1"
  }
}

output "vnc_password" {
  description = "VNC server password"
  value       = random_password.vnc_password.result
  sensitive   = true
}

output "caldera_url" {
  description = "Caldera web interface URL"
  value       = "http://${aws_instance.caldera.public_ip}:8888"
}

output "caldera_credentials" {
  description = "Caldera admin credentials"
  value = {
    username = "admin"
    password = random_password.caldera_admin.result
  }
  sensitive = true
}