<#

Paul Ohashi
TCI

SYNOPSIS
    Compare and sync Active Directory group memberships between two users.

DESCRIPTION
    Prompts for a template user and a target user, compares their AD group memberships,
    and optionally updates the target user to match the template user's memberships.

NOTES
    Requires ActiveDirectory module.
#>

CLS
# Ensure AD module is available
Import-Module ActiveDirectory -ErrorAction Stop

# Prompt for users
$templateUser = Read-Host "Enter the username (sAMAccountName) of the TEMPLATE user"
$targetUser   = Read-Host "Enter the username (sAMAccountName) of the TARGET user"

# Get AD user objects
try {
    $template = Get-ADUser $templateUser -Properties MemberOf
    $target   = Get-ADUser $targetUser   -Properties MemberOf
} catch {
    Write-Host "Error: One or both users not found in Active Directory." -ForegroundColor Red
    exit
}

# Get their groups (convert to group names)
$templateGroups = $template.MemberOf | ForEach-Object { (Get-ADGroup $_).Name }
$targetGroups   = $target.MemberOf   | ForEach-Object { (Get-ADGroup $_).Name }

# Compare memberships
$missingGroups = $templateGroups | Where-Object { $_ -notin $targetGroups }
$extraGroups   = $targetGroups   | Where-Object { $_ -notin $templateGroups }

Write-Host "`n--- Group Comparison ---" -ForegroundColor Cyan
Write-Host "Template user: $templateUser"
Write-Host "Target user:   $targetUser`n"

if ($missingGroups) {
    Write-Host "Groups missing from target (will be added):" -ForegroundColor Yellow
    $missingGroups | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "No missing groups." -ForegroundColor Green
}

if ($extraGroups) {
    Write-Host "`nGroups extra on target (will be removed):" -ForegroundColor Yellow
    $extraGroups | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "`nNo extra groups." -ForegroundColor Green
}

# Ask for confirmation to sync
$confirm = Read-Host "`nDo you want to update $targetUser's memberships to match $templateUser (Y/N)?"

if ($confirm -match '^[Yy]$') {
    # Add missing groups
    foreach ($group in $missingGroups) {
        try {
            Add-ADGroupMember -Identity $group -Members $targetUser -ErrorAction Stop
            Write-Host "Added $targetUser to $group" -ForegroundColor Green
        } catch {
            Write-Host ("Failed to add {0} to {1}: {2}" -f $targetUser, $group, $_.Exception.Message) -ForegroundColor Red
        }
    }

    # Remove extra groups
    foreach ($group in $extraGroups) {
        try {
            Remove-ADGroupMember -Identity $group -Members $targetUser -Confirm:$false -ErrorAction Stop
            Write-Host "Removed $targetUser from $group" -ForegroundColor Green
        } catch {
            Write-Host ("Failed to remove {0} from {1}: {2}" -f $targetUser, $group, $_.Exception.Message) -ForegroundColor Red
        }
    }

    Write-Host "`nMembership synchronization complete." -ForegroundColor Cyan
} else {
    Write-Host "`nNo changes were made." -ForegroundColor Cyan
}
