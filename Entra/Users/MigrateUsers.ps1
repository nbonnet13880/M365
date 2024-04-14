<#
.SYNOPSIS
    Migrate users from Sync users to cloud users
.DESCRIPTION
    The script begin by an inventory of sync users must be migrated. The users who the validity date is expired are listed on the variable and the CSV file is created.
    He contain the attributes of this accounts. If the Extended Attributes 5 contain DIRSYNC, the value of the attributes is deleted and the username listed in the log file.
    After that the synchronization between AD and AAD is performed to delete the users in Entra ID.
    The Entra ID Users is restored and a licence is affected.
.EXAMPLE
    Before to run the script, the variable must be configured.
.NOTES
    Script created by Nicolas BONNET 21-02-2024.
#>

####################################################################################################################################
#   Variable used by the script                                                                                                    #
####################################################################################################################################
$i=0
$ResultsSelectUsers= @()
$ResultsDeleteAttributes= @()
$ResultsMigration= @()
$LogFile = get-date -Format "ddMMyyyy-HHMM"
$Log="C:\Scripts\Log-Export-$LogFile.csv"
$Log2="C:\Scripts\Log-Suppression-$LogFile.csv"
$Log3="C:\Scripts\Log-Migration-$LogFile.csv"
$DirSyncServer = "FQDN Server Entra ID Connect"
$DirPath = "C:\Scripts\"
$LicenceO365Source = "Ecole:M365EDU_A3_STUUSEBNFT" # Found the name of the licence with powershell
$LicenceO365SourceA1 = "Ecole:STANDARDWOFFPACK_STUDENT" # Found the name of the licence with powershell
$GroupLicenceO365E3 = "ID of the Entra group"
$TargetOU ="OU=Diplomes,DC=student,DC=Ecole,DC=lan" # Target OU where the users is moved after the migration 
$ValeurSynchro="DIRSYNC"  
$LDAPAttributes = "extensionAttribute5"


$htmlfile = $Log,$Log2,$Log3
$SMTPServer = "10.1.150.17"
$SMTPPort = "25"
$Username = "noreply@InYourCloud.fr"
$encodingMail = [System.Text.Encoding]::UTF8
$Subject = "Migration Users"
$Body = "Migration users AD"
$Destinataires = 'destinataire1@inyourcloud.Fr,destinataire2@inyourcloud.fr','destinataire3@inyourcloud.fr'
$To = $Destinataires.Split(',')
$emailattachment = $htmlfile
$MailAttach = $emailattachment.Split(',')

####################################################################################################################################
#   Create the list of the users must be migrated                                                                                  #
#   For each users, the value of some attributes are exported on the CSV file                                                      #
####################################################################################################################################


$AncienEleves=Search-ADAccount  -AccountExpired -Server Srv-AD.ecole.lan -SearchBase "OU=Eleve,OU=Marseille,DC=Ecole,DC=lan" -UsersOnly -ResultPageSize 15 -resultSetSize $null | Select-Object Name, userPrincipalName,SamAccountName, DistinguishedName, AccountExpirationDate,extensionAttribute5

While ($i -le "1")  
{  
    $AncienEleve=Get-ADUser -Server Srv-AD.ecole.lan -Identity $AncienEleves[$i].SamAccountName -Properties $LDAPAttributes | Select-Object Name, userPrincipalName,SamAccountName, DistinguishedName, AccountExpirationDate,extensionAttribute5
    
    $ResultsSelectUsers += [pscustomobject] @{
        'Name' = $AncienEleve[$i].Name
        'userPrincipalName' = $AncienEleve.userPrincipalName
        'SamAccountName' = $AncienEleve.SamAccountName
        'DistinguishedName' = $AncienEleve.DistinguishedName
        'AccountExpirationDate' = $AncienEleve.AccountExpirationDate
        'extensionAttribute5' = $AncienEleve.extensionAttribute5
        
        }
     $ResultsSelectUsers | Export-Csv -Path $Log -Delimiter "," -NoTypeInformation
   $i++
}

$Users = Import-Csv $Log -Delimiter ","

####################################################################################################################################
#   For each users who the extensionAttribute 5 is equal to $ValeurSynchro, the value of attrinutes is deleted                     #
#   The result is imported on the CSV file                                                                                         #
####################################################################################################################################


ForEach ($User in $Users)
{
     
    If ($User.extensionAttribute5 -eq $ValeurSynchro)
    {
        Get-ADUser -Server Srv-AD.ecole.lan -Identity $User.SamAccountName | Set-ADUser -clear $LDAPAttributes
       
        $ResultsDeleteAttributes += [pscustomobject] @{
        'Username' = $User.SamAccountName
        'Résultat' = "Value is been deleted"}
       
    }
    Else
    {
        $ResultsDeleteAttributes += [pscustomobject] @{
        'Username' = $User.SamAccountName
        'Résultat' = "Value is not deleted"}
        
    }
}

$ResultsDeleteAttributes | Export-Csv -Path $Log2 -Delimiter "," -NoTypeInformation

