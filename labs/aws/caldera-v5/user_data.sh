#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install XFCE desktop environment (lightweight, better RDP support)
apt-get install -y \
    xfce4 \
    xfce4-goodies \
    xorg \
    dbus-x11

# Install xrdp for RDP access
apt-get install -y xrdp
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

# Install TigerVNC server
apt-get install -y tigervnc-standalone-server tigervnc-common

# Configure VNC for ubuntu user
mkdir -p /home/ubuntu/.vnc
cat > /home/ubuntu/.vnc/xstartup << 'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
chmod +x /home/ubuntu/.vnc/xstartup

# Set VNC password
echo "${vnc_password}" | vncpasswd -f > /home/ubuntu/.vnc/passwd
chmod 600 /home/ubuntu/.vnc/passwd
chown -R ubuntu:ubuntu /home/ubuntu/.vnc

# Create VNC systemd service
cat > /etc/systemd/system/vncserver@.service << 'EOF'
[Unit]
Description=VNC Server for X11
After=syslog.target network.target

[Service]
Type=forking
User=ubuntu
ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill :%i > /dev/null 2>&1 || :'
ExecStart=/usr/bin/vncserver :%i -geometry 1920x1080 -depth 24 -localhost no
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vncserver@1.service
systemctl start vncserver@1.service

# Set password for ubuntu user (for RDP)
echo "ubuntu:${vnc_password}" | chpasswd

# Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install dependencies for Caldera
apt-get install -y \
    git \
    python3 \
    python3-pip \
    python3-venv \
    golang-go \
    upx-ucl \
    npm

# Install useful tools
snap install firefox
apt-get install -y \
    curl \
    wget \
    vim \
    tmux \
    htop \
    net-tools \

# Create desktop directory
mkdir -p /home/ubuntu/Desktop

# Create Caldera installation instructions on desktop
cat > /home/ubuntu/Desktop/Install-Caldera.txt << 'EOF'
MITRE Caldera Installation Instructions
========================================

Run these commands in a terminal to install and start Caldera:

cd /opt
sudo git clone https://github.com/mitre/caldera.git --recursive
cd caldera
python3 -m venv .calderavenv
source .calderavenv/bin/activate
pip3 install -r requirements.txt
python3 server.py --insecure --build

After Caldera starts, access it at: http://localhost:8888
Default credentials: admin / admin

Note: Change the admin password on first login!

Documentation: https://caldera.readthedocs.io/
EOF

chown ubuntu:ubuntu /home/ubuntu/Desktop/Install-Caldera.txt

# Create info file on desktop
cat > /home/ubuntu/Desktop/README.txt << EOF
Remote Desktop Server
=====================

RDP Connection: Use Remote Desktop Client
VNC Connection: Port 5901
Username: ubuntu
Password: ${vnc_password}

To install MITRE Caldera, see: Install-Caldera.txt

EOF

chown ubuntu:ubuntu /home/ubuntu/Desktop/README.txt

echo "Setup complete" > /var/log/caldera-setup.log