<# Paul Ohashi
TCI
JML script

8-24-26 - v1.2, Bug Fix: Updated the Get-ValueOrDefault() function to properly evaluate user input by passing $Value to :IsNullOrWhiteSpace().
This corrects an issue where modified field values (OU, phone number, description, etc.) were reverting to their default values during
validation. Modified the start date prompt to collect only the date and automatically build the AD description as "Start Date: <date>".
This ensures a consistent Description field format while simplifying user input.

8-31-26 - v1.3, Added template user logic for group cloning to new hire (joiner) functions.
New users can inherit AD security-group memberships from an existing template user.

10-16-26 - v1.4, Added a re-hire function. Works almost as expected. A couple minor bug fixes are needed:
    * Somewhere in the rehire logic a user input hangs and you have to hit the enter button another time.
    * The script exits after the re-hire function completes, instead of returning to the menu.
    * Old bug, but still needs to be addressed is to ignore the Domain Users group when updating group membership.
#>

Import-Module ActiveDirectory
CLS

function New-Joiner {

    function Get-ValueOrDefault {
        param(
            [string]$Prompt,
            [string]$Default
        )

        $Value = Read-Host "$Prompt [$Default]"

        if ([string]::IsNullOrWhiteSpace($Value)) {
            return $Default
        }

        return $Value
    }

    Write-Host "`n=== NEW JOINER ===" -ForegroundColor Green

    # General Tab
    $FirstName = Read-Host "First Name"
    $LastName  = Read-Host "Last Name"

    # Organization
    $Title      = Read-Host "Job Title"
    $Department = Read-Host "Department"
    $ManagerSam = Read-Host "Manager Username"

    # Attributes
    $employeeID = Read-Host "Employee ID"

    # Defaults (modifiable)
    $UPNDomain = Get-ValueOrDefault `
        "UPN Domain" `
        "transcableusa.com"

    $OU = Get-ValueOrDefault `
        "OU Path" `
        "OU=TestDev,OU=Texas,DC=verticalcable,DC=local"

    $Office = Get-ValueOrDefault `
        "Office Location" `
        "Bonham TX"

    $Telephone = Get-ValueOrDefault `
        "Telephone Number" `
        "903-449-4622"

    $Company = Get-ValueOrDefault `
        "Company" `
        "Trans Cable International"

    $WebPage = Get-ValueOrDefault `
        "Website" `
        "https://transcableusa.com"

    # Generated values
    $SamAccountName = Get-ValueOrDefault `
        "SamAccountName" `
        "$($FirstName.Trim()).$($LastName.Trim())"

    $DisplayName = Get-ValueOrDefault `
        "Display Name" `
        "$FirstName $LastName"

    $Email = Get-ValueOrDefault `
        "Email Address" `
        "$SamAccountName@$UPNDomain"

    $StartDate = Get-ValueOrDefault `
        "Start Date" `
        (Get-Date -Format 'M/d/yy')

    $Description = "Start Date: $StartDate"

    # Password
    $Password = Read-Host "Temporary Password" -AsSecureString

    # Template User
    Write-Host ""
    $TemplateSam = Read-Host "Template User Username (leave blank for no group cloning)"

    # Summary
    Write-Host ""
    Write-Host "========== REVIEW ==========" -ForegroundColor Cyan
    Write-Host "Name:          $DisplayName"
    Write-Host "Username:      $SamAccountName"
    Write-Host "Employee ID:   $employeeID"
    Write-Host "Email:         $Email"
    Write-Host "Title:         $Title"
    Write-Host "Department:    $Department"
    Write-Host "Manager:       $ManagerSam"
    Write-Host "Office:        $Office"
    Write-Host "Phone:         $Telephone"
    Write-Host "Company:       $Company"
    Write-Host "OU:            $OU"
    Write-Host "Website:       $WebPage"
    Write-Host "Description:   $Description"

    if ([string]::IsNullOrWhiteSpace($TemplateSam)) {
        Write-Host "Template User: None"
    }
    else {
        Write-Host "Template User: $TemplateSam"
    }

    Write-Host ""

    $Confirm = Read-Host "Create user? (Y/N)"

    if ($Confirm -notmatch '^[Yy]$') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }

    try {

        # Validate Manager
        $ManagerDN = (Get-ADUser $ManagerSam -ErrorAction Stop).DistinguishedName

        # Validate Template User if one was provided
        $TemplateUser = $null

        if (-not [string]::IsNullOrWhiteSpace($TemplateSam)) {

            try {
                $TemplateUser = Get-ADUser `
                    -Identity $TemplateSam `
                    -Properties MemberOf `
                    -ErrorAction Stop

                Write-Host "`nTemplate user found: $($TemplateUser.Name)" -ForegroundColor Cyan
            }
            catch {
                Write-Host "`nTemplate user '$TemplateSam' was not found." -ForegroundColor Red
                Write-Host "User was NOT created." -ForegroundColor Red
                return
            }
        }

        # Create the new AD user
        New-ADUser `
            -Name $DisplayName `
            -GivenName $FirstName `
            -Surname $LastName `
            -DisplayName $DisplayName `
            -employeeID $employeeID `
            -SamAccountName $SamAccountName `
            -UserPrincipalName "$SamAccountName@$UPNDomain" `
            -Path $OU `
            -Office $Office `
            -OfficePhone $Telephone `
            -EmailAddress $Email `
            -Description $Description `
            -HomePage $WebPage `
            -Title $Title `
            -Department $Department `
            -Company $Company `
            -Manager $ManagerDN `
            -AccountPassword $Password `
            -Enabled $true `
            -ChangePasswordAtLogon $true `
            -ErrorAction Stop

        Write-Host "`nUser created successfully." -ForegroundColor Green

        # ============================================================
        # CLONE TEMPLATE USER GROUP MEMBERSHIPS
        # ============================================================

        if ($null -ne $TemplateUser) {

            Write-Host ""
            Write-Host "=== CLONING GROUP MEMBERSHIPS ===" -ForegroundColor Cyan
            Write-Host "Template User: $($TemplateUser.SamAccountName)"
            Write-Host "New User:      $SamAccountName"
            Write-Host ""

            # Groups that should NEVER be copied to a new user
            $ExcludedGroups = @(
                "Domain Admins",
                "Enterprise Admins",
                "Schema Admins",
                "Administrators",
                "Account Operators",
                "Backup Operators",
                "Server Operators",
                "Print Operators"
            )

            try {

                # Get the template user's direct group memberships
                $TemplateGroups = Get-ADPrincipalGroupMembership `
                    -Identity $TemplateUser `
                    -ErrorAction Stop |
                    Where-Object {
                        $_.GroupCategory -eq "Security" -and
                        $_.Name -notin $ExcludedGroups
                    }

                if ($TemplateGroups.Count -eq 0) {

                    Write-Host "No security groups found to copy." -ForegroundColor Yellow
                }
                else {

                    Write-Host "Groups to be copied:" -ForegroundColor White

                    foreach ($Group in $TemplateGroups) {
                        Write-Host "  $($Group.Name)"
                    }

                    Write-Host ""

                    $CopyConfirm = Read-Host "Copy these group memberships? (Y/N)"

                    if ($CopyConfirm -match '^[Yy]$') {

                        foreach ($Group in $TemplateGroups) {

                            try {

                                Add-ADGroupMember `
                                    -Identity $Group `
                                    -Members $SamAccountName `
                                    -ErrorAction Stop

                                Write-Host "[OK] $($Group.Name)" -ForegroundColor Green
                            }
                            catch {

                                Write-Host "[FAILED] $($Group.Name): $($_.Exception.Message)" `
                                    -ForegroundColor Red
                            }
                        }

                        Write-Host ""
                        Write-Host "Group cloning complete." -ForegroundColor Green
                    }
                    else {

                        Write-Host "Group cloning cancelled." -ForegroundColor Yellow
                    }
                }
            }
            catch {

                Write-Host "Unable to retrieve template user's group memberships." `
                    -ForegroundColor Red

                Write-Host $_.Exception.Message -ForegroundColor Red
            }
        }
        else {

            Write-Host "`nNo template user specified. Group memberships were not cloned." `
                -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "========== JOINER COMPLETE ==========" -ForegroundColor Green
        Write-Host "Name:     $DisplayName"
        Write-Host "Username: $SamAccountName"
        Write-Host ""

    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

<#
Sometimes ex-employees come back and that's what this function is for. When employees leave TCI their AD account is
disabled, their password is changed to a random 32 character value, their account is moved from the Texas OU to the
Disabled Users sub-OU, and all group membership is removed (except for Domain Users).

If they come back this function is used.
#>
function Process-Rehire {

    Write-Host "`n=== RE-HIRE ===" -ForegroundColor Green

    # Search for the former employee
    $Search = Read-Host "Former employee Username or Employee ID"

    if ([string]::IsNullOrWhiteSpace($Search)) {
        Write-Host "Search value is required." -ForegroundColor Red
        return
    }

    try {
        # Try username first
        $User = Get-ADUser -Identity $Search `
            -Properties EmployeeID, Description, Enabled, MemberOf `
            -ErrorAction SilentlyContinue

        # If not found, search by Employee ID
        if ($null -eq $User) {
            $Matches = @(
                Get-ADUser -Filter { EmployeeID -eq $Search } `
                    -Properties EmployeeID, Description, Enabled, MemberOf `
                    -ErrorAction Stop
            )

            if ($Matches.Count -eq 0) {
                Write-Host "No matching employee found." -ForegroundColor Red
                return
            }

            if ($Matches.Count -gt 1) {
                Write-Host "Multiple accounts match this Employee ID." `
                    -ForegroundColor Red
                Write-Host "Resolve the duplicate records before proceeding."
                return
            }

            $User = $Matches[0]
        }
    }
    catch {
        Write-Host "Unable to search Active Directory." -ForegroundColor Red
        Write-Host $_.Exception.Message
        return
    }

    # Show existing account details
    Write-Host "`n========== EXISTING ACCOUNT ==========" `
        -ForegroundColor Cyan
    Write-Host "Name:        $($User.Name)"
    Write-Host "Username:    $($User.SamAccountName)"
    Write-Host "Employee ID: $($User.EmployeeID)"
    Write-Host "Enabled:     $($User.Enabled)"
    Write-Host "Description: $($User.Description)"
    Write-Host "OU:          $(($User.DistinguishedName -split ',',2)[1])"

    # Do not accidentally process an active employee
    if ($User.Enabled) {
        Write-Host "`nAccount is already enabled. Aborting." `
            -ForegroundColor Yellow
        return
    }

    $ConfirmIdentity = Read-Host `
        "`nIs this the correct former employee? (Y/N)"

    if ($ConfirmIdentity -notmatch '^[Yy]$') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }

    # Collect current employment information
    $FirstName  = Read-Host "First Name"
    $LastName   = Read-Host "Last Name"
    $Title      = Read-Host "Current Job Title"
    $Department = Read-Host "Current Department"
    $ManagerSam = Read-Host "Current Manager Username"
    $Office     = Read-Host "Office Location"
    $Telephone  = Read-Host "Telephone Number"
    $Company    = Read-Host "Company"

    $DefaultDomain = "transcableusa.com"
    $UPNDomain = Read-Host "UPN Domain [$DefaultDomain]"

    if ([string]::IsNullOrWhiteSpace($UPNDomain)) {
        $UPNDomain = $DefaultDomain
    }

    $WebPage = Read-Host "Website [https://transcableusa.com]"

    if ([string]::IsNullOrWhiteSpace($WebPage)) {
        $WebPage = "https://transcableusa.com"
    }

    $NewOU = Read-Host "Active OU distinguished name"

    if ([string]::IsNullOrWhiteSpace($NewOU)) {
        Write-Host "An active OU is required." -ForegroundColor Red
        return
    }

    $RehireDate = Read-Host `
        "Re-hire Date [$(Get-Date -Format 'M/d/yy')]"

    if ([string]::IsNullOrWhiteSpace($RehireDate)) {
        $RehireDate = Get-Date -Format 'M/d/yy'
    }

    # Validate manager and destination OU
    try {
        $Manager = Get-ADUser -Identity $ManagerSam `
            -ErrorAction Stop

        Get-ADOrganizationalUnit -Identity $NewOU `
            -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "Manager or destination OU validation failed." `
            -ForegroundColor Red
        Write-Host $_.Exception.Message
        return
    }

    # Set display name and retain the existing account identity
    $DisplayName = "$FirstName $LastName"
    $NewUPN = "$($User.SamAccountName)@$UPNDomain"
    $NewEmail = $NewUPN

    # Preserve the former employment history
    $OldDescription = $User.Description
    $NewDescription = "Rehire Date: $RehireDate"

    if (-not [string]::IsNullOrWhiteSpace($OldDescription)) {
        $NewDescription = "$OldDescription | $NewDescription"
    }

    # Require a new temporary password
    $Password = Read-Host "New Temporary Password" -AsSecureString

    # Optional group template
    $TemplateSam = Read-Host `
        "Template User Username (blank to skip group cloning)"

    $TemplateUser = $null

    if (-not [string]::IsNullOrWhiteSpace($TemplateSam)) {
        try {
            $TemplateUser = Get-ADUser -Identity $TemplateSam `
                -Properties MemberOf -ErrorAction Stop
        }
        catch {
            Write-Host "Template user not found. Aborting." `
                -ForegroundColor Red
            return
        }
    }

    # Review before making changes
    Write-Host "`n========== RE-HIRE REVIEW ==========" `
        -ForegroundColor Cyan
    Write-Host "Name:        $DisplayName"
    Write-Host "Username:    $($User.SamAccountName) (existing account)"
    Write-Host "Employee ID: $($User.EmployeeID)"
    Write-Host "UPN:         $NewUPN"
    Write-Host "Email:       $NewEmail"
    Write-Host "Title:       $Title"
    Write-Host "Department:  $Department"
    Write-Host "Manager:     $($Manager.SamAccountName)"
    Write-Host "Office:      $Office"
    Write-Host "Phone:       $Telephone"
    Write-Host "Company:     $Company"
    Write-Host "Destination: $NewOU"
    Write-Host "Description: $NewDescription"
    Write-Host "Group Template: $(if ($TemplateUser) {
        $TemplateUser.SamAccountName
    } else { 'None' })"

    $Confirm = Read-Host "`nProceed with re-hire? (Y/N)"

    if ($Confirm -notmatch '^[Yy]$') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }

    try {
        # Update employment attributes without creating a new account
        Set-ADUser -Identity $User `
            -GivenName $FirstName `
            -Surname $LastName `
            -DisplayName $DisplayName `
            -UserPrincipalName $NewUPN `
            -EmailAddress $NewEmail `
            -Title $Title `
            -Department $Department `
            -Manager $Manager.DistinguishedName `
            -Office $Office `
            -OfficePhone $Telephone `
            -Company $Company `
            -HomePage $WebPage `
            -Description $NewDescription `
            -ErrorAction Stop

        # Set new credentials
        Set-ADAccountPassword -Identity $User `
            -Reset `
            -NewPassword $Password `
            -ErrorAction Stop

        # Move account to its active OU
        Move-ADObject -Identity $User.DistinguishedName `
            -TargetPath $NewOU -ErrorAction Stop

        # Require password change at next logon
        Set-ADUser -Identity $User.SamAccountName `
            -ChangePasswordAtLogon $true -ErrorAction Stop

        # Enable only after preceding operations succeed
        Enable-ADAccount -Identity $User.SamAccountName `
            -ErrorAction Stop

        Write-Host "`nAccount re-hired successfully." `
            -ForegroundColor Green
    }
    catch {
        Write-Host "`nRe-hire operation encountered an error." `
            -ForegroundColor Red
        Write-Host $_.Exception.Message
        Write-Host "Review the account state before retrying."
        return
    }

    # Optional group membership cloning
    if ($null -ne $TemplateUser) {

        $ExcludedGroups = @(
            "Domain Admins",
            "Enterprise Admins",
            "Schema Admins",
            "Administrators",
            "Account Operators",
            "Backup Operators",
            "Server Operators",
            "Print Operators"
        )

        try {
            $Groups = Get-ADPrincipalGroupMembership `
                -Identity $TemplateUser -ErrorAction Stop |
                Where-Object {
                    $_.GroupCategory -eq "Security" -and
                    $_.Name -notin $ExcludedGroups
                }

            Write-Host "`nGroups available to copy:" `
                -ForegroundColor Cyan

            $Groups | ForEach-Object { Write-Host " - $($_.Name)" }

            $CopyConfirm = Read-Host "Copy these groups? (Y/N)"

            if ($CopyConfirm -match '^[Yy]$') {
                foreach ($Group in $Groups) {
                    try {
                        Add-ADGroupMember -Identity $Group `
                            -Members $User.SamAccountName `
                            -ErrorAction Stop

                        Write-Host "[OK] $($Group.Name)" `
                            -ForegroundColor Green
                    }
                    catch {
                        Write-Host "[FAILED] $($Group.Name): $($_.Exception.Message)" `
                            -ForegroundColor Yellow
                    }
                }
            }
        }
        catch {
            Write-Host "Unable to retrieve template groups." `
                -ForegroundColor Yellow
            Write-Host $_.Exception.Message
        }
    }

    Write-Host "`n========== RE-HIRE COMPLETE ==========" `
        -ForegroundColor Green
    Write-Host "Username: $($User.SamAccountName)"
    Write-Host "Verify M365, email groups, Rubicon, and application access."
}


function Update-Mover {

    Write-Host "`n=== MOVER ===" -ForegroundColor Yellow

    $User = Read-Host "Username of employee [sAMAccountName]"

    try {
        Get-ADUser $User -Properties * | Out-Null
    }
    catch {
        Write-Host "User not found." -ForegroundColor Red
        return
    }

    $Title = Read-Host "New Title"
    $Department = Read-Host "New Department"
    $ManagerSam = Read-Host "New Manager Username"

    try {
        $ManagerDN = (Get-ADUser $ManagerSam).DistinguishedName

        Set-ADUser $User `
            -Title $Title `
            -Department $Department `
            -Manager $ManagerDN

        Write-Host "`nUser updated successfully." -ForegroundColor Green
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}
```


function Process-Leaver {
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
        Write-Host "- Disable Rubicon access"
        Write-Host ""
        Write-Host "========== AUDIT ==========" -ForegroundColor Cyan
        Write-Host "- Updated EmployeeActiveDirectoryAccounts.xlsx"
        Write-Host "- Confirm M365 license removal"
        Write-Host "- Confirm M365 distribution lists and email groups"
        Write-Host "Comment: $Comment"
    }

    do {

        Clear-Host

        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host " JOINER | MOVER | LEAVER TOOL"
        Write-Host "======================================"
        Write-Host "1. Joiner"
        Write-Host "2. Mover"
        Write-Host "3. Leaver"
        Write-Host "4. Re-hire"
        Write-Host "5. Exit"

        $Choice = Read-Host "`nSelect an option"

        switch ($Choice) {

            "1" { New-Joiner }
            "2" { Update-Mover }
            "3" { Process-Leaver }
            "4" { Process-Rehire }
            "5" { break }

            default {
                Write-Host "Invalid selection." -ForegroundColor Red
            }
        }

        if ($Choice -ne "4") {
            Read-Host "`nPress ENTER to continue"
        }

    } while ($Choice -ne "4")