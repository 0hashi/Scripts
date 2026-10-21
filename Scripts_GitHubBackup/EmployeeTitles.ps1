Get-ADUser `
    -SearchBase "OU=Texas,DC=verticalcable,DC=local" `
    -Filter * `
    -Properties Title |
Select-Object Name, Title |
Sort-Object Title |
Format-Table -AutoSize