# Paul Ohashi
# TCI
# Deprovision user script

Import-Module ActiveDirectory
CLS
# ===== DEFINE DISABLED USERS OU =====
$DisabledUsersOU = "OU=Disabled Users,OU=Texas,DC=verticalcable,DC=local"

Write-Host "Terminate User"
Write-Host ""

# ===== PROMPT FOR USERNAME =====
$SamAccountName = Read-Host "Enter SamAccountName"

# ===== GET USER =====
try {
    $User = Get-ADUser $SamAccountName -Properties MemberOf, Description, DistinguishedName
}
catch {
    Write-Host "User not found." -ForegroundColor Red
    exit
}

# ===== PROMPT TO DISABLE USER =====
$DisableChoice = Read-Host "Disable user? (Y/N)"
$Comment = Read-Host "Comment:"

# ===== GENERATE RANDOM 32 CHARACTER PASSWORD =====
Add-Type -AssemblyName System.Web

$RandomPassword = [System.Web.Security.Membership]::GeneratePassword(32,8)

# ===== RESET PASSWORD =====
Set-ADAccountPassword `
    -Identity $User.SamAccountName `
    -Reset `
    -NewPassword (ConvertTo-SecureString $RandomPassword -AsPlainText -Force)

# ===== REMOVE GROUP MEMBERSHIPS =====
$GroupsRemoved = @()

# Get all groups except Domain Users
$Groups = Get-ADPrincipalGroupMembership $User |
    Where-Object { $_.Name -ne "Domain Users" }

foreach ($Group in $Groups) {

    try {
        Remove-ADGroupMember `
            -Identity $Group `
            -Members $User `
            -Confirm:$false

        $GroupsRemoved += $Group.Name
    }
    catch {
        Write-Host "Failed to remove from group: $($Group.Name)" -ForegroundColor Yellow
    }
}

# ===== UPDATE DESCRIPTION WITH TERMINATION DATE =====
$CurrentDescription = $User.Description

$TermDate = Get-Date -Format "MM/dd/yyyy"

if ([string]::IsNullOrWhiteSpace($CurrentDescription)) {
    $NewDescription = "Term Date: $TermDate"
}
else {
    $NewDescription = "$CurrentDescription | Term Date: $TermDate"
}

Set-ADUser `
    -Identity $User `
    -Description $NewDescription

# ===== DISABLE AND MOVE USER =====
if ($DisableChoice -match '^[Yy]$') {

    Disable-ADAccount -Identity $User

    Move-ADObject `
        -Identity $User.DistinguishedName `
        -TargetPath $DisabledUsersOU

    $UserDisabled = "YES"
}
else {
    $UserDisabled = "NO"
}

# ===== OUTPUT RESULTS =====
Write-Host ""
Write-Host "========== USER TERMINATION COMPLETE ==========" -ForegroundColor Cyan
Write-Host "Username: $($User.SamAccountName)"
Write-Host "Disabled: $UserDisabled"
Write-Host "Password changed to random 32-character value"
Write-Host "Updated Description: $NewDescription"
Write-Host "User moved to: $DisabledUsersOU"
Write-Host ""

Write-Host "Groups Removed:" -ForegroundColor Cyan

if ($GroupsRemoved.Count -eq 0) {
    Write-Host "None"
}
else {
    $GroupsRemoved | ForEach-Object {
        Write-Host "- $_"
    }
}

Write-Host "========== ACCESS CONTROL REVOKED ==========" -ForegroundColor Cyan
Write-Host "- Deleted Atlas Access Control account"
Write-Host ""
Write-Host "========== AUDIT ==========" -ForegroundColor Cyan
Write-Host "- Updated EmployeeActiveDirectoryAccounts.xlsx"
Write-Host ""
Write-Host "Comment: $Comment"