$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\ws-setup.log" -Append

$DomainName = "${domain_name}"
$DomainNetbios = "${domain_netbios}"
$DCIP = "${dc_ip}"
$AdminPassword = ConvertTo-SecureString "${admin_password}" -AsPlainText -Force
$DomainCred = New-Object System.Management.Automation.PSCredential("$DomainNetbios\Administrator", $AdminPassword)

$adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $DCIP
Write-Output "DNS set to $DCIP"

$maxAttempts = 40
$attempt = 0
do {
    $attempt++
    Write-Output "Waiting for DC to be ready (attempt $attempt/$maxAttempts)..."
    Start-Sleep -Seconds 30
    $dcReady = Test-NetConnection -ComputerName $DCIP -Port 389 -WarningAction SilentlyContinue
} while (-not $dcReady.TcpTestSucceeded -and $attempt -lt $maxAttempts)

if (-not $dcReady.TcpTestSucceeded) {
    Write-Output "DC not reachable after $maxAttempts attempts"
    Stop-Transcript
    exit 1
}

Write-Output "DC reachable, waiting additional time for AD services..."
Start-Sleep -Seconds 120

$joined = $false
$joinAttempts = 0
$maxJoinAttempts = 10

while (-not $joined -and $joinAttempts -lt $maxJoinAttempts) {
    $joinAttempts++
    Write-Output "Domain join attempt $joinAttempts/$maxJoinAttempts..."
    try {
        Add-Computer -DomainName $DomainName -Credential $DomainCred -Force -ErrorAction Stop
        $joined = $true
        Write-Output "Domain join successful"
    } catch {
        Write-Output "Domain join failed: $_"
        Start-Sleep -Seconds 60
    }
}

if (-not $joined) {
    Write-Output "Domain join failed after $maxJoinAttempts attempts"
    Stop-Transcript
    exit 1
}

Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

Add-LocalGroupMember -Group "Remote Desktop Users" -Member "$DomainNetbios\Domain Users" -ErrorAction SilentlyContinue

Write-Output "Workstation setup complete, rebooting..."
Stop-Transcript
Restart-Computer -Force