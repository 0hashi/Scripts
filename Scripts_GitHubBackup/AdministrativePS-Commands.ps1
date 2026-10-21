#PO - Get/Set Execution Policy (RemoteSigned or Unrestricted)
Get-ExecutionPolicy
Set-ExecutionPolicy Unrestricted

#--------------------------------------------------------------------
#PO - AzureAD/Entra ID & Microsoft Graph PowerShell Modules. The AzureAD Module is being replaced by the MS Graph Powershell Module
#
# Depending on which module you want to use (AzureAD or Microsoft Graph API) make sure the module is installed.
#
# Import the AzureAD, or Microsoft Graph module and connect before running queries.

#PO - If needed, install and import the AzureAD PowerShell Module
Install-Module AzureAD
Import-Module AzureAD

#PO - Connect to AzureAD
Connect-AzureAD
#------------------------------
#PO - If needed, install and import Microsoft Graph API
Install-Module -Name Microsoft.Graph -Force
Import-Module Microsoft.Graph

#PO - Connect/Authenticate Microsoft Graph
Connect-MgGraph


#--------------------------------------------------------------------
# System Administration Commands
#--------------------------------------------------------------------

# REMOTE COMMANDS
Invoke-Command -ComputerName 10.100.105.57 -ScriptBlock { systeminfo | find "System Boot Time" }

#--------------------------------------------------------------------

#PO - Get AD User info
Get-ADUser announcement1

#--------------------------------------------------------------------

#PO - Get the domain role of a system
# - 0x0: Standalone workstation
# - 0x1: Member workstation
# - 0x2: Standalone server
# - 0x3: Member server
# - 0x4: Backup domain controller
# - 0x5: Primary domain controller

wmic computersystem get DomainRole

#--------------------------------------------------------------------

#PO - Who's logged on, where?
qwinsta /server:10.100.105.57 | Where-Object {$_ -notmatch "SYSTEM"}

#--------------------------------------------------------------------

#PO - Search Security Event log for logons in the last (x) days.
Get-EventLog -LogName Security | Where-Object {$_.EventID -eq 4624} | Select-Object -Property @{Name='TimeGenerated';Expression={$_.TimeGenerated}}, @{Name='User';Expression={$_.ReplacementStrings[5]}} | Sort-Object TimeGenerated -Descending | Where-Object {$_.TimeGenerated -ge (Get-Date).AddDays(-5)} | Where-Object {$_ -notmatch "SYSTEM"}

#--------------------------------------------------------------------
# Get a list of AD users in the Texas OU
Get-ADUser -Filter * -SearchBase "OU=Texas,DC=verticalcable,DC=local" | Select-Object Name, DistinguishedName | Sort-Object Name

#--------------------------------------------------------------------

#PO - Display the number of disabled user accounts.
Search-ADAccount -AccountDisabled -UsersOnly -SearchBase "OU=Texas,DC=verticalcable,DC=local" | FT Name, DistinguishedName | Measure-Object -Line
#PO - Display the disabled user accounts.
Search-ADAccount -AccountDisabled -UsersOnly -SearchBase "OU=Texas,DC=verticalcable,DC=local" | Sort-Object -Property Name | FT Name, DistinguishedName 

#--------------------------------------------------------------------

#PO - Get a list of AzureAD subscriptions
Get-AzureADSubscribedSku 

#--------------------------------------------------------------------

#PO - Get a list of users and their assigned license SKUs
Connect-AzureAD
Get-AzureADUser -All $true | ForEach-Object {
    $user = $_

    $licenses = Get-AzureADUserLicenseDetail -ObjectId $user.ObjectId
    $licenses | ForEach-Object {
        [PSCustomObject]@{
            UserPrincipalName = $user.UserPrincipalName
            DisplayName       = $user.DisplayName
            LicenseSku        = $_.SkuPartNumber
        }
    }
} | Format-Table -AutoSize  >AzureADUserLicenseDetails.cvs

#--------------------------------------------------------------------

# Shutdown Windows systems remotely.
# Comma delimited list of computers to shut down
$ComputerNames = @("e6workstation")

# Credentials for remote access
$Credential = Get-Credential

