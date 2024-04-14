<#
.SYNOPSIS 
This script permit to delete following contacts in Exchange Online. After that importation of new contact can be done.

.DESCRIPTION 
On the first time, the connection to Exchange Online is performed. We can begin the deletion of contact already in Exchange Online. I use CSV file for delete only the desired contact/
The contact are imported in the powershell variable then we performed the deletion with the ForEach. The variable $Todelete contain contact that we want delete.
On the second part, importation has performed. We import a other csv in the powershell variable $Importcsvnew. The path of the csv is configured in line 33 (Variable $Pathcsvnew)
The ForEach permit to create new mail contact in the M365 tenant.

.LINK 
https://www.inyourcloud.fr
https://www.nibonnet.fr

#>

#Connect to Exchange OnLine
UserCredential = Get-Credential
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
Import-PSSession $Session -DisableNameChecking

#Delete contact on Office 365 if contact is present on CSV file
$Pathcsv = "C:\DeleteContact.CSV"
$Importcsv = Import-Csv $Pathcsv

ForEach ($item in $Importcsv)
{
	$Todelete = $item.ADRESSE
	Remove-MailContact -Identity $Todelete -Confirm:$false
	$Todelete | Write-Host
}

#Import contact to CSVFile
#Create CSV file with column (Display name and External mail) 
$Pathcsvnew = "C:\Newcontacts.CSV"
$Importcsvnew = Import-Csv $Pathcsvnew
ForEach ($itemnew in $Importcsvnew)
{
	$Name = $itemnew.Name
	$Address = $itemnew.Address
	$Name
	New-MailContact -Name $Name -DisplayName $Name -ExternalEmailAddress $Address
}