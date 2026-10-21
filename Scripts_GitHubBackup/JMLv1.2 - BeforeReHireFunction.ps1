# Paul Ohashi
# TCI
# JML script
#
# 8-24-26 - v1.2, Bug Fix: Updated the Get-ValueOrDefault() function to properly evaluate user input by passing $Value to :IsNullOrWhiteSpace().
# This corrects an issue where modified field values (OU, phone number, description, etc.) were reverting to their default values during
# validation. Modified the start date prompt to collect only the date and automatically build the AD description as "Start Date: <date>".
# This ensures a consistent Description field format while simplifying user input.
#
# 8-31-26 - v1.3, Added template user group cloning to New-Joiner.
# New users can inherit AD security-group memberships from an existing template user.
#
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
        Write-Host "4. Exit"

        $Choice = Read-Host "`nSelect an option"

        switch ($Choice) {

            "1" { New-Joiner }
            "2" { Update-Mover }
            "3" { Process-Leaver }
            "4" { break }

            default {
                Write-Host "Invalid selection." -ForegroundColor Red
            }
        }

        if ($Choice -ne "4") {
            Read-Host "`nPress ENTER to continue"
        }

    } while ($Choice -ne "4")