# Iterate through each computer and attempt to shut it down
foreach ($Computer in $ComputerNames) {
    try {
        Write-Host "Attempting to shut down $Computer..." -ForegroundColor Yellow
        Stop-Computer -ComputerName $Computer -Credential $Credential -Force -Confirm:$false
        Write-Host "$Computer has been shut down successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to shut down $Computer. Error: $_" -ForegroundColor Red
    }
}

#--------------------------------------------------------------------

#PO - Execute remote PowerShell cmd
Invoke-Command -ComputerName design1 -ScriptBlock { Get-LocalGroupMember -Group $GroupName }

#--------------------------------------------------------------------
# Shutdown Windows with WMIC
Invoke-Command -ComputerName computername -ScriptBlock { shutdown /s /t 0 }

#--------------------------------------------------------------------

#PO - Backup DNS
# Specify the DNS server and zone
Import-Module DnsServer
$DnsServer = "verttxdc001"
$ZoneName = "verticalcable.local"

# Export the zone
Export-DnsServerZone -Name $ZoneName -FileName "$ZoneName.dns" -ComputerName $DnsServer
Write-Output "Exported zone $ZoneName to $ZoneName.dns"

# Specify the DNS server
$DnsServer = "verttxdc001"

# List all zones to verify the zone name
Get-DnsServerZone -ComputerName $DnsServer

#--------------------------------------------------------------------

$ZoneName = "verticalcable.local"
$DnsServer = "VERTTXDC001.verticalcable.local"

# Get all A records in the specified zone
$ARecords = Get-DnsServerResourceRecord -ZoneName $ZoneName -ComputerName $DnsServer | Where-Object RecordType -eq "A"

# Group A records by IP address
$Duplicates = $ARecords | Group-Object -Property RecordData -NoElement | Where-Object Count -gt 1

# Display duplicates
$Duplicates | ForEach-Object {
    Write-Output "Duplicate IP Address: $($_.Name) - Count: $($_.Count)"
}

#--------------------------------------------------------------------

Get-DhcpServerv4Reservation -ComputerName "10.100.104.7" -ScopeId 10.100.104.0

#--------------------------------------------------------------------

# Find users in specific privileged groups and print the results to STDOOUT and if selected
# to the default printer
$privilegedGroups = "Domain Admins", "Enterprise Admins", "Schema Admins", "Administrators"
$privilegedAccts = foreach ($group in $privilegedGroups) {
    Get-ADGroupMember -Identity $group | Select-Object Name, SamAccountName, DistinguishedName,@{Name='Group';Expression={$group}}
}
$privilegedAccts = $privilegedAccts | Sort-Object -Property Name 

# Output and print the results
Write-Output $privilegedAccts | Format-Table -AutoSize

###$privilegedAccts | Export-Csv -Path "TCI_PrivilegedAccounts.csv" -NoTypeInformation
###Out-Printer -InputObject $privilegedAccts

#--------------------------------------------------------------------

# Find users with adminCount attribute set to 1
Get-ADUser -Filter "adminCount -eq 1" | Select-Object Name, SamAccountName, Enabled | Sort-Object -Property Name

#--------------------------------------------------------------------

# Find users with specific rights (e.g., reset password)
Get-ADObject -Filter 'objectClass -eq "user"' -Properties userAccountControl | 
    Where-Object {$_.userAccountControl -band 0x10000} | 
    Select-Object Name, SamAccountName, Enabled |Sort-Object -Property Name

#--------------------------------------------------------------------

# Find disabled users in OU and move to another OU
# Specify the source and destination OUs
$sourceOU = "OU=Texas,DC=verticalcable,DC=local"
$destinationOU = "OU=Disabled Users,OU=Texas,DC=verticalcable,DC=local"

# Get all disabled users in the source OU
$disabledUsers = Get-ADUser -SearchBase $sourceOU -Filter {Enabled -eq $false}

# Move each disabled user to the destination OU
foreach ($user in $disabledUsers) {
    #Move-ADObject -Identity $user.DistinguishedName -TargetPath $destinationOU
    Write-Output $user "moved to " $destinationOU
    Write-Output "---------------------------------"
}

