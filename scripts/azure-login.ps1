# Retrieve environment variables
$clientId = $env:AZURE_CLIENT_ID
$clientSecret = $env:AZURE_CLIENT_SECRET
$tenantId = $env:AZURE_TENANT_ID
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID

# Debugging: Output the environment variables for verification
Write-Host "DEBUG: Environment Variables Verification:"
Write-Host "AZURE_CLIENT_ID: $($clientId -ne $null)"
Write-Host "AZURE_CLIENT_SECRET: $([string]::IsNullOrEmpty($clientSecret))"
Write-Host "AZURE_TENANT_ID: $($tenantId -ne $null)"
Write-Host "AZURE_SUBSCRIPTION_ID: $($subscriptionId -ne $null)"

# Validate required variables
if (-not $clientId) { Write-Error "AZURE_CLIENT_ID is missing." }
if (-not $clientSecret) { Write-Error "AZURE_CLIENT_SECRET is missing." }
if (-not $tenantId) { Write-Error "AZURE_TENANT_ID is missing." }

if (-not $clientId -or -not $clientSecret -or -not $tenantId) {
    Write-Error "One or more required environment variables are missing. Ensure all required variables are set in GitLab CI/CD."
    exit 1
}

# Log in to Azure using the service principal
Write-Host "DEBUG: Running az login command..."
Write-Host "DEBUG: Command: az login --service-principal --username $clientId --password [MASKED] --tenant $tenantId"

az login --service-principal --username $clientId --password $clientSecret --tenant $tenantId

if ($LASTEXITCODE -ne 0) {
    Write-Error "Azure login failed for Service Principal. Verify AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, and AZURE_TENANT_ID."
    exit $LASTEXITCODE
}

Write-Host "Azure login successful."

# Check accessible subscriptions
Write-Host "DEBUG: Listing accessible subscriptions..."
$subscriptions = az account list --query "[].{Name:name, ID:id}" -o table

if (-not $subscriptions) {
    Write-Error "No subscriptions found for the service principal. Ensure it has the correct role at the subscription level."
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
