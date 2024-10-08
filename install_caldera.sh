#!/bin/bash

# Update System
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# Check Python version
echo "Checking Python version..."
python3 --version

# Install Python 3.8+ if needed
echo "Installing Python 3.8+..."
sudo apt install python3 python3-pip -y

# Install Node.js v18
echo "Installing Node.js v18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -
sudo apt-get install -y nodejs

# Verify Node.js and npm installation
echo "Verifying Node.js and npm installation..."
node -v
npm -v

# Install GoLang 1.17+
echo "Installing GoLang 1.17+..."
sudo rm -rf /usr/local/go
wget https://golang.org/dl/go1.22.1.linux-amd64.tar.gz 
sudo tar -C /usr/local -xzf go1.22.1.linux-amd64.tar.gz 

# Set up GoLang environment variables
echo "Setting up GoLang environment variables..."
echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.profile
echo "export GOPATH=\$HOME/go" >> ~/.profile
echo "export PATH=\$PATH:\$GOPATH/bin" >> ~/.profile
source ~/.profile

# Verify Go installation
echo "Verifying Go installation..."
go version

# Install Git
echo "Installing Git..."
sudo apt update
sudo apt install git -y

# Clone and set up Caldera
echo "Cloning Caldera repository..."
git clone https://github.com/mitre/caldera.git --recursive
cd caldera

# Install Python virtual environment
echo "Setting up Python virtual environment for Caldera..."
sudo apt install python3-venv -y
python3 -m venv venv
source venv/bin/activate

# Install required Python packages for Caldera
echo "Installing Python dependencies..."
pip install aiohttp-apispec
pip3 install -r requirements.txt

# Start Caldera server
echo "Starting Caldera server..."
python3 server.py --insecure --build
