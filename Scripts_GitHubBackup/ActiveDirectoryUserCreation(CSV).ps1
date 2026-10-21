
# Active Directory user creation script
#
# Filename: ActiveDirectoryUserCreation(CSV).ps1
# Version 1.0
# Date: 5-1-2025
# Paul Ohashi, Trans Cable International
#
# This script serves two purposes: 
# 1. To create new AD User accounts for new employees.
# 2. To verify the EmployeeActiveDirectoryAccounts.xlsx file has parity with
#    the Trans Cable Users in Active Directory User Accounts
#
# NOTE: The employee spreadsheet exists on TCI IT SharePoint site in the following location:
#       (Documents > a > b > c)
#
# Usage:    1. Download EmployeeActiveDirectoryAccounts.xlsx as a .csv file.
#              (this may work as .xlsx, but I had issues while testing). 
#           2. Update the $usersRaw variable with the path and filename of the downloaded .csv spreadsheet.
#           3. Verify the $targetOU is where you want new users created.
#           4. Run this script.
#
# NOTE: Version 2.0 will read the spreadsheet from SharePoint directly (no need to download and convert to .csv).
#
# Define the target OU
$targetOU = "OU=TestDev,OU=Texas,DC=verticalcable,DC=local"

# Load users from CSV
# $usersRaw = Import-Csv -Path "C:\Users\paulo\Desktop\ActiveDirectory\TestDev\EmployeeActiveDirectoryAccounts10-10-25.csv"

$csvPath = Read-Host "Drag and drop your CSV file here"
$usersRaw = Import-Csv -Path $csvPath



# Debug: Show headers once
Write-Host "Detected Columns:" -ForegroundColor Cyan
$usersRaw[0].PSObject.Properties.Name | ForEach-Object { Write-Host " - $_" }

# Main loop
foreach ($user in $usersRaw) {
    $sam = $user.'sAMAccountName'.Trim()

    # Validate sAMAccountName
    if (-not $sam -or $sam -match '[^a-zA-Z0-9.-]') {
        Write-Host "Skipping: Invalid or missing sAMAccountName for '$($user.'Employee Name')'" -ForegroundColor Yellow
        continue
    }

    $existingUser = Get-ADUser -Filter { SamAccountName -eq $sam } -ErrorAction SilentlyContinue

    if ($existingUser) {
        Write-Host "User '$sam' already exists. Updating attributes..." -ForegroundColor Cyan

        try {
            Set-ADUser -Identity $sam `
                -Title $user.'Job Title'.Trim() `
                -Department $user.'Department'.Trim() `
                -EmployeeID $user.'Employee ID'.Trim() `
                -UserPrincipalName ($sam + "@transcableusa.com") `
                -Description "Start Date: $($user.'Start Date')"

            # Update extensionAttributes only if values are provided
            $otherAttributes = @{}
            if ($user.'Employment Status')             { $otherAttributes['extensionAttribute1'] = $user.'Employment Status'.Trim() }
            if ($user.'System Access')                 { $otherAttributes['extensionAttribute2'] = $user.'System Access'.Trim() }
            if ($user.'Role-Based Access Level')       { $otherAttributes['extensionAttribute3'] = $user.'Role-Based Access Level'.Trim() }
            if ($user.'MFA Enabled')                   { $otherAttributes['extensionAttribute4'] = $user.'MFA Enabled'.Trim() }
            if ($user.'Background Check Complete')     { $otherAttributes['extensionAttribute5'] = $user.'Background Check Complete'.Trim() }

            if ($otherAttributes.Count -gt 0) {
                Set-ADUser -Identity $sam -Replace $otherAttributes
            }

            Write-Host "Updated user: $($user.'Employee Name')" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to update user: $($user.'Employee Name') - $_" -ForegroundColor Red
        }

        continue
    }

    # For new users, set secure password
    $securePassword = ConvertTo-SecureString "Xy!9z@T2#kL7&mQp" -AsPlainText -Force

    try {
        New-ADUser `
            -Name $user.'Employee Name'.Trim() `
            -SamAccountName $sam `
            -UserPrincipalName ($sam + "@transcableusa.com") `
            -AccountPassword $securePassword `
            -Enabled $true `
            -GivenName ($user.'Employee Name' -split ' ')[0] `
            -Surname ($user.'Employee Name' -split ' ')[1] `
            -Title $user.'Job Title'.Trim() `
            -Department $user.'Department'.Trim() `
            -EmployeeID $user.'Employee ID'.Trim() `
            -Description "Start Date: $($user.'Start Date')" `
            -Path $targetOU

        # Now apply optional attributes after creation
        $otherAttributes = @{}
        if ($user.'Employment Status')             { $otherAttributes['extensionAttribute1'] = $user.'Employment Status'.Trim() }
        if ($user.'System Access')                 { $otherAttributes['extensionAttribute2'] = $user.'System Access'.Trim() }
        if ($user.'Role-Based Access Level')       { $otherAttributes['extensionAttribute3'] = $user.'Role-Based Access Level'.Trim() }
        if ($user.'MFA Enabled')                   { $otherAttributes['extensionAttribute4'] = $user.'MFA Enabled'.Trim() }
        if ($user.'Background Check Complete')     { $otherAttributes['extensionAttribute5'] = $user.'Background Check Complete'.Trim() }

        if ($otherAttributes.Count -gt 0) {
            Set-ADUser -Identity $sam -Replace $otherAttributes
        }

        Write-Host "Created user: $($user.'Employee Name')" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to create user: $($user.'Employee Name') - $_" -ForegroundColor Red
    }
}
