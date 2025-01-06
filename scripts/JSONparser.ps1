# PowerShell Script to Parse JSON and Create Individual Rule Files

# Input JSON file
$InputFile = "rules.json"  # Replace with your actual file path

# Output directory
$OutputDir = "azure-scheduled-analytics/Mass Backups/dod365-law/Sentinel Backup - dod365-law - Monday, January 6, 2025"

if (-Not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir
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
        # Use the 'name' property as the filename or fallback to 'id'
        $FileName = if ($Rule.name) { $Rule.name } else { $Rule.id }
        $FilePath = Join-Path -Path $OutputDir -ChildPath "$FileName.json"

        # Convert rule to JSON and write to file
        $Rule | ConvertTo-Json -Depth 10 | Out-File -FilePath $FilePath -Encoding utf8

        Write-Host "Saved rule: $FileName"
    }
} else {
    Write-Error "The JSON does not contain a 'value' array. Ensure the structure matches expectations."
    exit 1
}

Write-Host "Parsing complete. Files saved in '$OutputDir'."
