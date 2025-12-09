<powershell>
$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\ad-setup.log" -Append

$DomainName = "${domain_name}"
$DomainNetbios = "${domain_netbios}"
$DSRMPassword = ConvertTo-SecureString "${dsrm_password}" -AsPlainText -Force
$AdminPassword = ConvertTo-SecureString "${admin_password}" -AsPlainText -Force
$LowPrivPassword = ConvertTo-SecureString "${lowpriv_password}" -AsPlainText -Force

# Weak passwords for attack scenarios
$KerberoastPassword = ConvertTo-SecureString "Summer2024!" -AsPlainText -Force
$ASREPPassword = ConvertTo-SecureString "Welcome123" -AsPlainText -Force

# Install AD DS role
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Check if domain already exists
$domainExists = $false
try {
    $domainExists = (Get-ADDomain -ErrorAction SilentlyContinue) -ne $null
} catch {}

if (-not $domainExists) {
    # Create new forest
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName $DomainNetbios `
        -SafeModeAdministratorPassword $DSRMPassword `
        -InstallDns `
        -Force `
        -NoRebootOnCompletion

    # Schedule post-reboot configuration
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File C:\configure-ad.ps1"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName "ConfigureAD" -Action $action -Trigger $trigger -Principal $principal -Force

    # Create post-reboot script
    @'
$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\ad-configure.log" -Append
Start-Sleep -Seconds 120

Import-Module ActiveDirectory

$DomainDN = (Get-ADDomain).DistinguishedName

# Create OUs
$OUs = @("ServiceAccounts", "Users", "Workstations", "Servers", "Groups")
foreach ($OU in $OUs) {
    try {
        New-ADOrganizationalUnit -Name $OU -Path $DomainDN -ProtectedFromAccidentalDeletion $false
    } catch {}
}

# ============================================
# ATTACK PATH 1: Kerberoastable Service Account
# ============================================
$svcBackup = New-ADUser `
    -Name "svc_backup" `
    -SamAccountName "svc_backup" `
    -UserPrincipalName "svc_backup@${domain_name}" `
    -Path "OU=ServiceAccounts,$DomainDN" `
    -AccountPassword (ConvertTo-SecureString "Summer2024!" -AsPlainText -Force) `
    -Enabled $true `
    -PasswordNeverExpires $true `
    -Description "Backup service account" `
    -PassThru

# Set SPN for Kerberoasting
Set-ADUser -Identity $svcBackup -ServicePrincipalNames @{Add="MSSQLSvc/db01.${domain_name}:1433"}

# Add to Backup Operators (elevated privileges)
Add-ADGroupMember -Identity "Backup Operators" -Members $svcBackup

# ============================================
# ATTACK PATH 2: AS-REP Roastable User
# ============================================
$asrepUser = New-ADUser `
    -Name "j.smith" `
    -SamAccountName "j.smith" `
    -UserPrincipalName "j.smith@${domain_name}" `
    -GivenName "John" `
    -Surname "Smith" `
    -Path "OU=Users,$DomainDN" `
    -AccountPassword (ConvertTo-SecureString "Welcome123" -AsPlainText -Force) `
    -Enabled $true `
    -Description "IT Support" `
    -PassThru

# Disable Kerberos pre-authentication
Set-ADAccountControl -Identity $asrepUser -DoesNotRequirePreAuth $true

# ============================================
# ATTACK PATH 3: ACL Abuse (GenericAll on group)
# ============================================
# Create IT Admins group with elevated access
$itAdmins = New-ADGroup `
    -Name "IT Admins" `
    -SamAccountName "IT Admins" `
    -GroupScope Global `
    -GroupCategory Security `
    -Path "OU=Groups,$DomainDN" `
    -Description "IT Administration group" `
    -PassThru

# Add IT Admins to Domain Admins
Add-ADGroupMember -Identity "Domain Admins" -Members $itAdmins

# Create attacker entry point user
$attackerUser = New-ADUser `
    -Name "m.johnson" `
    -SamAccountName "m.johnson" `
    -UserPrincipalName "m.johnson@${domain_name}" `
    -GivenName "Mike" `
    -Surname "Johnson" `
    -Path "OU=Users,$DomainDN" `
    -AccountPassword (ConvertTo-SecureString "${lowpriv_password}" -AsPlainText -Force) `
    -Enabled $true `
    -Description "Help Desk" `
    -PassThru

# Grant m.johnson GenericAll on IT Admins group (ACL abuse path)
$itAdminsPath = "AD:\$($itAdmins.DistinguishedName)"
$acl = Get-Acl $itAdminsPath
$identity = New-Object System.Security.Principal.NTAccount("${domain_netbios}\m.johnson")
$rights = [System.DirectoryServices.ActiveDirectoryRights]::GenericAll
$type = [System.Security.AccessControl.AccessControlType]::Allow
$inheritance = [DirectoryServices.ActiveDirectorySecurityInheritance]::None
$ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($identity, $rights, $type, $inheritance)
$acl.AddAccessRule($ace)
Set-Acl $itAdminsPath $acl

# ============================================
# Decoy users and groups
# ============================================
$decoyUsers = @(
    @{Name="a.williams"; First="Alice"; Last="Williams"; Desc="Finance"},
    @{Name="b.taylor"; First="Bob"; Last="Taylor"; Desc="Marketing"},
    @{Name="c.brown"; First="Carol"; Last="Brown"; Desc="HR"},
    @{Name="d.davis"; First="David"; Last="Davis"; Desc="Engineering"},
    @{Name="e.miller"; First="Emma"; Last="Miller"; Desc="Sales"}
)

foreach ($user in $decoyUsers) {
    $pw = ConvertTo-SecureString (-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | ForEach-Object {[char]$_})) -AsPlainText -Force
    New-ADUser `
        -Name $user.Name `
        -SamAccountName $user.Name `
        -UserPrincipalName "$($user.Name)@${domain_name}" `
        -GivenName $user.First `
        -Surname $user.Last `
        -Path "OU=Users,$DomainDN" `
        -AccountPassword $pw `
        -Enabled $true `
        -Description $user.Desc
}

# Additional service accounts (red herrings)
$svcAccounts = @("svc_web", "svc_sql", "svc_monitor")
foreach ($svc in $svcAccounts) {
    $pw = ConvertTo-SecureString (-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 20 | ForEach-Object {[char]$_})) -AsPlainText -Force
    New-ADUser `
        -Name $svc `
        -SamAccountName $svc `
        -Path "OU=ServiceAccounts,$DomainDN" `
        -AccountPassword $pw `
        -Enabled $true `
        -PasswordNeverExpires $true `
        -Description "Service Account"
}

# Enable Remote Desktop
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Enable WinRM
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Cleanup
Unregister-ScheduledTask -TaskName "ConfigureAD" -Confirm:$false

Stop-Transcript
'@ | Out-File -FilePath "C:\configure-ad.ps1" -Encoding UTF8

    Restart-Computer -Force
} else {
    Write-Output "Domain already exists, skipping installation"
}

Stop-Transcript
</powershell>