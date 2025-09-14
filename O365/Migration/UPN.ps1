#Intall required module if not already installed
If (-not (Get-Module -ListAvailable -Name AzureAD)) {
    Install-Module -Name AzureAD
}  

$Cred = get-credential
Connect-AzureAD -Credential $Cred

# Obtenir tous les utilisateurs
$csvPath = "Mail.csv"

$Users= Get-Content -Path $csvPath


Write-Host "Début de la mise à jour des UPN..." -ForegroundColor Green

foreach ($user in $users) {
    # Vérifier si l'UPN contient l'ancien domaine
   
    $UserDetails = $User -split ","
    $SourceUPN = $UserDetails[0]
    $TargetUPN = $UserDetails[1]

    Set-AzureADUser -ObjectId $SourceUPN -UserPrincipalName $TargetUPN 
    
}

Write-Host "Script terminé." -ForegroundColor Cyan