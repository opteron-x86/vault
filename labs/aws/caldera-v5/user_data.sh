#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt update
apt upgrade -y

apt install -y \
    xfce4 \
    xfce4-goodies \
    xorg \
    dbus-x11

apt install -y xrdp
adduser xrdp ssl-cert

# Configure xrdp to use XFCE
cat > /etc/xrdp/startwm.sh << 'EOF'
#!/bin/sh
if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi
startxfce4
EOF
chmod +x /etc/xrdp/startwm.sh

# Configure XFCE session for all users
echo "startxfce4" > /etc/skel/.xsession

systemctl enable xrdp
systemctl restart xrdp

# Set password for ubuntu user (for RDP)
echo "ubuntu:${vnc_password}" | chpasswd

# Install dependencies for Caldera
apt install -y \
    git \
    python3 \
    python3-pip \
    python3-venv \
    golang-go \
    upx-ucl \
    npm

# Clone Caldera repository
git clone https://github.com/mitre/caldera.git --recursive --branch master
cd caldera

# Install Python dependencies
python3 -m venv .calderavenv
source .calderavenv/bin/activate
pip install -r requirements.txt
python3 server.py --insecure --build

# Install useful tools
apt install -y \
    curl \
    wget \
    vim \
    tmux \
    htop \
    net-tools \

snap install firefox 

# Create desktop shortcuts
mkdir -p /home/ubuntu/Desktop
cat > /home/ubuntu/Desktop/caldera.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Caldera
Comment=MITRE Caldera C2 Platform
Exec=firefox http://localhost:8888
Icon=firefox
Terminal=false
Categories=Network;
EOF
chmod +x /home/ubuntu/Desktop/caldera.desktop
chown ubuntu:ubuntu /home/ubuntu/Desktop/caldera.desktop

# Create info file on desktop
cat > /home/ubuntu/Desktop/README.txt << EOF
MITRE Caldera Server

Caldera URL: http://localhost:8888
Username: admin
Password: ${caldera_admin}

RDP/VNC Password: ${vnc_password}

Documentation: https://caldera.readthedocs.io/
EOF
chown ubuntu:ubuntu /home/ubuntu/Desktop/README.txt

echo "Setup complete" > /var/log/caldera-setup.log