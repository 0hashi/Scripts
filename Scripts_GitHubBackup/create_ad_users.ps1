#Create a bunch of AD users
#
# create_ad_users.ps1 - A simple PowerShell script to create Active Directory users. Modify
# the following variables and run in PowerShell.
#   $domainController =
#   $ou =
#   $employeeIDOfUsernames
#
#
Import-Module ActiveDirectory

# Connect to Active Directory (you might need to modify this part based on your environment)
$domainController = "reddirt.lab"
$ou = "OU=Inactive Accounts,OU=NAM,OU=Enterprise,OU=www.reddirt.lab,OU=Active Roles,OU=Solutions,DC=reddirt,DC=lab"  # Modify this to the appropriate Organizational Unit (OU)

# Define the number of random usernames to generate
$employeeIDOfUsernames = 50

# Function to generate a random username
function GenerateRandomUsername {
    $firstNames = @("Alice", "Bob", "Charlie", "Don", "Edgar", "Frank", "George", "Henry", "Israel", "Johnny", "Kenton", "Larry", "Mike", "Nathan", "Oscar", "Peter", "Robert", "Sam", "Paula" +
    , "Thomas", "Victor", "Wayne", "Alan", "Beth", "Christie", "Donna", "Ellen", "Farah", "Gloria", "Helen", "Iris", "Kathleen", "Linda", "Monica", "Nanci", "Olivia", "Pamela", "Randy", "Pauline" +
    , "Sara", "Tammy", "Victoria", "Wendy", "John", "Jane", "Michael", "Emily", "David", "Sarah", "Christopher", "Jessica", "Daniel", "Matthew", "Ava", "Andrew", "Emma", "William", "Sophia" +
    , "James", "Isabella", "Joseph", "Mia", "Jake", "Jim", "Jimmy", "Al", "Alan", "Ashley", "Amber", "Barbie", "Brent", "Carol", "Caroline", "Diane", "Diana", "Deena", "Darla", "Daniel" +
    , "Dave", "Paul", "Dan", "Stacey", "Edwardo", "Eli", "Francis", "Fred", "Fredo", "Gene", "Jennie", "Jenny", "Joey", "Todd", "Lonnie", "Ray", "Raymond", "Tom", "Sammy", "Kayia", "Kimmie" +
    , "Jameson", "Jeff", "Christopher", "Tiffany", "Carl", "Eric", "Arik", "Emmet", "Karl", "Tony", "Anthony", "Penny", "Amy", "Hank", "Josh", "Dave", "Eddie", "Arlene", "Tammy", "Pete", "Nick" +
   , "Bobby", "Barney", "Moe", "Ruth", "Miranda", "Martina", "Luigi", "Stewart", "Jon", "Mabel", "Mickey", "George", "Terri", "Emmerson", "Brinley", "Rich", "Maverick", "Tamara")

$lastNames = @("Jones", "Jefferson", "Berg", "Manson", "Bonham", "Upchurch", "Michales", "Lake", "Gaines", "May", "Beaver", "Sloth", "Rice", "Rock", "Johnson", "Smith", "Harley", "Mitchell" +
, "Watson", "Humphries", "Peterson", "Sanchez", "Wong", "Burns", "Huynh", "Wooster", "Royale", "Samuel", "Wilkins", "Walker", "Riley", "Daly", "Simpson", "Garcia", "Lang", "McGee", "Skinner" +
, "Thompson", "Patel", "Johnson", "Williams", "Jones", "Brown", "Davis", "Miller", "Wilson", "Moore", "Taylor", "Thomas", "Jackson", "White", "Harris", "Young", "Hernandez", "King", "Wright" +
, "Lopez", "Mendoza", "Chapman", "Conrad", "Laughney", "Daily", "Cage", "Toulouse", "Lakeman", "Frampton", "Koothrappali", "Cooper", "Woo", "Wang", "Wonder", "Copenhagen", "Miller", "Carter" +
, "Wilson", "Anderson", "Lee", "Bailey", "Quinn", "Lewis", "Lopez", "Taylor", "Swift", "Tyler", "Hansley", "Thatcher", "Bardot", "Brown", "Perez", "Harris", "White", "Clark", "Torres", "Wright" +
, "King", "Young", "Robinson", "Ramirez", "Hill", "Green", "Adams", "Nelson", "Flores", "Phillips", "Evans", "Turner", "Diaz", "Parker", "Cruz", "Reyes", "Morris", "Morales", "Murphy", "Cook" +
, "Ortiz", "Morgan", "Reed", "Howard", "Cox", "Wood", "Bennett", "Gray", "Ruiz", "Hughes", "Price", "Alvarez", "Castillo", "Sanders", "Patel", "Ross", "Foster", "Powell", "Jenkins", "Perry" +
, "Sullivan", "Coleman", "Butler", "Fisher", "Simmons", "Romero", "Patterson", "Hamilton", "Griffin", "Wallace", "Moreno", "West", "Hayes", "Bryant", "Herrera", "Gibson", "Ellis", "Tran", "Medina" +
, "Moreau", "Beaumont", "Francois", "Durand", "Gauthier", "Lambert", "Dubois", "Fournier", "Dumont", "Blanc", "Chevalier", "LaCroix", "Dumas", "De La Fontaine", "Aubert" +
, "Dufour", "Roche", "Blanchet", "Guillaume", "Archambault", "Tremblay", "Lefevre", "Cloutier", "Sauveterre", "Monet", "Garnier", "Moulin", "Toussaint", "Laurent", "Dupont", "Martin" +
, "Boucher", "Allard", "Chevrolet", "Moreau", "Corbin", "Leroy", "Cartier", "Duplantier", "Fournier", "Beaufort", "Bonnet", "Rousseau", "Lyon", "Granger", "Fontaine", "Chastain", "Dufort" +
, "LaRue", "Renaud", "Vernier", "Allemand", "Couture", "Abadie", "Bassett", "Adrien", "Aries", "Abreo", "Alarie", "Barbier")


    $firstName = Get-Random -InputObject $firstNames
    $lastName = Get-Random -InputObject $lastNames

    return "$firstName.$lastName"
}

# Generate and create random usernames
for ($i = 1; $i -le $employeeIDOfUsernames; $i++) {
    $username = GenerateRandomUsername
    $password = ConvertTo-SecureString -AsPlainText "1q2w3e4r5T10-" -Force
    $name = "$($username.ToLower())"
    $fname = $username -replace '(.*)\.(.*)', '$1'
    $lname = $username -replace '(.*)\.(.*)', '$2'
    $employeeID = Get-Random -Minimum 1000 -Maximum 9999

    New-ADUser -Name "$fname $lname" -SamAccountName $name -UserPrincipalName "$name@reddirt.lab" -Path $ou -AccountPassword $password -GivenName $fname -Surname $lname -EmailAddress "$name@oneidentity.aws" -OfficePhone "1-800-306-9329" -EmployeeID $employeeID -Enabled $true

    Write-Host "Created user: username: $username - fname: $fname - lname: $lname - employeeID: $employeeID - "
}

# Disconnect from Active Directory
Disconnect-ADServiceAccount
