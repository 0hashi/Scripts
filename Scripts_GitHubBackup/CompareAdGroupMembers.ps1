Import-Module ActiveDirectory

Write-Host ""
Write-Host "Active Directory Group Membership Sync"
Write-Host "--------------------------------------"

$SourceGroup = Read-Host "Enter SOURCE group (Group A)"
$TargetGroup = Read-Host "Enter TARGET group (Group B)"

Write-Host ""
Write-Host "Collecting group membership..."

# Get members
$SourceMembers = @(Get-ADGroupMember $SourceGroup -Recursive)
$TargetMembers = @(Get-ADGroupMember $TargetGroup)

Write-Host ""
Write-Host "Source group member count: $($SourceMembers.Count)"
Write-Host "Target group member count: $($TargetMembers.Count)"

# Compare Distinguished Names
$SourceDN = $SourceMembers.DistinguishedName
$TargetDN = $TargetMembers.DistinguishedName

$UsersToAddDN = $SourceDN | Where-Object {$_ -notin $TargetDN}
$UsersToRemoveDN = $TargetDN | Where-Object {$_ -notin $SourceDN}

Write-Host ""
Write-Host "========== PREVIEW ==========" -ForegroundColor Yellow

Write-Host ""
Write-Host "Members to ADD to ${TargetGroup}:" -ForegroundColor Green
$UsersToAddDN | ForEach-Object { (Get-ADObject $_).Name }

Write-Host ""
Write-Host "Members to REMOVE from ${TargetGroup}:" -ForegroundColor Red
$UsersToRemoveDN | ForEach-Object { (Get-ADObject $_).Name }

$Confirm = Read-Host "`nProceed with synchronization? (Y/N)"

if ($Confirm -notin @("Y","y")) { exit }

# Add users
foreach ($DN in $UsersToAddDN) {
    Add-ADGroupMember -Identity $TargetGroup -Members $DN
    Write-Host "Added: $((Get-ADObject $DN).Name)"
}

# Remove users
foreach ($DN in $UsersToRemoveDN) {
    Remove-ADGroupMember -Identity $TargetGroup -Members $DN -Confirm:$false
    Write-Host "Removed: $((Get-ADObject $DN).Name)"
}

Write-Host ""
Write-Host "Group synchronization complete." -ForegroundColor Cyan