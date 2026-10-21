Get-ADObject -Filter 'IsDeleted -eq $true' -IncludeDeletedObjects 

Get-ADObject -Filter 'ObjectCategory -eq "person" -and IsDeleted -eq $true' -IncludeDeletedObjects

Get-ADOptionalFeature -Filter {Name -eq "Recycle Bin Feature"}


Import-Module AzureAD
Connect-MgGraph -Scopes "User.Read.All"
Get-MgUser -All -ConsistencyLevel eventual -Filter "endsWith(UserPrincipalName, '@example.com')" -CountVariable Count | 
Select-Object UserPrincipalName

