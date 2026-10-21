# Install Graph module if not already installed
# Install-Module Microsoft.Graph -Scope CurrentUser

CLS

# Connect to Microsoft Graph with proper permissions
Connect-MgGraph -Scopes "User.Read.All","Organization.Read.All"

# Ask user whether to search all users or filter by UPN domain
Write-Host "Do you want to search the entire directory or filter by a specific UPN domain?" -ForegroundColor Cyan
$choice = Read-Host "Type 'All' for entire directory or 'Domain' for a specific UPN domain"

# Ask user if they want consolidated output
Write-Host ""
Write-Host "Would you like to consolidate all licenses into one row per user?" -ForegroundColor Cyan
$consolidateChoice = Read-Host "Type '[Y|y]' to consolidate or 'No' for one row per license"

# Initialize user list
$licensedUsers = @()

if ($choice -eq 'All') {
    Write-Host "Searching all licensed users in the entire directory..." -ForegroundColor Green

    $licensedUsers = Get-MgUser -All -Property "DisplayName,UserPrincipalName,JobTitle,Department,AssignedLicenses" |
        Where-Object { $_.AssignedLicenses.Count -gt 0 }

} elseif ($choice -eq 'Domain') {
    # Prompt for UPN domain
    $upnDomain = Read-Host "Enter the UPN domain to search for (e.g., domain1.com or @domain1.com)"

    # Normalize domain input
    $upnDomain = $upnDomain.TrimStart('@')

    Write-Host "Searching licensed users with UPNs ending in @$upnDomain ..." -ForegroundColor Green

    $licensedUsers = Get-MgUser -All -Property "DisplayName,UserPrincipalName,JobTitle,Department,AssignedLicenses" |
        Where-Object {
            $_.AssignedLicenses.Count -gt 0 -and
            $_.UserPrincipalName -like "*@$upnDomain"
        }

} else {
    Write-Host "Invalid selection. Please run the script again and choose 'All' or 'Domain'." -ForegroundColor Red
    exit
}

# Get license SKUs available in the tenant
$skus = Get-MgSubscribedSku | Select-Object SkuId, SkuPartNumber, ConsumedUnits

# Build results list
$results = @()

if ($consolidateChoice -match '[Yy]$') {
    # One row per user with all licenses combined
    $results = foreach ($user in $licensedUsers) {
        $licenseNames = foreach ($license in $user.AssignedLicenses) {
            ($skus | Where-Object { $_.SkuId -eq $license.SkuId }).SkuPartNumber
        }

        [PSCustomObject]@{
            LineNumber        = 0
            DisplayName       = $user.DisplayName
            UsernameUPN       = $user.UserPrincipalName
            Title             = $user.JobTitle
            Department        = $user.Department
            Licenses          = ($licenseNames -join ", ")
        }
    }

} else {
    # One row per license
    $results = foreach ($user in $licensedUsers) {
        foreach ($license in $user.AssignedLicenses) {
            $sku = $skus | Where-Object { $_.SkuId -eq $license.SkuId }

            [PSCustomObject]@{
                LineNumber        = 0
                DisplayName       = $user.DisplayName
                UserPrincipalName = $user.UserPrincipalName
                LicenseName       = $sku.SkuPartNumber
            }
        }
    }
}

if ($results.Count -eq 0) {
    Write-Host "No licensed users found for the specified search criteria." -ForegroundColor Yellow
    exit
}

#PO: Sort choice
# Prompt user for sort column
Write-Host ""
Write-Host "Choose the column to sort by:" -ForegroundColor Cyan
Write-Host "  1 = Display Name"
Write-Host "  2 = Username (UPN)"
Write-Host "  3 = Title"
Write-Host "  4 = Department"

if ($consolidateChoice -match '^[Yy]$') {
    Write-Host "  5 = Licenses"
} else {
    Write-Host "  5 = License Name"
}

$sortChoice = Read-Host "Enter the number of the column to sort by"

# Map number to property name
$sortProperty = switch ($sortChoice) {
    '1' { 'DisplayName' }
    '2' { 'UsernameUPN' }
    '3' { 'Title' }
    '4' { 'Department' }
    '5' {
        if ($consolidateChoice -match '^[Yy]$') {
            'Licenses'
        }
        else {
            'LicenseName'
        }
    }
    default {
        Write-Host "Invalid selection. Defaulting to Display Name." -ForegroundColor Yellow
        'DisplayName'
    }
}

# Sort results based on user selection
$sortedResults = $results | Sort-Object $sortProperty

# Renumber after sorting
$counter = 1
$sortedResults = $sortedResults | ForEach-Object {
    $_.LineNumber = $counter
    $counter++
    $_
}


$sortedResults = $results |
    Sort-Object `
        @{Expression={($_.UsernameUPN -split '@')[-1].ToLower()}},
        DisplayName



# Display final output
$sortedResults | Format-Table -AutoSize

#PO: Optional: Export to CSV
#PO: Ask whether to export results
Write-Host ""
$exportChoice = Read-Host "Would you like to export the results to a CSV file? (Y/N)"

if ($exportChoice -match '^[Yy]$') {

    # Default file name
    if ($consolidateChoice -match '^[Yy]$') {
        $defaultFile = "C:\temp\M365_AssignedLicenses_Consolidated.csv"
    }
    else {
        $defaultFile = "C:\temp\M365_AssignedLicenses.csv"
    }

    #PO $fileName = Read-Host "Enter a file name or press Enter to use '$defaultFile'"
    $fileName = "$defaultFile"

    $exportPath = "$fileName"

    $sortedResults | Export-Csv $exportPath -NoTypeInformation

    Write-Host ""
    Write-Host "Results exported successfully:" -ForegroundColor Green
    Write-Host $exportPath -ForegroundColor Yellow
}
else {
    Write-Host "Export skipped." -ForegroundColor Yellow
}