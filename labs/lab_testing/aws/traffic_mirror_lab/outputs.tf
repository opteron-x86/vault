output "instructions" {
  description = "Instructions for testing"
  value       = <<-EOT
    
    Traffic Mirroring Lab Walkthrough:
    
    1. SSH to collector instance:
       ssh -i cnc-all-access.pem ec2-user@${module.mirror_target_ec2.collector_instance_public_ip}
    
    2. Start capturing traffic on collector:
       sudo tcpdump -i any -n port 4789 -v
       
       Or to see decapsulated traffic:
       sudo tcpdump -i any -n udp port 4789 -w /tmp/mirror.pcap
    
    3. Generate traffic on source instance:
       Visit http://${module.mirror_target_ec2.target_instance_public_ip} in your browser
       
       Or from another terminal:
       curl http://${module.mirror_target_ec2.target_instance_public_ip}
    
    4. You should see VXLAN encapsulated traffic on the collector!
        If written to a file with -w, read the file with :
        tcpdump -r /tmp/mirror.pcap

        Alternatively, you can view the pcap with Wireshark!
    
    Note: Mirrored traffic is encapsulated in VXLAN (UDP port 4789)

    Ideas for upgrading lab:
        - Scan EC2's that are already there and dynamically make the traffic mirror for an EC2 thats already built, makes emulation more realistic.
        - Add plaintext traffic generation with telnet or http with fun traffic to view.
            -Automatically begin pcap for generated traffic.
  EOT
}