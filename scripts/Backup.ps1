Install-Module posh-git -Scope CurrentUser -Force
Import-Module posh-git
Add-PoshGitToProfile -AllHosts
git config user.email "ci@example.com"
git config user.name "CI"
git remote remove ssh_origin || true  # Local repo state may be cached
git remote add origin https://${GIT_USERNAME}:${GIT_PASSWORD}@gitlab.com/your-namespace/your-repo.git



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

<#
.SYNOPSIS
    Get-SentinelAnalyticsRuleYAML is a Powershell Module that GETs Azure Sentinel Analytic Rules in YAML format.
.DESCRIPTION
    Get-SentinelAnalyticsRuleYAML is a Powershell Module that GETs Azure Sentinel Analytic Rules in YAML format.
    It assumes that you already have the Az.Accounts Module (Get-AzAccessToken function) installed.
.EXAMPLE
    Get-SentinelAnalyticsRule -RuleId bae9dbb9-d32f-4de4-9eb1-d11055dcb832
.INPUTS
    To bring back a list of the rule ids. If you have the Get-AzSentinelAlertRule installed you can do the following:
    PS > Get-AzSentinelAlertRule -ResourceGroupName GSMO-RG -WorkspaceName sentinel-gsmo-ws | select name, displayname
.NOTES
    To install the PowerShell Module visit https://docs.microsoft.com/en-us/powershell/scripting/developer/module/installing-a-powershell-module?view=powershell-5.1 for details.

        TLDR: Step 1 - Copy to $env:userprofile\WindowsPowerShell\Modules
        cp ".\Tools\PowerShell\Developer Scripts\Modules\Get-SentinelAnalyticsRule" $env:userprofile\WindowsPowerShell\Modules -r
        Step 2 - Import the Module (per console)
        Import-Module Get-SentinelAnalyticsRule
        Step 3 - Follow Get-Help examples to invoke
        Get-Help Get-SentinelAnalyticsRule -full
#>

function Get-Header {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $token = (Get-AzAccessToken).Token
    $header = @{"Authorization"="Bearer $token";"Content-Type"="application/json"}
    return $header
}

function Format-AlertRule {
    param (
        [Parameter(Mandatory = $true)]
        [Object]$rule
    )
    # Flatten data to properties
    $rule.properties | Add-Member -MemberType NoteProperty -Name 'id' -Value $rule.id -Force
    $rule.properties | Add-Member -MemberType NoteProperty -Name 'name' -Value $rule.name -Force
    $rule.properties | Add-Member -MemberType NoteProperty -Name 'etag' -Value $rule.etag -Force
    $rule.properties | Add-Member -MemberType NoteProperty -Name 'type' -Value $rule.type -Force
    $rule.properties | Add-Member -MemberType NoteProperty -Name 'kind' -Value $rule.kind -Force
}

function Get-SentinelAnalyticsRuleYAML
{
    param (
        [Parameter(Mandatory = $false,
        HelpMessage = 'Enter the ID(s) for the Analytic Rule(s) that you want to bring back the YAML details back for',
        Position = 0)]
        [string[]]$RuleId,
        [Parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $false,
        HelpMessage = 'Enter the path of the folder you want to output to')]
        [string]$outputPath,
        [Parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $false,
        HelpMessage = 'Enter the resource group containing the Sentinel workspace you want to upload to')]
        [string]$resourceGroupName,
        [Parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $false,
        HelpMessage = 'Enter the Log Analytics Workspace containing the Sentinel instance you want to upload to')]
        [string]$workspaceName,
        [Parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $false,
        HelpMessage = 'Enter the Log Analytics Workspace containing the Sentinel instance you want to upload to')]
        [string]$subscriptionID
    )

    ## Check if the powershell-yaml module is installed, if not install it
    $PowerShellYAMLModule = Get-InstalledModule -Name powershell-yaml -ErrorAction SilentlyContinue
    if ($PowerShellYAMLModule -eq $null) {
        Write-Warning "The Powershell-yaml PowerShell module is not found"
        ## Admin, install to all users
        Write-Warning -Message "Installing the Powershell-yaml module to all users"
        Install-Module -Name powershell-yaml -Force
        Import-Module -Name powershell-yaml -Force
    }

    Write-Output "Starting Export..."
    Write-Output "Output Path: $($outputPath)"
    Write-Output "Resource Group: $($resourceGroupName)"
    Write-Output "Workspace: $($workspaceName)"

    ## Check if output path exists, if not create it
    if (Test-Path $outputPath) {
        Write-Verbose "Path Exists"
    }
    else {
        try {
            $null = New-Item -Path $outputPath -Force -ItemType Directory -ErrorAction Stop
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            Write-Error $ErrorMessage
            Write-Verbose $_
            Break
        }
    }

    $rules = @()

    $header = Get-Header
    $resourceManagerUrl = (Get-AzContext | Select-Object -ExpandProperty Environment).ResourceManagerUrl

    if ($RuleId) {
        foreach ($id in $RuleId) {
            try {
                Write-Output "Getting Analytic Rule: $($id)"
                $ruleName = [String] $id
                $url = "$($resourceManagerUrl)subscriptions/$($subscriptionID)/resourceGroups/$($resourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($workspaceName)/providers/Microsoft.SecurityInsights/alertRules/$($ruleName)?api-version=2022-11-01-preview"

                $temp = ((invoke-webrequest $url -Method 'GET' -Headers $header) | ConvertFrom-JSON)
                Format-AlertRule -rule $temp
                $rules += $temp.properties
            }
            catch {
                $return = $_.Exception.Message
                Write-Error $return
            }
        }
    }
    else {
        try {
            Write-Output "Getting Analytic Rules..."
            $url = "$($resourceManagerUrl)subscriptions/$($subscriptionID)/resourceGroups/$($resourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($workspaceName)/providers/Microsoft.SecurityInsights/alertRules?api-version=2022-11-01-preview"
            $tempRules = ((invoke-webrequest $url -Method 'GET' -Headers $header)[0] | ConvertFrom-Json).value
            foreach ($tempRule in $tempRules){
                Format-AlertRule -rule $tempRule
                $rules += $tempRule.properties
            }
        }
        catch {
            $return = $_.Exception.Message
            Write-Error $return
        }
    }
    if ($rules) {
        foreach ($rule in $rules) {
            try{
                $ruleDisplayName = $rule.DisplayName
                Write-Output "Outputting $ruleDisplayName"
                $fullPath = "$($outputPath)/$ruleDisplayName.yaml"
                if ($ruleDisplayName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -eq -1){
                    $rule | ConvertTo-Yaml | Out-File $fullPath -ErrorAction Stop
                    Write-Output "Output Successful: $fullPath"
                }
                else {
                    Write-Error "Error: Invalid character in $ruleDisplayName. Output unsuccessful."
                }
                Write-Output $_
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                Write-Error $ErrorMessage
                Write-Verbose $_
                Break
            }
        }
    }
}
Export-ModuleMember -Function Get-SentinelAnalyticsRuleYAML