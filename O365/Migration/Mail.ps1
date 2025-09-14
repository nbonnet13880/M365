#Intall required module if not already installed
If (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Install-Module -Name ExchangeOnlineManagement -Force
}   
#Connection to Exchange Online
$UserCredential = Get-Credential
Connect-ExchangeOnline -Credential $UserCredential

#Load CSV file
$csvPath = "Mail.csv"

$Users= Get-Content -Path $csvPath

Foreach ($User in $Users) {
    $UserDetails = $User -split ","
    $SourceUPN = $UserDetails[0]
    $TargetUPN = $UserDetails[1]

    #Check if source mailbox exists
    $SourceMailbox = Get-Mailbox -Identity $SourceUPN -ErrorAction SilentlyContinue
    If ($null -eq $SourceMailbox) {
        Write-Host "Source mailbox for $SourceUPN does not exist. Skipping to next user." -ForegroundColor Yellow
        Continue
    }

    #Perform mailbox Configuration
   Set-Mailbox -Identity $SourceUPN -WindowsEmailAddress $TargetUPN

    #Output success message
    Write-Host "Mailbox for $SourceUPN has been successfully updated to $TargetUPN" -ForegroundColor Green
}