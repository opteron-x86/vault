#!/bin/bash
set -e

apt-get update
apt-get install -y docker.io

systemctl enable docker
systemctl start docker

usermod -aG docker ubuntu

cat > /home/ubuntu/juice-shop-config.json << 'CONFIG'
{
  "application": {
    "domain": "localhost",
    "name": "OWASP Juice Shop"
  },
  "secrets": {
    "db_password": "${db_password}",
    "admin_token": "${admin_token}",
    "bucket_name": "${bucket_name}",
    "secret_id": "${secret_id}"
  }
}
CONFIG

chown ubuntu:ubuntu /home/ubuntu/juice-shop-config.json

docker pull bkimminich/juice-shop:latest

docker run -d \
  --name juice-shop \
  --restart unless-stopped \
  -p 3000:3000 \
  -v /home/ubuntu/juice-shop-config.json:/juice-shop/config/custom.json:ro \
  bkimminich/juice-shop:latest

cat > /home/ubuntu/check-juice-shop.sh << 'CHECKSCRIPT'
#!/bin/bash
until curl -s http://localhost:3000 > /dev/null; do
  echo "Waiting for Juice Shop to start..."
  sleep 5
done
echo "Juice Shop is ready!"
CHECKSCRIPT

chmod +x /home/ubuntu/check-juice-shop.sh
chown ubuntu:ubuntu /home/ubuntu/check-juice-shop.sh

cat > /var/log/juice-shop-setup.log << LOGENTRY
Juice Shop deployment completed
Database password: ${db_password}
Admin token: ${admin_token}
GCS Bucket: ${bucket_name}
Secret ID: ${secret_id}
Access URL: http://$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google"):3000
LOGENTRY

# Schedule shutdown after 4 hours
echo "sudo shutdown -h now" | at now + 4 hours