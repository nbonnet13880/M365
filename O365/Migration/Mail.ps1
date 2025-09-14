#Connection to Exchange Online
$UserCredential = Get-Credential
Connect-ExchangeOnline -Credential $UserCredential

#Load CSV file
git 