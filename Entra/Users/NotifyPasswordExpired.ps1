<#
.SYNOPSIS
    Send email if password will expire
.DESCRIPTION
    The script begin by an inventory of sync users must be migrated. The users who the validity date is expired are listed on the variable and the CSV file is created.
    He contain the attributes of this accounts. If the Extended Attributes 5 contain DIRSYNC, the value of the attributes is deleted and the username listed in the log file.
    After that the synchronization between AD and AAD is performed to delete the users in Entra ID.
    The Entra ID Users is restored and a licence is affected.
.EXAMPLE
    Before to run the script, the variable must be configured.
.NOTES
    Script created by Nicolas BONNET 21-03-2024.
#>


#######################################################################################################################################################################
# Variable used on the script                                                                                                                                         #                                                                                                                                                      
#######################################################################################################################################################################

$SMTPHost = "10.13.123.17"
$FromEmail = "noreply@inyourcloud.Fr"
$expireindays = 200
$DirPath = "C:\Scripts\"

#######################################################################################################################################################################
# Today date retrieval ant test if directory exist                                                                                                                    #
# - If not exist, the repository is created                                                                                                                           #                                                                                                                                                    
#######################################################################################################################################################################

$Date = Get-Date
$DirPathCheck = Test-Path -Path $DirPath
If (!($DirPathCheck))
{
	Try
	{
		new-Item -ItemType Directory $DirPath -Force
	}
	Catch
	{
		$_ | Out-File ($DirPath + "\" + "Log.txt") -Append
	}
}

#######################################################################################################################################################################
# Connexion to Entra ID                                                                                                                                               #
# - If the file EmailExpiry.cred exist => Connexion at Entra ID, if not username and password must be enter                                                           #                                                                                                                                                    
#######################################################################################################################################################################


$CredObj = ($DirPath + "\" + "EmailExpiry.cred")
$CredObjCheck = Test-Path -Path $CredObj
If (!($CredObjCheck))
{
	"$Date - INFO: creating cred object" | Out-File ($DirPath + "\" + "Log.txt") -Append
	$Credential = Get-Credential -Message "Please enter your Entra ID credential that you will use to send e-mail from $FromEmail. If you are not using the account $FromEmail make sure this account has 'Send As' rights on $FromEmail."
	$Credential | Export-CliXml -Path $CredObj
}

Write-Host "Importing Cred object..." -ForegroundColor Yellow
$Cred = (Import-CliXml -Path $CredObj)

#######################################################################################################################################################################
# Import Powershell Active Directory module                                                                                                                           #
# - Retrieve the user list on dedicated Organizational Unit                                                                                                           #
# - Calculate password age                                                                                                                                #                
#######################################################################################################################################################################

"$Date - INFO: Importing AD Module" | Out-File ($DirPath + "\" + "Log.txt") -Append
Import-Module ActiveDirectory
"$Date - INFO: Getting users" | Out-File ($DirPath + "\" + "Log.txt") -Append
$users = Get-Aduser -Server srv-ad.ecole.lan -SearchBase 'OU=Diplomes,DC=student,DC=ecole,DC=lan' -properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress -filter { (Enabled -eq 'True') -and (PasswordNeverExpires -eq 'False') } | Where-Object { $_.PasswordExpired -eq $False }

$maxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge

#######################################################################################################################################################################
# For all users                                                                                                                                         #
# - Keep email address                                                                                                                                   #
# - Calculate password age                                                                                                                               #                
#######################################################################################################################################################################


foreach ($user in $users)
{
	$Name = (Get-ADUser $user | ForEach-Object { $_.Name })
	Write-Host "Working on $Name..." -ForegroundColor White
	Write-Host "Getting e-mail address for $Name..." -ForegroundColor Yellow
	$emailaddress = $user.emailaddress
	If (!($emailaddress))
	{
		Write-Host "$Name has no E-Mail address listed, looking at their proxyaddresses attribute..." -ForegroundColor Red
		Try
		{
			$emailaddress = (Get-ADUser $user -Properties proxyaddresses | Select-Object -ExpandProperty proxyaddresses | Where-Object { $_ -cmatch '^SMTP' }).Trim("SMTP:")
		}
		Catch
		{
			$_ | Out-File ($DirPath + "\" + "Log.txt") -Append
		}
		If (!($emailaddress))
		{
			Write-Host "$Name has no email addresses to send an e-mail to!" -ForegroundColor Red
			"$Date - WARNING: No email found for $Name" | Out-File ($DirPath + "\" + "Log.txt") -Append
		}
		
	}
	
	$passwordSetDate = (Get-ADUser $user -properties * | ForEach-Object { $_.PasswordLastSet })
	
	$PasswordPol = (Get-ADUserResultantPasswordPolicy $user)
	if (($PasswordPol) -ne $null)
	{
		$maxPasswordAge = ($PasswordPol).MaxPasswordAge
	}
	
	$expireson = $passwordsetdate + $maxPasswordAge
	$today = (get-date)

	$daystoexpire = (New-TimeSpan -Start $today -End $Expireson).Days
    
#######################################################################################################################################################################
# If the password is greater than 0 and less than $expireindays                                                                                                       #
# - Send Email                                                                                                                                                        #                
#######################################################################################################################################################################
	
	If (($daystoexpire -ge "0") -and ($daystoexpire -lt $expireindays))
	{
		"$Date - INFO: Sending expiry notice email to $Name" | Out-File ($DirPath + "\" + "Log.txt") -Append
		Write-Host "Sending Password expiry email to $name" -ForegroundColor Yellow
		
		$SmtpClient = new-object system.net.mail.smtpClient
		$MailMessage = New-Object system.net.mail.mailmessage
		
		$mailmessage.From = $FromEmail
		$SmtpClient.Host = $SMTPHost
		$SMTPClient.EnableSsl = $false
		$SMTPClient.Port = "25"
		$mailmessage.To.add("$emailaddress")
		$mailmessage.Subject = "Your password will expire $daystoexpire days"
		$MailMessage.DeliveryNotificationOptions = ("onSuccess", "onFailure")
		$MailMessage.Priority = "High"
		$mailmessage.Body =
		"Dear $Name,
Your Domain password will expire in $daystoexpire days. Please change it as soon as possible.

To change your password, follow the method below:

1. On your Windows computer
	a.	If you are not in the office, logon and connect to VPN. 
	b.	Log onto your computer as usual and make sure you are connected to the internet.
	c.	Press Ctrl-Alt-Del and click on ""Change Password"".
	d.	Fill in your old password and set a new password.  See the password requirements below.
	e.	Press OK to return to your desktop. 

The new password must meet the minimum requirements set forth in our corporate policies including:
	1.	It must be at least 8 characters long.
	2.	It must contain at least one character from 3 of the 4 following groups of characters:
		a.  Uppercase letters (A-Z)
		b.  Lowercase letters (a-z)
		c.  Numbers (0-9)
		d.  Symbols (!@#$%^&*...)
	3.	It cannot match any of your past 24 passwords.
	4.	It cannot contain characters which match 3 or more consecutive characters of your username.
	5.	You cannot change your password more often than once in a 24 hour period.

If you have any questions please contact our Support team at support@InYourCloud.fr or call us at +33X XX XX XX XX

Thanks,
The IT Administrator
support@InYourCloud.fr
+33X XX XX XX XX"
		Write-Host "Sending E-mail to $emailaddress..." -ForegroundColor Green
		Try
		{
			$smtpclient.Send($mailmessage)
		}
		Catch
		{
			$_ | Out-File ($DirPath + "\" + "Log.txt") -Append
		}
	}
	Else
	{
		"$Date - INFO: Password for $Name not expiring for $daystoexpire days" | Out-File ($DirPath + "\" + "Log.txt") -Append
		Write-Host "Password for $Name does not expire for $daystoexpire days" -ForegroundColor White
	}
}