#######################################################################################################################################################################
# Synchronisation AD with Entra ID                                                                                                                                    #
# - Delete the log                                                                                                                                                    #
# - Create CSV file with (UPN, SamAccountName, GivenName et Name)                                                                                                     #
# - Wait 120 sec for the Active Directory replication                                                                                                                 #
# - Synchronisation is performed (if the synchronization is in progress : wait, if not run the synchronization and wait 300 secondes                                  #                                                                                                                                                      
#######################################################################################################################################################################

#If (Test-Path $PathCsv)
#{
#    Remove-Item $PathCsv -Force
#}

#$Users | select userPrincipalName,sAMAccountName,givenname,name | export-csv -Force -Path $PathCsv  -Delimiter "," -NoTypeInformation -Encoding UTF8

    
    write-host "Wait 120 seconds"
    Start-Sleep -s 120

    Invoke-Command -ComputerName $DirSyncServer -ScriptBlock {
    Import-Module adsync
    $Debut = get-date
    $SynchroEnabled=Get-ADSyncConnectorRunStatus
    If ($SynchroEnabled.RunState -eq $empty)
    {        
        write-host "Start the synchronization, $Debut"
        Start-ADSyncSyncCycle -PolicyType Delta
        Start-Sleep -s 600
    }
    else
      {
        write-host "Sync in progress, we wait. $Debut"
        Start-Sleep -s 900
        Start-ADSyncSyncCycle -PolicyType Delta
        Start-Sleep -s 600
    }
  
    }



#######################################################################################################################################################################
# Connect to Microsoft 365                                                                                                                                            #
# - If the file AzureAD.Cred is not present, the M365 username and password is asked                                                                                  #
# - Import MSOnine module                                                                                                                                         #
# - Connect to Entra ID                                                                                                                                        #
#######################################################################################################################################################################
 
$CredObj = ($DirPath + "\" + "AzureAD.cred")
 
$CredObjCheck = Test-Path -Path $CredObj
If (!($CredObjCheck))
{
    "$Date - INFO: creating cred object" | Out-File ($DirPath + "\" + "Log.txt") -Append
     
    $Credential = Get-Credential -Message "Please enter your Administrator Entra ID credential that you will use to connect."    
    
    $Credential | Export-CliXml -Path $CredObj
}
 
Write-Host "Importing Cred object..." -ForegroundColor Yellow
$Cred = (Import-CliXml -Path $CredObj)
 
 
Import-Module MSOnline
 
connect-msolservice -credential $Cred

#######################################################################################################################################################################
# Restore user and assign licence                                                                                                                                     #
# - Import CSV file                                                                                                                                                   #
# - Restore user                                                                                                                                                      #
# - If the licence is assigned, the licence is deleted and user is added on the group. If not user is added on the group                                              #
#######################################################################################################################################################################
 
#$ImportCsv = Import-Csv $PathCsv -Delimiter ","
 
 
ForEach ($item in $Users)
{
    Restore-MsolUser -UserPrincipalName $item.userPrincipalName
    Write-Host "Restore in progress" -ForegroundColor Yellow
    Start-Sleep -s 60
   
    Set-MsolUser -UserPrincipalName $item.userPrincipalName -ImmutableId "$null"
    


    $Licenceconfigured = Get-MsolUser -UserPrincipalName $item.userPrincipalName
    $UPN = $item.userPrincipalName
 
    If ($Licenceconfigured.isLicensed -eq $true)
    {
        Set-MsolUserLicense -UserPrincipalName $item.userPrincipalName -RemoveLicenses $LicenceO365Source
        Set-MsolUserLicense -UserPrincipalName $item.userPrincipalName -RemoveLicenses $LicenceO365SourceA1
        $guid = get-msoluser -userprincipalname $UPN | select -expandproperty objectid
        $guid = $guid.guid
        Add-MsolGroupMember -GroupObjectId $GroupLicenceO365E3 -GroupMemberType User -GroupMemberObjectId $guid
    }
    Else
    {
        $guid = get-msoluser -userprincipalname $UPN | select -expandproperty objectid
        $guid = $guid.guid
        Add-MsolGroupMember -GroupObjectId $GroupLicenceO365E3 -GroupMemberType User -GroupMemberObjectId $guid        
        
    }
  
    $utilMigres=Get-MsolUser -UserPrincipalName $upn

     If ($utilMigres -ne $null)
    {
         $ResultsMigration += [pscustomobject] @{
        'Username' = $item.userPrincipalName
        'Résultat' = "Migration OK"}
    }
    Else
    {

         $ResultsMigration += [pscustomobject] @{
        'Username' = $item.userPrincipalName
        'Résultat' = "Migration not OK"}
        
    }
   
   $ResultsMigration | Export-Csv -Path $Log3 -Delimiter "," -NoTypeInformation
}


#######################################################################################################################################################################
# Move migrated users in the target OU                                                                                                                                #
# - For each user in the $Users variable, the user is migrated in the Target OU                                                                                       #
# - Email is sent. Migration is done                                                                                                                                  #
#######################################################################################################################################################################


ForEach ($User1 in $Users)
{
        Move-ADObject -Server Srv-AD.ecole.lan -Identity  $User1.DistinguishedName   -TargetPath $TargetOU 
}

send-MailMessage -SmtpServer $SMTPServer -To $To -From "noreply@InYourCloud.Fr" -Subject $Subject -Body $Body -BodyAsHtml -Attachments $MailAttach -Priority high
 
