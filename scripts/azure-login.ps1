# Retrieve environment variables
$clientId = $env:AZURE_CLIENT_ID
$clientSecret = $env:AZURE_CLIENT_SECRET
$tenantId = $env:AZURE_TENANT_ID
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$workspaceName = $env:WORKSPACE_NAME  # Optional, if needed for other operations

# Debugging: Output the environment variables for verification
Write-Host "Environment Variables Debug:"
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

Write-Host "Azure authentication and subscription set successfully."

# Perform additional tasks if needed (e.g., workspace verification)
if ($workspaceName) {
    Write-Host "Checking workspace $workspaceName..."
    az monitor log-analytics workspace show --workspace-name $workspaceName --query "name" -o tsv

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Workspace $workspaceName not found or inaccessible."
        exit $LASTEXITCODE
    }

    Write-Host "Workspace verification successful."
}

Write-Host "Script execution completed successfully."
