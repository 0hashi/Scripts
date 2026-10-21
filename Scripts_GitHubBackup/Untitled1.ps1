Get-WinEvent -FilterHashtable @{
    LogName = 'Security';
    ID = 4624;
    StartTime = (Get-Date).AddDays(-1)
} | ForEach-Object {
    $xml = [xml]$_.ToXml()
    [PSCustomObject]@{
        TimeCreated = $_.TimeCreated
        User = $xml.Event.EventData.Data[5].'#text'
        IPAddress = $xml.Event.EventData.Data[18].'#text'
        LogonType = $xml.Event.EventData.Data[8].'#text'
    }
}
