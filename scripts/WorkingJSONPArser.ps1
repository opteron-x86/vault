# Input JSON file
$InputFile = "C:\Users\Danielle.Torrence\Documents\Sentinel Backup - dod365-law - Monday, January 6, 2025"  # Update with your actual JSON file path

# Output directory
$OutputDir = "C:\Users\Danielle.Torrence\Documents\To_Be_Tested\parsed_rules"
if (-Not (Test-Path -Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force
}

# Check if the input file exists
if (-Not (Test-Path -Path $InputFile)) {
    Write-Error "Input file not found at path: $InputFile"
    exit 1
}

# Read the JSON file
try {
    $JsonData = Get-Content -Path $InputFile -Raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to read or parse the JSON file. Ensure the file is valid JSON."
    exit 1
}

# Parse and save each rule to its own file
if ($JsonData.value -is [array]) {
    foreach ($Rule in $JsonData.value) {
        # Attempt to use the 'displayName' property as the filename
        if ($Rule.properties.displayName) {
            $FileName = $Rule.properties.displayName
            $SafeFileName = $FileName -replace '[^a-zA-Z0-9_-]', '_' # Sanitize filename
            $FilePath = Join-Path -Path $OutputDir -ChildPath "$SafeFileName.json"

            # Convert rule to JSON and write to file
            $Rule | ConvertTo-Json -Depth 10 | Out-File -FilePath $FilePath -Encoding utf8

            Write-Host "Saved rule: $SafeFileName"
        } else {
            Write-Error "Rule with ID $($Rule.id) does not have a 'displayName' property."
        }
    }
} else {
    Write-Error "The JSON does not contain a 'value' array. Ensure the structure matches expectations."
    exit 1
}

Write-Host "Parsing complete. Files saved in '$OutputDir'."
