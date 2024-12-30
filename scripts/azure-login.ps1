# Retrieve stored variables
$tenantId = $env:AZURE_TENANT_ID
$clientId = $env:AZURE_CLIENT_ID
$clientSecret = $env:AZURE_CLIENT_SECRET
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID

# Check for required variables
if (-not $tenantId -or -not $clientId -or -not $clientSecret -or -not $subscriptionId) {
    Write-Error "One or more required environment variables (AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_SUBSCRIPTION_ID) are missing."
    exit 1
}

# Log in to Azure
Write-Host "Logging into Azure..."
az login --service-principal --tenant $tenantId --username $clientId --password $clientSecret

if ($LASTEXITCODE -ne 0) {
    Write-Error "Azure login failed."
    exit $LASTEXITCODE
}

# Set the active subscription
Write-Host "Setting Azure subscription to $subscriptionId..."
az account set --subscription $subscriptionId

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set Azure subscription."
    exit $LASTEXITCODE
}

Write-Host "Azure login and subscription set successfully."

