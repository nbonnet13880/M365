<#
.SYNOPSIS
    Select M365 users with txt file, create backup job and add the users.
.DESCRIPTION
    The first command permit to keep information about the VBO Organization. The variable $Usernames read the txt file and store 
    the username in the variable ($Usernames). The variable $ListUsers permit to store the attributes of the users.
    THe item that you want backup (mailbox, archive mail, Onedrive et Personal Sharepoint) must be configured. If the calue configured
    is $True, the item is backup ed. The last line of the script permit to create the backup jon on Veeam. The TXT file contain username of the users.
.EXAMPLE
    Before to run the script, the CmdLets for Veeam for M365 must be installed. Add username of the users that you want backup.
.NOTES
    Script created by Nicolas BONNET 06-05-2024.
#>

$M365Org=Get-VBOOrganization 
$Usernames=Get-Content -Path C:\Temp\Users.txt
$ListUsers=Get-VBOOrganizationUser -Organization $org | ?{$usernames.Contains($_.UserName)}
$BackupJob=New-VBOBackupItem -User $ListUsers -Mailbox:$True -ArchiveMailbox:$true -OneDrive:$True -Sites:$True
Add-VBOJob -Organization $M365Org -Name "[Daily] - Backup users" -Repository (Get-VBORepository) -SelectedItems $BackupJob