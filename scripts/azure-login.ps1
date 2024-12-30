# Retrieve environment variables
$clientId = $env:AZURE_CLIENT_ID
$clientSecret = $env:AZURE_CLIENT_SECRET
$tenantId = $env:AZURE_TENANT_ID
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID

# Debugging: Output the environment variables for verification
Write-Host "DEBUG: Environment Variables Verification:"
Write-Host "AZURE_CLIENT_ID: $($clientId -ne $null)"
Write-Host "AZURE_CLIENT_SECRET: $($clientSecret -ne $null)"
Write-Host "AZURE_TENANT_ID: $($tenantId -ne $null)"
Write-Host "AZURE_SUBSCRIPTION_ID: $($subscriptionId -ne $null)"

# Validate required variables
if (-not $clientId) { Write-Error "AZURE_CLIENT_ID is missing." }
if (-not $clientSecret) { Write-Error "AZURE_CLIENT_SECRET is missing." }
if (-not $tenantId) { Write-Error "AZURE_TENANT_ID is missing." }
if (-not $subscriptionId) { Write-Error "AZURE_SUBSCRIPTION_ID is missing." }

if (-not $clientId -or -not $clientSecret -or -not $tenantId -or -not $subscriptionId) {
    Write-Error "One or more required environment variables are missing. Ensure all required variables are set in GitLab CI/CD."
    exit 1
}

# Attempt to log in to Azure
Write-Host "Logging into Azure..."
$loginResult = az login --service-principal --username $clientId --password $clientSecret --tenant $tenantId

if ($LASTEXITCODE -ne 0) {
    Write-Error "Azure login failed. Please verify the AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, and AZURE_TENANT_ID."
    exit $LASTEXITCODE
}

Write-Host "Azure login successful."

# Check for available subscriptions
Write-Host "DEBUG: Listing available subscriptions..."
$subscriptions = az account list --query "[].{Name:name, ID:id}" -o table

if (-not $subscriptions) {
    Write-Error "No subscriptions found for this service principal. Ensure it has been assigned a role for at least one subscription."
    exit 1
}

Write-Host "DEBUG: Available Subscriptions:"
Write-Host $subscriptions

# Set the specified subscription
Write-Host "Setting Azure subscription to $subscriptionId..."
az account set --subscription $subscriptionId

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set Azure subscription. Verify the AZURE_SUBSCRIPTION_ID variable is correct and that the service principal has access to this subscription."
    exit $LASTEXITCODE
}

Write-Host "Azure subscription set successfully."

# Final success message
Write-Host "Azure authentication and subscription setup completed successfully."
