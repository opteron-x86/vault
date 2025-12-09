<powershell>
$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\ad-setup.log" -Append

$DomainName = "${domain_name}"
$DomainNetbios = "${domain_netbios}"
$DSRMPassword = ConvertTo-SecureString "${dsrm_password}" -AsPlainText -Force
$LowPrivPassword = ConvertTo-SecureString "${lowpriv_password}" -AsPlainText -Force

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

    @'
$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\ad-configure.log" -Append

$maxAttempts = 30
$attempt = 0
do {
    $attempt++
    Write-Output "Waiting for AD DS to be ready (attempt $attempt/$maxAttempts)..."
    Start-Sleep -Seconds 30
    try {
        $domain = Get-ADDomain -ErrorAction Stop
        $ready = $true
    } catch {
        $ready = $false
    }
} while (-not $ready -and $attempt -lt $maxAttempts)

if (-not $ready) {
    Write-Output "AD DS not ready after $maxAttempts attempts"
    Stop-Transcript
    exit 1
}

Import-Module ActiveDirectory
$DomainDN = $domain.DistinguishedName
$UsersContainer = "CN=Users,$DomainDN"
Write-Output "AD DS ready. Domain DN: $DomainDN"

# Create OUs (skip Users - use built-in CN=Users container)
$OUs = @("ServiceAccounts", "Workstations", "Servers", "Groups")
foreach ($OU in $OUs) {
    try {
        New-ADOrganizationalUnit -Name $OU -Path $DomainDN -ProtectedFromAccidentalDeletion $false -ErrorAction Stop
        Write-Output "Created OU: $OU"
    } catch {
        Write-Output "OU $OU already exists or failed: $_"
    }
}

# Kerberoastable service account
try {
    $svcBackup = New-ADUser -Name "svc_backup" -SamAccountName "svc_backup" `
        -UserPrincipalName "svc_backup@${domain_name}" `
        -Path "OU=ServiceAccounts,$DomainDN" `
        -AccountPassword (ConvertTo-SecureString "Summer2024!" -AsPlainText -Force) `
        -Enabled $true -PasswordNeverExpires $true -PassThru
    Set-ADUser -Identity $svcBackup -ServicePrincipalNames @{Add="MSSQLSvc/db01.${domain_name}:1433"}
    Add-ADGroupMember -Identity "Backup Operators" -Members $svcBackup
    Write-Output "Created svc_backup with SPN"
} catch {
    Write-Output "svc_backup setup failed: $_"
    $svcBackup = Get-ADUser -Identity "svc_backup" -ErrorAction SilentlyContinue
    if ($svcBackup) {
        Set-ADUser -Identity $svcBackup -ServicePrincipalNames @{Add="MSSQLSvc/db01.${domain_name}:1433"} -ErrorAction SilentlyContinue
        Add-ADGroupMember -Identity "Backup Operators" -Members $svcBackup -ErrorAction SilentlyContinue
    }
}

# AS-REP roastable user
try {
    $asrepUser = New-ADUser -Name "j.smith" -SamAccountName "j.smith" `
        -UserPrincipalName "j.smith@${domain_name}" `
        -GivenName "John" -Surname "Smith" `
        -Path $UsersContainer `
        -AccountPassword (ConvertTo-SecureString "Welcome123" -AsPlainText -Force) `
        -Enabled $true -Description "IT Support" -PassThru
    Set-ADAccountControl -Identity $asrepUser -DoesNotRequirePreAuth $true
    Write-Output "Created j.smith with pre-auth disabled"
} catch {
    Write-Output "j.smith setup failed: $_"
}

# IT Admins group
try {
    $itAdmins = New-ADGroup -Name "IT Admins" -SamAccountName "IT Admins" `
        -GroupScope Global -GroupCategory Security `
        -Path "OU=Groups,$DomainDN" -PassThru
    Add-ADGroupMember -Identity "Domain Admins" -Members $itAdmins
    Write-Output "Created IT Admins group"
} catch {
    Write-Output "IT Admins setup failed: $_"
    $itAdmins = Get-ADGroup -Identity "IT Admins" -ErrorAction SilentlyContinue
    if ($itAdmins) {
        Add-ADGroupMember -Identity "Domain Admins" -Members $itAdmins -ErrorAction SilentlyContinue
    }
}

# Attacker entry point user
try {
    $attackerUser = New-ADUser -Name "m.johnson" -SamAccountName "m.johnson" `
        -UserPrincipalName "m.johnson@${domain_name}" `
        -GivenName "Mike" -Surname "Johnson" `
        -Path $UsersContainer `
        -AccountPassword (ConvertTo-SecureString "${lowpriv_password}" -AsPlainText -Force) `
        -Enabled $true -Description "Help Desk" -PassThru
    Write-Output "Created m.johnson"
} catch {
    Write-Output "m.johnson creation failed: $_"
    $attackerUser = Get-ADUser -Identity "m.johnson" -ErrorAction SilentlyContinue
}

# Grant m.johnson GenericAll on IT Admins using SID
Start-Sleep -Seconds 5
try {
    $itAdmins = Get-ADGroup -Identity "IT Admins"
    $attackerUser = Get-ADUser -Identity "m.johnson"
    $acl = Get-Acl "AD:\$($itAdmins.DistinguishedName)"
    $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
        $attackerUser.SID,
        [System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    $acl.AddAccessRule($ace)
    Set-Acl "AD:\$($itAdmins.DistinguishedName)" $acl
    Write-Output "Granted m.johnson GenericAll on IT Admins"
} catch {
    Write-Output "ACL setup failed: $_"
}

# Decoy users
$decoyUsers = @(
    @{Name="a.williams"; First="Alice"; Last="Williams"; Desc="Finance"},
    @{Name="b.taylor"; First="Bob"; Last="Taylor"; Desc="Marketing"},
    @{Name="c.brown"; First="Carol"; Last="Brown"; Desc="HR"}
)
foreach ($user in $decoyUsers) {
    try {
        $pw = ConvertTo-SecureString (-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | ForEach-Object {[char]$_})) -AsPlainText -Force
        New-ADUser -Name $user.Name -SamAccountName $user.Name `
            -UserPrincipalName "$($user.Name)@${domain_name}" `
            -GivenName $user.First -Surname $user.Last `
            -Path $UsersContainer `
            -AccountPassword $pw -Enabled $true -Description $user.Desc
    } catch {}
}

# Enable RDP and WinRM
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Grant Remote Desktop Users the right to log on via RDP (required on DCs)
$rdpSid = (Get-ADGroup "Remote Desktop Users").SID.Value
secedit /export /cfg C:\secpol.cfg
$content = Get-Content C:\secpol.cfg
$content = $content -replace '(SeRemoteInteractiveLogonRight.*)
Write-Output "Configuration complete"
Stop-Transcript
'@ | Out-File -FilePath "C:\configure-ad.ps1" -Encoding UTF8

    Restart-Computer -Force
}

Stop-Transcript
</powershell>
, "`$1,*$rdpSid"
Set-Content C:\secpol.cfg $content
secedit /configure /db C:\Windows\security\local.sdb /cfg C:\secpol.cfg /areas USER_RIGHTS
Remove-Item C:\secpol.cfg -Force
Write-Output "Granted RDP logon right to Remote Desktop Users"

Unregister-ScheduledTask -TaskName "ConfigureAD" -Confirm:$false
Write-Output "Configuration complete"
Stop-Transcript
'@ | Out-File -FilePath "C:\configure-ad.ps1" -Encoding UTF8

    Restart-Computer -Force
}

Stop-Transcript
</powershell>