$Events |
ForEach-Object {

    $Xml = [xml]$_.ToXml()

    $Fields = @{}
    foreach ($Data in $Xml.Event.EventData.Data) {
        $Fields[$Data.Name] = $Data.'#text'
    }

    # Determine username based on event type
    $UserName = $Fields['TargetUserName']

    # Exclude machine and system accounts
    if ($UserName -and
        $UserName -ne 'SYSTEM' -and
        $UserName -notmatch '\$$') {

        [PSCustomObject]@{
            TimeCreated = $_.TimeCreated

            Result = switch ($_.Id) {
                4624 { 'Success' }
                4625 { 'Failure' }
                4634 { 'Logoff' }
                4647 { 'User Logoff' }
                Default { 'Other' }
            }

            UserName = $UserName
        }
    }
} |
Sort-Object TimeCreated |
Format-Table -AutoSize