# Get the Group Membership of a user object
Get-ADPrincipalGroupMembership lead.operator | Select-Object name
Get-ADPrincipalGroupMembership -Identity lead.operator | Get-ADGroupMember



$username = "lead.operator"  # Replace with the actual username
$userGroups = Get-ADPrincipalGroupMembership -Identity $username  

foreach ($group in $userGroups) {
    Write-Host "Group: $($group.Name)"
        $nestedGroups = Get-ADGroupMember -Identity $group.Name | Where-Object { $_.ObjectClass -eq "group" }
            foreach ($nestedGroup in $nestedGroups) {
                    Write-Host "  - $($nestedGroup.Name)"
    }
}

#--------------------------------------------------------------------
$user = "paul.ohashi"
$groups = Get-ADPrincipalGroupMembership -Identity $user 


# Get the members of each group
foreach ($group in $groups) {
    Write-Host "Members of group $($group.Name):"
    Get-ADGroupMember -Identity $group.Name
}

#--------------------------------------------------------------------
#PO - Get group membership of user
Get-ADPrincipalGroupMembership -Identity "tw-exp" | Select-Object name | Write-Host 

#--------------------------------------------------------------------

$User = "lead.operator"


$Groups = Get-ADUser -Identity $User | Get-ADPrincipalGroupMembership
$Groups | ForEach-Object {
    Get-ADGroup -Identity $_.DistinguishedName -Properties MemberOf
} | Select Name

Get-ADUser -Identity $User | Get-ADPrincipalGroupMembership | Select-Object Name


Get-ADUser -Filter { extensionAttribute1 -notlike "*" } -Properties extensionAttribute1

#--------------------------------------------------------------------

# Get all disabled users. Good for STDOUT or printing
$disabledUsers = Get-ADUser -Filter * -Properties Enabled, MemberOf | Where-Object {$_.Enabled -eq $false}

# For each disabled user, get their group memberships
foreach ($user in $disabledUsers) {
    Write-Host "Disabled User: $($user.Name)"
    $groups = $user.MemberOf | Get-ADGroup -Properties Name
    foreach ($group in $groups) {
        Write-Host "  - Member of: $($group.Name)"
    }
    Write-Host ""
}

#--------------------------------------------------------------------

# Get all disabled users and their group membership and print the output to
# C:\inetpub\wwwroot\activedirectory\logs\disabled_users_and_groups.csv
# This script runs via Task Scheduler twice a day at 0400 and 1600.
Import-Module ActiveDirectory

$disabledUsers = Get-ADUser -Filter {Enabled -eq $false} -Properties MemberOf

$report = @()

foreach ($user in $disabledUsers) {
    $groups = $user.MemberOf | ForEach-Object {
        (Get-ADGroup $_).Name
    }

    $report += [PSCustomObject]@{
        UserName = $user.SamAccountName
        Groups   = $groups -join ","
    }
}
$logRotateDate = Get-Date -format "yyyyMMddhhmmss"
Copy-Item -Path "C:\inetpub\wwwroot\activedirectory\logs\disabled_users_and_groups.csv" -Destination "C:\inetpub\wwwroot\activedirectory\logs\disabled_users_and_groups.$logRotateDate.csv"
$report | Export-Csv -Path "C:\inetpub\wwwroot\activedirectory\logs\disabled_users_and_groups.csv" -NoTypeInformation

#--------------------------------------------------------------------

# List all active AD users and their group membership, ignore errors
# and print output to C:\inetpub\wwwroot\activedirectory\logs\active_users_and_groups.csv
# Import the Active Directory module
# Import Active Directory module
Import-Module ActiveDirectory

# Get all active users from Active Directory
$ActiveUsers = Get-ADUser -Filter {Enabled -eq $true} -Properties MemberOf, DisplayName | Sort-Object Name

