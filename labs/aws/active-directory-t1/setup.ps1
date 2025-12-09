<powershell>
$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\ad-setup.log" -Append

$DomainName = "${domain_name}"
$DomainNetbios = "${domain_netbios}"
$DSRMPassword = ConvertTo-SecureString "${dsrm_password}" -AsPlainText -Force
$AdminPassword = ConvertTo-SecureString "${admin_password}" -AsPlainText -Force
$LowPrivPassword = "${lowpriv_password}"

# Set Administrator password before AD DS promotion
$admin = [ADSI]"WinNT://./Administrator,user"
$admin.SetPassword("${admin_password}")
Write-Output "Administrator password set"

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

$domainExists = $false
try {
    $domainExists = (Get-ADDomain -ErrorAction SilentlyContinue) -ne $null
} catch {}

if (-not $domainExists) {
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName $DomainNetbios `
        -SafeModeAdministratorPassword $DSRMPassword `
        -InstallDns `
        -Force `
        -NoRebootOnCompletion

    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File C:\configure-ad.ps1"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName "ConfigureAD" -Action $action -Trigger $trigger -Principal $principal -Force

    $configScript = @"

`$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\ad-configure.log" -Append

`$maxAttempts = 30
`$attempt = 0
do {
    `$attempt++
    Write-Output "Waiting for AD DS to be ready (attempt `$attempt/`$maxAttempts)..."
    Start-Sleep -Seconds 30
    try {
        `$domain = Get-ADDomain -ErrorAction Stop
        `$ready = `$true
    } catch {
        `$ready = `$false
    }
} while (-not `$ready -and `$attempt -lt `$maxAttempts)

if (-not `$ready) {
    Write-Output "AD DS not ready after `$maxAttempts attempts"
    Stop-Transcript
    exit 1
}

Import-Module ActiveDirectory
`$DomainDN = `$domain.DistinguishedName
`$UsersContainer = "CN=Users,`$DomainDN"
Write-Output "AD DS ready. Domain DN: `$DomainDN"

`$OUs = @("ServiceAccounts", "Workstations", "Servers", "Groups")
foreach (`$OU in `$OUs) {
    try {
        New-ADOrganizationalUnit -Name `$OU -Path `$DomainDN -ProtectedFromAccidentalDeletion `$false -ErrorAction Stop
        Write-Output "Created OU: `$OU"
    } catch {
        Write-Output "OU `$OU already exists or failed"
    }
}

try {
    `$svcBackup = New-ADUser -Name "svc_backup" -SamAccountName "svc_backup" -UserPrincipalName "svc_backup@$DomainName" -Path "OU=ServiceAccounts,`$DomainDN" -AccountPassword (ConvertTo-SecureString "Summer2024!" -AsPlainText -Force) -Enabled `$true -PasswordNeverExpires `$true -PassThru
    Set-ADUser -Identity `$svcBackup -ServicePrincipalNames @{Add="MSSQLSvc/db01.$DomainName`:1433"}
    Add-ADGroupMember -Identity "Backup Operators" -Members `$svcBackup
    Write-Output "Created svc_backup with SPN"
} catch {
    Write-Output "svc_backup setup failed: `$_"
}

try {
    `$asrepUser = New-ADUser -Name "j.smith" -SamAccountName "j.smith" -UserPrincipalName "j.smith@$DomainName" -GivenName "John" -Surname "Smith" -Path `$UsersContainer -AccountPassword (ConvertTo-SecureString "Welcome123" -AsPlainText -Force) -Enabled `$true -Description "IT Support" -PassThru
    Set-ADAccountControl -Identity `$asrepUser -DoesNotRequirePreAuth `$true
    Write-Output "Created j.smith with pre-auth disabled"
} catch {
    Write-Output "j.smith setup failed: `$_"
}

try {
    `$itAdmins = New-ADGroup -Name "IT Admins" -SamAccountName "IT Admins" -GroupScope Global -GroupCategory Security -Path "OU=Groups,`$DomainDN" -PassThru
    Add-ADGroupMember -Identity "Domain Admins" -Members `$itAdmins
    Write-Output "Created IT Admins group"
} catch {
    Write-Output "IT Admins setup failed: `$_"
}

try {
    `$attackerUser = New-ADUser -Name "m.johnson" -SamAccountName "m.johnson" -UserPrincipalName "m.johnson@$DomainName" -GivenName "Mike" -Surname "Johnson" -Path `$UsersContainer -AccountPassword (ConvertTo-SecureString "$LowPrivPassword" -AsPlainText -Force) -Enabled `$true -Description "Help Desk" -PassThru
    Write-Output "Created m.johnson"
} catch {
    Write-Output "m.johnson creation failed: `$_"
}

# ACL setup with retry
`$aclSet = `$false
`$aclAttempts = 0
`$maxAclAttempts = 6
while (-not `$aclSet -and `$aclAttempts -lt `$maxAclAttempts) {
    `$aclAttempts++
    Start-Sleep -Seconds 10
    try {
        Import-Module ActiveDirectory
        `$itAdmins = Get-ADGroup -Identity "IT Admins" -ErrorAction Stop
        `$attackerUser = Get-ADUser -Identity "m.johnson" -ErrorAction Stop
        if (`$itAdmins -and `$attackerUser) {
            `$acl = Get-Acl "AD:\`$(`$itAdmins.DistinguishedName)"
            `$ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(`$attackerUser.SID, [System.DirectoryServices.ActiveDirectoryRights]::GenericAll, [System.Security.AccessControl.AccessControlType]::Allow)
            `$acl.AddAccessRule(`$ace)
            Set-Acl "AD:\`$(`$itAdmins.DistinguishedName)" `$acl
            `$aclSet = `$true
            Write-Output "Granted m.johnson GenericAll on IT Admins"
        }
    } catch {
        Write-Output "ACL setup attempt `$aclAttempts failed: `$_"
    }
}
if (-not `$aclSet) {
    Write-Output "ACL setup failed after `$maxAclAttempts attempts"
}

Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Enable-PSRemoting -Force

Unregister-ScheduledTask -TaskName "ConfigureAD" -Confirm:`$false
Write-Output "Configuration complete"
Stop-Transcript
"@

    $configScript | Out-File -FilePath "C:\configure-ad.ps1" -Encoding UTF8
    Restart-Computer -Force
}

Stop-Transcript
</powershell>