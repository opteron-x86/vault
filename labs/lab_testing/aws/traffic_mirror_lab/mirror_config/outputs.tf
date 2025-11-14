output "mirror_session_id" {
  value       = aws_ec2_traffic_mirror_session.mirror_session.id
}

output "instructions" {
  description = "Instructions for testing"
  value       = <<-EOT
    
    Traffic Mirroring Lab Setup Complete!
    
    1. SSH to collector instance:
       ssh -i your-key.pem ec2-user@${var.target_instance_public_ip}
    
    2. Start capturing traffic on collector:
       sudo tcpdump -i any -n port 4789 -v
       
       Or to see decapsulated traffic:
       sudo tcpdump -i any -n udp port 4789 -w /tmp/mirror.pcap
    
    3. Generate traffic on source instance:
       Visit http://${var.target_instance_public_ip} in your browser
       
       Or from another terminal:
       curl http://${var.target_instance_public_ip}
    
    4. You should see VXLAN encapsulated traffic on the collector!
    
    Note: Mirrored traffic is encapsulated in VXLAN (UDP port 4789)
  EOT
}