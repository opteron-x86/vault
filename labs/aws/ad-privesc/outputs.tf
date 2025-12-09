output "dc_public_ip" {
  description = "Domain Controller public IP"
  value       = aws_instance.dc.public_ip
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

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.dc.id
}

output "rdp_command" {
  description = "RDP connection command"
  value       = "xfreerdp /v:${aws_instance.dc.public_ip} /u:${var.domain_netbios}\\m.johnson /p:<password> /cert:ignore"
}

output "attack_paths" {
  description = "Available attack paths in this lab"
  value = {
    kerberoast = "svc_backup has SPN set - crack TGS for password"
    asrep      = "j.smith has pre-auth disabled - AS-REP roast"
    acl_abuse  = "m.johnson has GenericAll on 'IT Admins' group (member of Domain Admins)"
  }
}

output "setup_note" {
  description = "Post-deployment instructions"
  value       = "Allow 10-15 minutes after deployment for AD DS installation and configuration to complete. Check C:\\ad-setup.log and C:\\ad-configure.log for status."
}