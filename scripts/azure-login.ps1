# Retrieve environment variables
$clientId = $env:AZURE_CLIENT_ID
$clientSecret = $env:AZURE_CLIENT_SECRET
$tenantId = $env:AZURE_TENANT_ID
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$resourceGroup = $env:RESOURCE_GROUP
$workspaceName = $env:WORKSPACE_NAME

# Validate required variables
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
    Write-Error "Failed to set Azure subscription."
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
