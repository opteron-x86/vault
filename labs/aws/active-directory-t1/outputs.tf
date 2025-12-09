output "dc_public_ip" {
  description = "Domain Controller public IP (admin access only)"
  value       = aws_instance.dc.public_ip
}

output "dc_private_ip" {
  description = "Domain Controller private IP"
  value       = aws_instance.dc.private_ip
}

output "workstation_public_ip" {
  description = "Workstation public IP (attacker entry point)"
  value       = aws_instance.workstation.public_ip
}

output "domain_name" {
  description = "Active Directory domain name"
  value       = var.domain_name
}

output "domain_netbios" {
  description = "NetBIOS domain name"
  value       = var.domain_netbios
}

output "attacker_username" {
  description = "Low-privilege domain user for initial access"
  value       = "${var.domain_netbios}\\m.johnson"
}

output "attacker_password" {
  description = "Password for low-privilege user"
  value       = random_password.lowpriv_password.result
  sensitive   = true
}

output "rdp_command" {
  description = "RDP to workstation as attacker"
  value       = "xfreerdp /v:${aws_instance.workstation.public_ip} /u:${var.domain_netbios}\\m.johnson /p:<password> /cert:ignore"
}

output "rdp_admin_command" {
  description = "RDP to DC as domain admin (for troubleshooting)"
  value       = "xfreerdp /v:${aws_instance.dc.public_ip} /u:${var.domain_netbios}\\Administrator /p:<admin_password> /cert:ignore"
}

output "admin_password" {
  description = "Domain Administrator password"
  value       = random_password.admin_password.result
  sensitive   = true
}

output "attack_paths" {
  description = "Available attack paths"
  value = {
    kerberoast = "svc_backup has SPN - crack TGS for password (Summer2024!)"
    asrep      = "j.smith has pre-auth disabled - AS-REP roast (Welcome123)"
    acl_abuse  = "m.johnson has GenericAll on IT Admins group (member of Domain Admins)"
  }
}

output "setup_note" {
  description = "Post-deployment instructions"
  value       = "Allow 15-20 minutes for DC setup and workstation domain join. Check C:\\ws-setup.log on workstation for status."
}