# ============================================================
# Windows Interactive Logon Report
#
# Event ID: 4624 - An account was successfully logged on
#
# Logon Types included:
#   2  = Interactive
#   7  = Unlock
#   10 = RemoteInteractive (RDP)
#   11 = CachedInteractive
# ============================================================

# Prompt for date or date range
$DateInput = Read-Host "Enter a date (MM/DD/YYYY) or date range (MM/DD/YYYY - MM/DD/YYYY)"

# Parse single date
if ($DateInput -match '^\s*(\d{1,2}/\d{1,2}/\d{4})\s*$') {

    try {
        $StartDate = [datetime]::ParseExact(
            $Matches[1],
            'M/d/yyyy',
            [Globalization.CultureInfo]::InvariantCulture
        ).Date

        $EndDate = $StartDate.AddDays(1)
    }
    catch {
        Write-Host "Invalid date." -ForegroundColor Red
        exit
    }
}

# Parse date range
elseif ($DateInput -match '^\s*(\d{1,2}/\d{1,2}/\d{4})\s*-\s*(\d{1,2}/\d{1,2}/\d{4})\s*$') {

    try {
        $StartDate = [datetime]::ParseExact(
            $Matches[1],
            'M/d/yyyy',
            [Globalization.CultureInfo]::InvariantCulture
        ).Date

        $EndDate = [datetime]::ParseExact(
            $Matches[2],
            'M/d/yyyy',
            [Globalization.CultureInfo]::InvariantCulture
        ).Date.AddDays(1)
    }
    catch {
        Write-Host "Invalid date range." -ForegroundColor Red
        exit
    }
}

else {
    Write-Host ""
    Write-Host "Invalid date format." -ForegroundColor Red
    Write-Host "Use one of the following formats:"
    Write-Host "  10/01/2026"
    Write-Host "  09/28/2026 - 10/01/2026"
    exit
}

# Validate date range
if ($EndDate -le $StartDate) {
    Write-Host ""
    Write-Host "End date must be on or after the start date." -ForegroundColor Red
    exit
}

# Display search range
$DisplayEndDate = $EndDate.AddSeconds(-1)

Write-Host ""
Write-Host "Searching Security log..." -ForegroundColor Cyan
Write-Host "Start: $StartDate"
Write-Host "End:   $DisplayEndDate"
Write-Host ""

# Retrieve successful logon events
$Results = Get-WinEvent -FilterHashtable @{
    LogName   = 'Security'
    Id        = 4624
    StartTime = $StartDate
    EndTime   = $EndDate
} -ErrorAction SilentlyContinue |
ForEach-Object {

    $Xml = [xml]$_.ToXml()

    $Fields = @{}

    foreach ($Data in $Xml.Event.EventData.Data) {
        $Fields[$Data.Name] = $Data.'#text'
    }

    # Only include human-oriented logon types
    if ($Fields['LogonType'] -in @('2','7','10','11') -and
        $Fields['TargetUserName'] -and
        $Fields['TargetUserName'] -ne 'SYSTEM' -and
        $Fields['TargetUserName'] -notmatch '\$$') {

        # Translate LogonType
        $LogonTypeDescription = switch ($Fields['LogonType']) {
            '2'  { 'Interactive (2)' }
            '7'  { 'Unlock (7)' }
            '10' { 'RemoteInteractive / RDP (10)' }
            '11' { 'CachedInteractive (11)' }
            default { "Unknown ($($Fields['LogonType']))" }
        }

        [PSCustomObject]@{
            TimeCreated          = $_.TimeCreated
            UserName             = $Fields['TargetUserName']
            Domain               = $Fields['TargetDomainName']
            LogonType            = $LogonTypeDescription
            Workstation          = $Fields['WorkstationName']
            IPAddress            = $Fields['IpAddress']
        }
    }
}

# Sort results newest first
$Results = $Results | Sort-Object TimeCreated -Descending

# Display results
if ($Results) {

    $Results | Format-Table -AutoSize

    Write-Host ""
    Write-Host "Total interactive logon events: $($Results.Count)" -ForegroundColor Green

    # Ask about CSV export
    $Export = Read-Host "Export results to CSV? (Y/N)"

    if ($Export -match '^[Yy]$') {

        $DefaultFileName = "InteractiveLogons_$($StartDate.ToString('yyyyMMdd'))"

        if ($EndDate.Date -gt $StartDate.Date) {
            $DefaultFileName += "_to_$($EndDate.AddDays(-1).ToString('yyyyMMdd'))"
        }

        $DefaultFileName += ".csv"

        $FileName = Read-Host "Enter CSV filename [$DefaultFileName]"

        if ([string]::IsNullOrWhiteSpace($FileName)) {
            $FileName = $DefaultFileName
        }

        # If the user doesn't provide .csv, add it
        if ($FileName -notmatch '\.csv$') {
            $FileName += ".csv"
        }

        $Results | Export-Csv -Path $FileName -NoTypeInformation -Encoding UTF8

        Write-Host ""
        Write-Host "CSV exported to:" -ForegroundColor Green
        Write-Host (Resolve-Path $FileName)
    }
}
else {

    Write-Host "No interactive logon events were found for the specified period." -ForegroundColor Yellow
}