# Define API endpoint and credentials
$atlasIP = "10.100.105.80"  # Change to your Atlas IP
$apiUrl = "https://$atlasIP/api/events"

# Optional: if authentication is needed (Basic Auth example)
$username = "admin"
$password = "+c!@dMin17"
#$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$username:$password"))
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${username}:${password}"))

# Trust all certificates temporarily for this session, ignore the signed certificate.
Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy



# Send GET request
$response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{
    Authorization = "Basic $base64AuthInfo"
}

# Filter events for Access Granted and Access Denied
$filteredEvents = $response.events | Where-Object {
    $_.eventType -match "Access Granted|Access Denied"
}

# Display filtered events
$filteredEvents | Format-Table timestamp, userName, eventType, doorName -AutoSize
