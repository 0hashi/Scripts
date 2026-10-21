#PO - Search event logs for logon information.

# Type	Meaning
# 2     Interactive (local keyboard)
# 3     Network (access to shared folder)
# 4	    Batch (e.g., scheduled tasks)
# 5     Service logon (local, system, network)
# 10    RemoteInteractive (RDP)
#
# List of target systems
$computers = @("E6", "ENGProcessTechOld")

# Get current date/time for filename
$timestamp = Get-Date -Format "MM-dd-yyyy_HH-mm-ss"

# Output CSV path
$outputPath = "C:\Users\paulo\Desktop\ActiveDirectory\WindowsLogonEvents\RemoteUserLogons_$timestamp.csv"

# Ensure log file exists with headers
if (-not (Test-Path $outputPath)) {
    "Computer,TimeCreated,User,IPAddress,LogonType" | Out-File -FilePath $outputPath
}

foreach ($computer in $computers) {
    try {
        Write-Host "Querying $computer..." -ForegroundColor Cyan

        Invoke-Command -ComputerName $computer -ScriptBlock {
            $events = Get-WinEvent -FilterHashtable @{
                LogName = 'Security';
                ID = 4624;
                StartTime = (Get-Date).AddDays(-1)
            }

            $events | ForEach-Object {
                $xml = [xml]$_.ToXml()
                [PSCustomObject]@{
                    TimeCreated = $_.TimeCreated
                    User        = $xml.Event.EventData.Data[5].'#text'
                    IPAddress   = $xml.Event.EventData.Data[18].'#text'
                    LogonType   = $xml.Event.EventData.Data[8].'#text'
                }
            }
        } | ForEach-Object {
            "$computer,$($_.TimeCreated),$($_.User),$($_.IPAddress),$($_.LogonType)" | Out-File -FilePath $outputPath -Append
        }

    } catch {
        Write-Warning "Failed to query $computer $_"
    }
}
