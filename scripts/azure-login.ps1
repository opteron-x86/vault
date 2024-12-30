# Retrieve environment variables
$clientId = $env:AZURE_CLIENT_ID
$clientSecret = $env:AZURE_CLIENT_SECRET
$tenantId = $env:AZURE_TENANT_ID
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$resourceGroup = $env:RESOURCE_GROUP
$workspaceName = $env:WORKSPACE_NAME

# Debugging: Output the environment variables for verification
Write-Host "Environment Variables Debug:"
Write-Host "AZURE_CLIENT_ID: $($clientId -ne $null)"
Write-Host "AZURE_CLIENT_SECRET: $($clientSecret -ne $null)"
Write-Host "AZURE_TENANT_ID: $($tenantId -ne $null)"
Write-Host "AZURE_SUBSCRIPTION_ID: $($subscriptionId -ne $null)"
Write-Host "RESOURCE_GROUP: $($resourceGroup -ne $null)"
Write-Host "WORKSPACE_NAME: $($workspaceName -ne $null)"

# Validate required variables
if (-not $clientId) { Write-Error "AZURE_CLIENT_ID is missing." }
if (-not $clientSecret) { Write-Error "AZURE_CLIENT_SECRET is missing." }
if (-not $tenantId) { Write-Error "AZURE_TENANT_ID is missing." }
if (-not $subscriptionId) { Write-Error "AZURE_SUBSCRIPTION_ID is missing." }
if (-not $resourceGroup) { Write-Error "RESOURCE_GROUP is missing." }
if (-not $workspaceName) { Write-Error "WORKSPACE_NAME is missing." }
if (-not $clientId -or -not $clientSecret -or -not $tenantId -or -not $subscriptionId -or -not $resourceGroup -or -not $workspaceName) {
    Write-Error "One or more required environment variables are missing. Ensure all required variables are set in GitLab CI/CD."
    exit 1
}

# Log in to Azure
Write-Host "Logging into Azure..."
az login --service-principal --username $clientId --password $clientSecret --tenant $tenantId

if ($LASTEXITCODE -ne 0) {
    Write-Error "Azure login failed."
    exit $LASTEXITCODE
}

# Set the Azure subscription
Write-Host "Setting Azure subscription to $subscriptionId..."
az account set --subscription $subscriptionId

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set Azure subscription. Verify the AZURE_SUBSCRIPTION_ID variable is correct."
    exit $LASTEXITCODE
}

# Confirm access to the resource group
Write-Host "Checking resource group access for $resourceGroup..."
az group show --name $resourceGroup

if ($LASTEXITCODE -ne 0) {
    Write-Error "Resource group $resourceGroup not found or inaccessible."
    exit $LASTEXITCODE
}

# Confirm access to the workspace
Write-Host "Checking workspace $workspaceName in resource group $resourceGroup..."
az monitor log-analytics workspace show --resource-group $resourceGroup --workspace-name $workspaceName

if ($LASTEXITCODE -ne 0) {
    Write-Error "Workspace $workspaceName not found or inaccessible in resource group $resourceGroup."
    exit $LASTEXITCODE
}

Write-Host "Azure authentication and resource verification successful."
