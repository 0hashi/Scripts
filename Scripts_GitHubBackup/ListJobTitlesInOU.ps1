Import-Module ActiveDirectory
Clear-Host

# Prompt for OU Distinguished Name
$OU = Read-Host "Enter the OU Distinguished Name (e.g. OU=Texas,DC=verticalcable,DC=local)"

# Get enabled users from the specified OU
$Users = Get-ADUser -SearchBase $OU `
                    -Filter 'Enabled -eq $true' `
                    -Properties Title |
    Select-Object SamAccountName, Title |
    Sort-Object Title

# Display results
$Users | Format-Table -AutoSize

# Optional: Export to CSV
$Export = Read-Host "Export results to CSV? (Y/N)"

if ($Export -match '^(Y|y)$')
{
    # Create C:\Temp if it doesn't exist
    if (-not (Test-Path 'C:\Temp'))
    {
        New-Item -Path 'C:\Temp' -ItemType Directory -Force | Out-Null
    }

    $CsvPath = 'C:\Temp\ActiveUsers_JobTitles.csv'
    $Users | Export-Csv -Path $CsvPath -NoTypeInformation

    Write-Host "Results exported to $CsvPath" -ForegroundColor Green
}