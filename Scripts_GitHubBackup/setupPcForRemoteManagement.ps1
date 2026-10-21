#PO - Check current network profile of the system to be managed remotely
Get-NetConnectionProfile
#-----------------
#PO - Change network profile on the system to be managed remotely
#Set-NetConnectionProfile -NetworkCategory [Private|Public|DomainAuthenticated]
Set-NetConnectionProfile -NetworkCategory Private

#PO - Test WinRM
Test-WSMan -ComputerName e6
Invoke-Command -ComputerName E6 -ScriptBlock { whoami }

#PO - If WinRM is not set up to allow remote access, execute these two commands:
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 1 -PropertyType DWord -Force
Restart-Service WinRM

#PO - Ensure the firewall is enabled for remote management
Get-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)"

#PO - If the output shows "Enabled: False", enable it
Enable-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)"

#PO - Configure system for remote PowerShell management
netsh advfirewall firewall set rule group="Remote Event Log Management" new enable=yes
Enable-PSRemoting -Force
winrm quickconfig
New-NetFirewallRule -DisplayName "Allow WMI" -Direction Inbound -Protocol TCP -LocalPort 135 -Action Allow  
New-NetFirewallRule -DisplayName "Allow RPC Dynamic Ports" -Direction Inbound -Protocol TCP -LocalPort 49152-65535 -Action Allow
New-NetFirewallRule -DisplayName "Allow SMB" -Direction Inbound -Protocol TCP -LocalPort 445 -Action Allow  
