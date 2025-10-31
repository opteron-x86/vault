# Import the required module
Import-Module AzureADPreview

# Get all Azure AD applications
$applications = Get-AzureADApplication -All $true
Write-Host "Retrieved $($applications.Count) applications."

# Iterate through each application and list the owners
foreach ($application in $applications) {
    Write-Host "Processing application $($application.DisplayName) with ObjectID $($application.ObjectId)."
    $owners = Get-AzureADApplicationOwner -ObjectId $application.ObjectId
    if($owners) {
        Write-Host "Found $($owners.Count) owner(s) for application $($application.DisplayName)."
        foreach ($owner in $owners) {
            $output = @{
              ApplicationId       = $application.AppId
              ObjectId            = $application.ObjectId  # Add this line
              ApplicationName     = $application.DisplayName
              OwnerObjectId       = $owner.ObjectId
              OwnerUserPrincipalName = $owner.UserPrincipalName
            }
            $output | Format-Table -AutoSize
        }
    } else {
        Write-Host "No owners found for application $($application.DisplayName)."
    }
}

# Note: Uncomment the line below if you want to disconnect from Azure AD at the end of the script.
# Disconnect-AzureAD
