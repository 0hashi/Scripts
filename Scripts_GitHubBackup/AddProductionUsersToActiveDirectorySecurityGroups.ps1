# This scripts takes an array of AD Users and adds them to an array of 
# AD Security Groups. Cool Unicode emojis for PowerShell scripts can be
# found here: https://unicode.org/emoji/charts/full-emoji-list.html

# Paul Ohashi
# May '25
# Script: AddProductionUsersToActiveDirectorySecurityGroups.ps1

# Define the list of users (sAMAccountNames or DNs)
$users = @(
    "Paul.Gray",
    "Ratan.Shah",
    "Miichael.Hintergardt"
)

# Define the list of security groups
$groups = @(
    "Production",
    "SP_Production",
    "SP_TCI-All",
    "TCI Manufacturing",
    "TCI Safety",
    "Texas Users"
)

# Loop through each user and each group
foreach ($user in $users) {
    foreach ($group in $groups) {
        try {
            Add-ADGroupMember -Identity $group -Members $user -ErrorAction Stop
            Write-Host "✅ Added $user to $group" -ForegroundColor Green
            }
        catch {
            Write-Host "❌ Failed to add $user to $group. Error: $_" -ForegroundColor Red
        }
    }
}
