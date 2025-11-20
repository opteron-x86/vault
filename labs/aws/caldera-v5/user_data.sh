#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Enable logging
exec > >(tee -a /var/log/user-data.log)
exec 2>&1

echo "Starting setup at $(date)"

apt-get update
apt-get upgrade -y

# Install XFCE desktop environment (lightweight, better RDP support)
echo "Installing XFCE..."
apt-get install -y \
    xfce4 \
    xfce4-goodies \
    xorg \
    dbus-x11

# Install xrdp for RDP access
echo "Installing xrdp..."
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
echo "Installing TigerVNC..."
apt-get install -y tigervnc-standalone-server tigervnc-common

# Configure VNC for ubuntu user with proper X11 environment
mkdir -p /home/ubuntu/.vnc
cat > /home/ubuntu/.vnc/xstartup << 'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
# Set XAUTHORITY for snap applications
export XAUTHORITY=$HOME/.Xauthority
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

# Configure X11 environment variables for ubuntu user
cat >> /home/ubuntu/.bashrc << 'EOF'

# X11 Authentication for snap applications
if [ -z "$XAUTHORITY" ]; then
    export XAUTHORITY=$HOME/.Xauthority
fi
EOF

# Also add to .profile for non-interactive sessions
cat >> /home/ubuntu/.profile << 'EOF'

# X11 Authentication for snap applications
if [ -z "$XAUTHORITY" ]; then
    export XAUTHORITY=$HOME/.Xauthority
fi
EOF

chown ubuntu:ubuntu /home/ubuntu/.bashrc
chown ubuntu:ubuntu /home/ubuntu/.profile

# Install Node.js 20 LTS
echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install Python and dependencies for Caldera
echo "Installing Python dependencies..."
apt-get install -y \
    git \
    python3 \
    python3-pip \
    python3-venv \
    golang-go \
    upx-ucl

# Verify pip installation
echo "Verifying pip installation..."
python3 -m pip --version

# Install useful tools (firefox will be installed via snap)
echo "Installing additional tools..."
apt-get install -y \
    curl \
    wget \
    vim \
    tmux \
    htop \
    net-tools \
    snapd

# Ensure snapd is running
systemctl enable snapd
systemctl start snapd

# Wait for snapd to be ready
sleep 10

# Install Firefox via snap
echo "Installing Firefox via snap..."
snap install firefox

# Ensure Desktop directory exists with correct permissions
echo "Creating Desktop directory..."
mkdir -p /home/ubuntu/Desktop
chown ubuntu:ubuntu /home/ubuntu/Desktop
chmod 755 /home/ubuntu/Desktop

# Create Caldera installation instructions on desktop
echo "Creating installation instructions..."
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
chmod 644 /home/ubuntu/Desktop/Install-Caldera.txt

# Create info file on desktop
echo "Creating README..."
cat > /home/ubuntu/Desktop/README.txt << EOF
Remote Desktop Server
=====================

RDP Connection: Use Remote Desktop Client
VNC Connection: Port 5901
Username: ubuntu
Password: ${vnc_password}

To install MITRE Caldera, see: Install-Caldera.txt

NOTE: Firefox is installed via snap. If it doesn't launch from the menu,
open a terminal and run: firefox &

EOF

chown ubuntu:ubuntu /home/ubuntu/Desktop/README.txt
chmod 644 /home/ubuntu/Desktop/README.txt

# Verify files were created
echo "Verifying desktop files..."
ls -la /home/ubuntu/Desktop/

echo "Setup complete at $(date)" > /var/log/caldera-setup.log
echo "Setup complete at $(date)"