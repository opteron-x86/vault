Write-Host "[+] Simulating DEV-0530 ransomware file encryption..." -ForegroundColor Cyan

# Define test files and ransom note
$testFolder = "C:\Users\Public\Dev0530_Test"
$testFile1 = "$testFolder\test1.txt"
$testFile2 = "$testFolder\test2.docx"
$encryptedFile1 = "$testFile1.h0lyenc"
$encryptedFile2 = "$testFile2.h0lyenc"
$ransomNote = "C:\FOR_DECRYPT.html"

# Ensure test folder exists
if (!(Test-Path $testFolder)) {
    New-Item -Path $testFolder -ItemType Directory | Out-Null
}

# Create sample files
Write-Host "[+] Creating test files..."
"DEV-0530 test file 1" | Out-File -Encoding UTF8 $testFile1
"DEV-0530 test file 2" | Out-File -Encoding UTF8 $testFile2

# Simulate encryption by renaming files
Write-Host "[+] Simulating encryption (renaming files)..."
Rename-Item -Path $testFile1 -NewName $encryptedFile1
Rename-Item -Path $testFile2 -NewName $encryptedFile2

# Create fake ransom note
Write-Host "[+] Creating ransom note..."
@"
<h1>All your files have been encrypted!</h1>
<p>Contact us for decryption instructions.</p>
"@ | Out-File -Encoding UTF8 $ransomNote

Write-Host "[+] DEV-0530 simulation complete. Check Sentinel!" -ForegroundColor Green