# MITRE Caldera C2 Server

**Difficulty:** 1/10  
**Provider:** AWS  
**Scenario:** Deploy MITRE Caldera adversary emulation platform with desktop environment

## Description

This lab deploys a fully configured MITRE Caldera server on Ubuntu 24.04 with MATE desktop environment. Caldera is an adversary emulation platform built on the MITRE ATT&CK framework, designed for automated adversary emulation, red team operations, and breach simulations.

The deployment includes:
- Ubuntu 24.04 LTS with MATE desktop environment
- MITRE Caldera server (latest version from master branch)
- RDP access via xrdp
- VNC access via TigerVNC
- Pre-configured admin credentials
- Desktop shortcuts for quick access

## Access Methods

### SSH Access
```bash
ssh ubuntu@<public_ip>
```

### RDP Access
- **Host:** Instance public IP
- **Port:** 3389
- **Username:** ubuntu
- **Password:** VNC password (from outputs)

### VNC Access
- **Host:** Instance public IP
- **Port:** 5901
- **Display:** :1
- **Password:** From outputs (use `--sensitive` flag)

### Caldera Web Interface
- **URL:** http://\<public_ip\>:8888
- **Username:** admin
- **Password:** From outputs (use `--sensitive` flag)

## Usage

### Viewing Credentials
```bash
vault outputs caldera --sensitive
```

### Connecting via VNC
```bash
vncviewer <public_ip>:5901
```

### Connecting via RDP
Use any RDP client (Microsoft Remote Desktop, Remmina, etc.):
```bash
xfreerdp /v:<public_ip>:3389 /u:ubuntu /p:<vnc_password>
```

### Accessing Caldera
Open a web browser and navigate to:
```
http://<public_ip>:8888
```

Login with:
- Username: `admin`
- Password: (from sensitive outputs)

## MITRE Caldera Overview

Caldera is a cybersecurity framework designed for automated adversary emulation and autonomous red team operations. Key features include:

- **Adversary Emulation:** Execute MITRE ATT&CK techniques in realistic scenarios
- **Automated Operations:** Chain techniques together in intelligent attack chains
- **Plugin Architecture:** Extend functionality with built-in and custom plugins
- **Agent Framework:** Deploy agents on target systems for command and control
- **Threat Intelligence:** Import and execute TTPs from threat actor profiles
- **Report Generation:** Comprehensive reporting of operation results

## Initial Setup in Caldera

1. Access the web interface at http://\<public_ip\>:8888
2. Log in with admin credentials
3. Navigate to **Agents** to see available agent options
4. Deploy agents to target systems for testing
5. Create operations in the **Operations** tab
6. Select adversary profiles to emulate
7. Configure objectives and constraints
8. Execute and monitor operations

## Documentation

- [Caldera Official Documentation](https://caldera.readthedocs.io/)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [Caldera GitHub Repository](https://github.com/mitre/caldera)

## Notes

- The instance type defaults to `t3.medium` for adequate performance
- Caldera runs on port 8888 and is accessible from allowed source IPs
- The setup script may take 5-10 minutes to complete after deployment
- Check `/var/log/caldera-setup.log` for installation status
- Desktop shortcuts are created for quick access to Caldera

## Cleanup

```bash
vault destroy caldera
```

## Security Considerations

- This lab deploys Caldera in insecure mode for training purposes
- Use only in isolated lab environments
- Never deploy this configuration in production networks
- Ensure proper network segmentation from production systems
- Review and understand Caldera operations before executing