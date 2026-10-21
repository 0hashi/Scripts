
CLS
# Prompt for the user's email address
$user = Read-Host "Enter the user's email address"

# Validate input
if ([string]::IsNullOrWhiteSpace($user)) {
    Write-Host "No email address entered. Exiting." -ForegroundColor Red
    return
}

# Search distribution lists and mail-enabled security groups
$results = foreach ($group in Get-DistributionGroup -ResultSize Unlimited) {
    Get-DistributionGroupMember `
        -Identity $group.Identity `
        -ResultSize Unlimited `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.PrimarySmtpAddress -and
            $_.PrimarySmtpAddress.ToString() -eq $user.Trim()
        } |
        ForEach-Object {
            [PSCustomObject]@{
                GroupName  = $group.DisplayName
                GroupEmail = $group.PrimarySmtpAddress
                UserName   = $_.DisplayName
                UserEmail  = $_.PrimarySmtpAddress
                GroupType  = $group.RecipientTypeDetails
            }
        }
}

# Display results
if ($results) {
    Write-Host "`nGroups containing $user :" -ForegroundColor Green
    $results | Sort-Object GroupName | Format-Table -AutoSize
}
else {
    Write-Host "`nNo direct group memberships found for $user." `
        -ForegroundColor Yellow
}
