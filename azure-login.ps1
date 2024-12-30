# Retrieve stored variables
$tenantId = $env:AZURE_TENANT_ID
$clientId = $env:AZURE_CLIENT_ID
$clientSecret = $env:AZURE_CLIENT_SECRET

# Check for required variables
if (-not $tenantId -or -not $clientId -or -not $clientSecret) {
    Write-Error "One or more required environment variables (AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET) are missing."
    exit 1
}

# Log in to Azure
Write-Host "Logging into Azure..."
az login --service-principal --tenant $tenantId --username $clientId --password $clientSecret

if ($LASTEXITCODE -ne 0) {
    Write-Error "Azure login failed."
    exit $LASTEXITCODE
}

Write-Host "Azure login successful."