# Iterate through each active user to get their group memberships
$Result = foreach ($User in $ActiveUsers) {
    # Fetch the user's groups
    $Groups = $User.MemberOf | ForEach-Object {
        (Get-ADGroup $_).Name
    }

    # Create a custom object with user details and group memberships
    [PSCustomObject]@{
        UserName   = $User.SamAccountName
        DisplayName = $User.DisplayName
        Groups     = $Groups -join ", " # Join group names into a comma-separated string
    }
}
# If an active_users_and_groups.csv file exists in the log directory, roll it over and create a new one.
# Output the result to the console and to C:\inetpub\wwwroot\activedirectory\logs\active_users_and_groups.csv
$logFile = "C:\inetpub\wwwroot\activedirectory\logs\active_users_and_groups.csv"

if (Test-Path $logFile) {
    $logRotateDate = Get-Date -format "yyyyMMddhhmmss"
    Copy-Item -Path "$logFile" -Destination "$logFile.$logRotateDate.csv"
}

$Result | Sort-Object UserName | Format-Table -AutoSize
$Result | Export-Csv -Path "C:\inetpub\wwwroot\activedirectory\logs\active_users_and_groups.csv" -NoTypeInformation



Import-Module ActiveDirectory

$disabledUsers = Get-ADUser -Filter {Enabled -eq $false} -Properties MemberOf

$report = @()

foreach ($user in $disabledUsers) {
    $groups = $user.MemberOf | ForEach-Object {
        (Get-ADGroup $_).Name
    }

    $report += [PSCustomObject]@{
        UserName = $user.SamAccountName
        Name     = $user.Name
        DN       = $user.DistinguishedName
        Groups   = $groups -join ","
    }
}
#$copyDate = Get-Date -format "yyyyMMddhhmmss"
#Copy-Item -Path "C:\inetpub\wwwroot\activedirectory\logs\disabled_users_and_groups.csv" -Destination "C:\inetpub\wwwroot\activedirectory\logs\disabled_users_and_groups.$copyDate.csv"
$report



Import-Module ActiveDirectory

$disabledUsers = Get-ADUser -Filter {Enabled -eq $false} -Properties MemberOf

$report = @()

foreach ($user in $disabledUsers) {
    $groups = $user.MemberOf | ForEach-Object {
        (Get-ADGroup $_).Name
    }

    $report += [PSCustomObject]@{
        UserName = $user.SamAccountName
        Name     = $user.Name
        DN	     = $user.DistinguishedName
        Groups   = $groups -join ","
    }
}
#$copyDate = Get-Date -format "yyyyMMddhhmmss"
#Copy-Item -Path "C:\inetpub\wwwroot\activedirectory\logs\disabled_users_and_groups.csv" -Destination "C:\inetpub\wwwroot\activedirectory\logs\disabled_users_and_groups.$copyDate.csv"
$report | Format-Table -AutoSize



#--------------------------------------------------------------------
# GET MAC ADDRESS
#--------------------------------------------------------------------
Get-NetAdapter | Select-Object Name, MacAddress, Status



#--------------------------------------------------------------------
# GET MEMBERS OF AN M365 DISTRIBUTION LIST
#--------------------------------------------------------------------

# Requires Exchange Online Management Module
#Install-Module ExchangeOnlineManagement -Scope CurrentUser

# Connect to Exchange Online
Connect-ExchangeOnline

# Prompt for Distribution List
$DLName = Read-Host "Enter Distribution List Name, Alias, or Email Address"

# Verify the DL exists
$DL = Get-DistributionGroup -Identity $DLName -ErrorAction SilentlyContinue

if (-not $DL) {
    Write-Host "Distribution Group '$DLName' not found." -ForegroundColor Red
    return
}

Write-Host "`nMembers of $($DL.DisplayName):" -ForegroundColor Green

# Get members
$Members = Get-DistributionGroupMember -Identity $DL.Identity |
    Sort-Object PrimarySmtpAddress |
    Select-Object PrimarySmtpAddress, RecipientType

# Display results
$Members | Format-Table -AutoSize

# Export to CSV
$CsvPath = "C:\temp\$($DL.Alias)_Members.csv"
$Members | Export-Csv -Path $CsvPath -NoTypeInformation

Write-Host "`nExported to $CsvPath" -ForegroundColor Yellow

# Disconnect session
Disconnect-ExchangeOnline -Confirm:$false