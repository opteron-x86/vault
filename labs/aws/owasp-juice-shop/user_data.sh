#!/bin/bash
set -e

dnf update -y
dnf install -y docker at

systemctl enable docker
systemctl start docker

usermod -aG docker ec2-user

cat > /home/ec2-user/juice-shop-config.json << 'CONFIG'
{
  "application": {
    "domain": "localhost",
    "name": "OWASP Juice Shop"
  },
  "secrets": {
    "db_password": "${db_password}",
    "admin_token": "${admin_token}",
    "secrets_arn": "${secrets_arn}"
  }
}
CONFIG

chown ec2-user:ec2-user /home/ec2-user/juice-shop-config.json

docker pull bkimminich/juice-shop:latest

docker run -d \
  --name juice-shop \
  --restart unless-stopped \
  -p 3000:3000 \
  -v /home/ec2-user/juice-shop-config.json:/juice-shop/config/custom.json:ro \
  bkimminich/juice-shop:latest

cat > /home/ec2-user/check-juice-shop.sh << 'CHECKSCRIPT'
#!/bin/bash
until curl -s http://localhost:3000 > /dev/null; do
  echo "Waiting for Juice Shop to start..."
  sleep 5
done
echo "Juice Shop is ready!"
CHECKSCRIPT

chmod +x /home/ec2-user/check-juice-shop.sh
chown ec2-user:ec2-user /home/ec2-user/check-juice-shop.sh

cat > /var/log/juice-shop-setup.log << LOGENTRY
Juice Shop deployment completed
Database password: ${db_password}
Admin token: ${admin_token}
Secrets ARN: ${secrets_arn}
Access URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000
LOGENTRY

systemctl enable atd
systemctl start atd
echo "sudo shutdown -h +240" | at now