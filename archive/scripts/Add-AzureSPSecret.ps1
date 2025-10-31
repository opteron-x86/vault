# Import the required module
Import-Module AzureAD

# Connect to Azure AD (Skip this step if you are already connected)
$credentials = Get-Credential
Connect-AzureAD -Credential $credentials -AzureEnvironmentName "AzureUSGovernment"  # Remove -AzureEnvironmentName "AzureUSGovernment" if not on GovCloud

# Set the application ObjectId (replace with your application's ObjectId)
$appObjectId = Read-Host -Prompt "Enter the application ObjectId"

# Prompt the user to enter a new password
$passwordValue = Read-Host -Prompt "Enter a new password for the application" -AsSecureString

# Convert the secure string password to plain text (required for the cmdlet)
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($passwordValue)
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Set the password (secret) description and duration
$passwordDescription = "Description for this secret"
$endDate = (Get-Date).AddYears(1)  # Set secret to expire in 1 year

# Create a new password (secret) for the application
$newPasswordCredential = New-AzureADApplicationPasswordCredential -ObjectId $appObjectId -Value $plainPassword -CustomKeyIdentifier $passwordDescription -EndDate $endDate

# Output the secret details
$newPasswordCredential | Format-List
