# Log in to Azure using the service principal
Write-Host "Logging into Azure as Service Principal..."
$loginResult = az login --service-principal --username $clientId --password $clientSecret --tenant $tenantId

if ($LASTEXITCODE -ne 0) {
    Write-Error "Azure login failed for Service Principal. Verify AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, and AZURE_TENANT_ID."
    exit $LASTEXITCODE
}

Write-Host "Azure login successful. Checking subscriptions..."

# List accessible subscriptions
$subscriptions = az account list --query "[].{Name:name, ID:id}" -o table

if (-not $subscriptions) {
    Write-Error "No subscriptions found for the service principal. Ensure it has the correct role at the subscription level."
    Write-Host "DEBUG: Checking service principal role assignments..."
    az role assignment list --assignee $clientId --query "[].{Role:roleDefinitionName, Scope:scope}" -o table
    exit 1
}

Write-Host "DEBUG: Accessible Subscriptions:"
Write-Host $subscriptions

# Set the subscription for subsequent operations
Write-Host "Setting Azure subscription to $subscriptionId..."
az account set --subscription $subscriptionId

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set Azure subscription. Verify AZURE_SUBSCRIPTION_ID is correct and the service principal has access."
    exit $LASTEXITCODE
}

Write-Host "Azure subscription set successfully."
Write-Host "Service principal authentication and subscription setup completed successfully."
