#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get upgrade -y

# Install MATE desktop environment
apt-get install -y \
    ubuntu-mate-desktop \
    mate-desktop-environment-core \
    lightdm

# Install xrdp for RDP access
apt-get install -y xrdp
systemctl enable xrdp
systemctl start xrdp

# Configure xrdp to use MATE
echo "mate-session" > /etc/skel/.xsession
cat > /etc/xrdp/startwm.sh << 'EOF'
#!/bin/sh
if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi
exec mate-session
EOF
chmod +x /etc/xrdp/startwm.sh

# Install TigerVNC server
apt-get install -y tigervnc-standalone-server tigervnc-common

# Configure VNC for ubuntu user
mkdir -p /home/ubuntu/.vnc
cat > /home/ubuntu/.vnc/xstartup << 'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec mate-session
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

# Install dependencies for Caldera
apt-get install -y \
    git \
    python3 \
    python3-pip \
    python3-venv \
    golang-go \
    upx-ucl

# Clone Caldera repository
cd /opt
git clone https://github.com/mitre/caldera.git --recursive --branch master
cd caldera

# Install Python dependencies
python3 -m pip install --break-system-packages -r requirements.txt

# Configure Caldera
cat > conf/local.yml << EOF
---
host: 0.0.0.0
port: 8888
users:
  admin:
    admin: ${caldera_admin}
EOF

# Create systemd service for Caldera
cat > /etc/systemd/system/caldera.service << 'EOF'
[Unit]
Description=MITRE Caldera
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/caldera
ExecStart=/usr/bin/python3 server.py --insecure
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable caldera.service
systemctl start caldera.service

# Install useful tools
apt-get install -y \
    curl \
    wget \
    vim \
    tmux \
    htop \
    net-tools \
    firefox

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