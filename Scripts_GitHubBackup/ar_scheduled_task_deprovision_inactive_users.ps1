# Active Roles Scheduled Task to deprovision inactive user accounts

$lastLogonThreshold = (Get-Date).AddDays(-30)
$domain = "reddirt"
$ouDN = "OU=Users,OU=NAM,OU=Enterprise,OU=www.reddirt.lab,OU=Active Roles,OU=Solutions,DC=reddirt,DC=lab"
$users = Get-ADUser -Filter * -Properties lastLogon -SearchBase $ouDN
$infoNotes = "Last logged on more than 30 days ago "
$attributeName = 'info'

# $limit is the max number of accounts that will be deprovisioned on each run. Remove $counter, $limit
# and the first if block in the foreach loop to deprovision all inactive user accounts in the defined
# OU ($ouDN).
$counter = 0
$limit = 10

foreach ($user in $users) {

    # Delete if block to deprovision all inactive user accounts in the defined OU ($ouDN)
    $counter++
    if ($counter -ge $limit) {
        break
    }

    $lastLogonValue = [System.DateTime]::FromFileTime($user.lastLogon)

    if ($lastLogonValue -lt $lastLogonThreshold) {

        Set-ADUser -Identity $user -Replace @{$attributeName = "$infoNotes $lastLogonValue"}

        $strUserPath = "EDMS://" + $user
        $ss = ""
        #Bind to the user object
        $User = [ADSI]$strUserPath
        #Deprovision the user account
        $User.Put("edsvaDeprovisionType", 1)
        $User.SetInfo()

    } else {
        Set-ADUser -Identity $user -Replace @{$attributeName = "Last logon: $lastLogonValue"}
    }
}
