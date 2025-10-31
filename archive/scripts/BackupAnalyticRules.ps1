param (
    [parameter(Mandatory = $true)]
    [string] $resourceGroupName,
    [parameter(Mandatory = $true)]
    [string] $workspaceName,
    [parameter(Mandatory = $true)]
    [string] $subscriptionid
)

$PowerShellYAMLModule = Get-InstalledModule -Name powershell-yaml -ErrorAction SilentlyContinue
if ($PowerShellYAMLModule -eq $null)
{
    Write-Warning "The Powershell-yaml PowerShell module is not found"
    Write-Warning -Message "Installing the Powershell-yaml module to all users"
    Install-Module -Name powershell-yaml -Force
    Import-Module -Name powershell-yaml -Force
}

# Check if Azure Account is already logged in.
$context = Get-AzContext
if (!$context)
{
    $secrets = ConvertFrom-JSON $env:credentials
    Write-Output $env
    Write-Output $env:credentials
    Write-Output $secrets
    $servicePrincipalId = $secrets.clientId
    $servicePrincipalKey = $secrets.clientSecret
    $tenantId = $secrets.tenantId
    $subscriptionId = $secrets.subscriptionId
    Clear-AzContext -Scope Process
    Clear-AzContext -Scope CurrentUser -Force -ErrorAction SilentlyContinue
    $credpass = ConvertTo-SecureString $servicePrincipalKey.replace("'", "''") -AsPlainText -Force
    Connect-AzAccount -ServicePrincipal -Tenant $tenantId -Credential (New-Object System.Management.Automation.PSCredential($servicePrincipalId, $credpass)) -Environment 'azureusgovernment' | out-null
    Get-AzContext -ListAvailable
    Set-AzContext -SubscriptionId $subscriptionId -TenantId $tenantId
}

$SentinelAnalyticsRuleYAMLModule = Get-InstalledModule -Name Get-SentinelAnalyticsRuleYAML -ErrorAction SilentlyContinue
if ($SentinelAnalyticsRuleYAMLModule -eq $null){
            Write-Warning "The Get-SentinelAnalyticsRuleYAML PowerShell module is not found"
            #Admin, install to all users
            Write-Warning -Message "Installing the Get-SentinelAnalyticsRuleYAML module to all users"
            #Install-Module -Name "Azure-Sentinel/Tools/PowerShell/Developer Scripts/Modules/Get-SentinelAnalyticsRuleYAML" -Force
            $ModulePath = Resolve-Path -Path "Azure-Sentinel\Tools\PowerShell\Developer` Scripts\Modules\Get-SentinelAnalyticsRuleYAML\"
            Import-Module -Name $ModulePath -Force -Verbose
}

Get-SentinelAnalyticsRuleYAML -workspaceName $workspaceName -resourceGroupName $resourceGroupName -subscriptionId $subscriptionid -outputPath ./Backup/Azure-Sentinel/AnalyticsRules