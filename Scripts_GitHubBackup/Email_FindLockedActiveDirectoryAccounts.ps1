# Import the Active Directory module
Import-Module ActiveDirectory

# Get current date/time for filename
$timestamp = Get-Date -Format "MM-dd-yyyy_HH-mm-ss"

# Define output file path with timestamp
$outputDir = "C:\Users\paulo\Desktop\ActiveDirectory"
$outputFile = "$outputDir\LockedAccounts_$timestamp.txt"

# Ensure the output directory exists
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory
}

# Get all locked user accounts
$lockedAccounts = Search-ADAccount -LockedOut -UsersOnly

# Format and write results to the file
if ($lockedAccounts) {
    $sorted = $lockedAccounts | Sort-Object Name
    $formatted = $sorted | Select-Object Name, SamAccountName, DistinguishedName | Format-Table -AutoSize | Out-String
    $formatted | Set-Content -Path $outputFile

    # Send output to default printer
    #$formatted | Out-Printer

    # Define email settings
    $smtpServer = "smtp.office365.com"      # SMTP Server
    $smtpPort = 587                         # Common ports: 25, 587, 465
    $from = "paulo@transcableusa.com"       # From me
    $to = "paulo@transcableusa"             # To me
    $subject = "Locked AD Accounts Report - $timestamp"
    $body = "Locked user accounts in Active Directory attached.`nGenerated: $timestamp"

    Optional: secure credentials (if required by your SMTP)
    $credential = Get-Credential

    # Send the email
    Send-MailMessage -From $from -To $to -Subject $subject -Body $body `
        -SmtpServer $smtpServer -Port $smtpPort `
        -Attachments $outputFile `
        -UseSsl -Credential $credential 

    Write-Host "Locked accounts written to $outputFile, sent to printer, and emailed." -ForegroundColor Green
} else {
    $message = "No locked accounts found."
    $message | Set-Content -Path $outputFile
    $message | Out-Printer

    # Send simple "no locks" notification
    Send-MailMessage -From $from -To $to -Subject "No Locked AD Accounts - $timestamp" `
        -Body $message -SmtpServer $smtpServer -Port $smtpPort -UseSsl

    Write-Host $message -ForegroundColor Green
}
