# Import the Active Directory module
Import-Module ActiveDirectory

# Get current date/time for filename
$timestamp = Get-Date -Format "MM-dd-yyyy_HH-mm-ss"

# Define output file path with timestamp
$outputDir = "C:\Users\paulo\Desktop\ActiveDirectory"
$outputFile = "$outputDir\LockedAccounts_$timestamp.txt"

# Ensure the output directory exists
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory | Out-Null
}

# Get all locked, enabled user accounts and sort alphabetically by Name
$lockedAccounts = Search-ADAccount -LockedOut -UsersOnly |
    Where-Object { $_.Enabled -eq $true } |
    Sort-Object Name

# Format and write results to file and console
if ($lockedAccounts) {
    $formatted = $lockedAccounts |
        Select-Object Name, SamAccountName, DistinguishedName |
        Format-Table -AutoSize |
        Out-String

    # Write to file
    # $formatted | Out-File -FilePath $outputFile -Encoding UTF8

    # Write to console
    Write-Host "`nLocked (Enabled) Accounts:`n" -ForegroundColor Cyan
    Write-Host $formatted
    # Write-Host "Results saved to: $outputFile" -ForegroundColor Green
} else {
    $message = "No locked and enabled accounts found."
    Write-Host $message -ForegroundColor Green
}
