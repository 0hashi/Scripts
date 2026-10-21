Connect-ExchangeOnline
Get-TransportRule -Identity "Employee OutsideEmail whitelist" | Format-List *

Get-TransportRule -Identity "EXTERNAL Messages" | Format-List *

Get-TransportRule | Where-Object {
    $_.Description -match "bluexinbo.com"
} | Select-Object Name,State,Priority,Description