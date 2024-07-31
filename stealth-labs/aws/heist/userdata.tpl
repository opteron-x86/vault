#!/bin/bash

# Wait for 60 seconds
sleep 60

# Update the system
sudo apt update -y
sudo apt upgrade -y

# Install Apache, PHP, and MySQL
sudo apt install apache2 php libapache2-mod-php php-mysql mysql-server -y

# Start and enable Apache and MySQL
sudo systemctl start apache2
sudo systemctl enable apache2
sudo systemctl start mysql
sudo systemctl enable mysql

# Secure MySQL installation
sudo mysql_secure_installation <<EOF

y
password
password
y
y
y
y
EOF

# Install AWS CLI
sudo apt install awscli -y

sudo mkdir /var/www/html/uploads

# Retrieve website files from S3
aws s3 cp s3://${techtalks_bucket_name}/ /var/www/html/ --recursive

# Set proper permissions
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/
sudo chmod -R 777 /var/www/html/uploads

# Run the database configuration script
sudo php /var/www/html/config.php
sudo rm /var/www/html/config.php

# Enable Apache rewrite module
sudo a2enmod rewrite
sudo systemctl restart apache2

# Configure firewall
sudo ufw allow 'Apache Full'
sudo ufw enable
