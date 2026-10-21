$Today = (Get-Date).ToString("MM/dd/yyyy")

Search-Mailbox -Identity "elizabetha@transcableusa.com" `
  -SearchQuery "Received:$Today" `
  -TargetMailbox "elizabeth@domain.com" `
  -TargetFolder "Recovered-Deleted-Email" `
  -LogLevel Full



  Install-Module -Name ExchangeOnlineManagement -Force

  Connect-ExchangeOnline -UserPrincipalName pohashi@transcableusa.com -UseEmbeddedWebView
  Restore-RecoverableItems -Identity elizabetha@transcableusa.com
