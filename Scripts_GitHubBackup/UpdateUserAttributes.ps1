# Import the Active Directory module (if not already loaded)
Import-Module ActiveDirectory

# Define user info (you can also pull this from a CSV for bulk updates)
$userSamAccountName = "lily.munster"  # Change to the target username

# Define the attributes to update
$attributes = @{
    Title        = "IT Minion"
    Department   = "IT"
    OfficePhone  = "555-123-4567"
    StreetAddress = "123 Main St"
    City         = "Durant"
    State        = "OK"
    PostalCode   = "74701"
    Company      = "Trans Cable Inc."
}

# Apply the updates
Set-ADUser -Identity $userSamAccountName @attributes

Write-Host "Updated attributes for user: $userSamAccountName"
