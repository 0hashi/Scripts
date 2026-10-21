# Import AD module
Import-Module ActiveDirectory

# Set output file path
$outputFile = "C:\Users\paulo\Desktop\ActiveDirectory\AD_User_LastLogon.txt"

# Define the OU to search (change this to match your environment)
$searchBase = "OU=Texas,DC=verticalcable,DC=local"

# Get user info from the specific OU, sort by GivenName
$users = Get-ADUser -Filter * -SearchBase $searchBase -Properties GivenName, Surname, SamAccountName, LastLogonDate |
    Where-Object { $_.Enabled -eq $true } |
    Select-Object GivenName, Surname, SamAccountName, LastLogonDate |
    Sort-Object GivenName

# Save to file
$users | Format-Table -AutoSize | Out-File -FilePath $outputFile

# STDOUT
$users | Format-Table -AutoSize

# Send to default printer
#Start-Process -FilePath $outputFile -Verb Print
