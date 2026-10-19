param(
    [string]$Path = "C:\PatchManagement\config\computers.txt",
    [string]$Required = "C:\PatchManagement\config\required-patches.txt",
    [string]$OutCsv = "C:\PatchManagement\output\ComplianceReport.csv",
    [System.Management.Automation.PSCredential]$Credential
)

if (-not $Credential) { $Credential = Get-Credential -Message "Compte administrateur des postes supervises" }

$requis = Get-Content $Required | ForEach-Object { $_.Trim().ToUpper() } | Where-Object { $_ -match '^KB\d+$' }
$dateControle = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

$rapport = foreach ($ligne in Get-Content $Path | Where-Object { $_.Trim() -ne "" }) {
    $nom, $ip = ($ligne -split ';') | ForEach-Object { $_.Trim() }

    $obj = [ordered]@{
        Poste = $nom; AdresseIP = $ip; KB_Requises = $requis.Count
        KB_Manquantes = "-"; ListeManquantes = "-"; Etat = "INACCESSIBLE"
        DateControle = $dateControle; Erreur = ""
    }

    if (-not (Test-NetConnection -ComputerName $ip -Port 5985 -WarningAction SilentlyContinue -InformationLevel Quiet)) {
        $obj.Erreur = "WinRM (5985) sans reponse"
        [PSCustomObject]$obj
        continue
    }

    try {
        $installes = Invoke-Command -ComputerName $ip -Credential $Credential -ErrorAction Stop -ScriptBlock {
            (Get-HotFix).HotFixID
        }
        $manquants = @($requis | Where-Object { $installes -notcontains $_ })
        $obj.KB_Manquantes   = $manquants.Count
        $obj.ListeManquantes = if ($manquants.Count -gt 0) { $manquants -join ',' } else { "Aucune" }
        $obj.Etat            = if ($manquants.Count -eq 0) { "CONFORME" } else { "NON CONFORME" }
    }
    catch {
        $obj.Erreur = $_.Exception.Message
    }
    [PSCustomObject]$obj
}

$rapport | Format-Table Poste, AdresseIP, KB_Requises, KB_Manquantes, ListeManquantes, Etat, DateControle -AutoSize
$rapport | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8 -Delimiter ';'

$controles = @($rapport | Where-Object { $_.Etat -ne "INACCESSIBLE" })
$conformes = @($controles | Where-Object { $_.Etat -eq "CONFORME" })
$taux = if ($controles.Count -gt 0) { [math]::Round(100 * $conformes.Count / $controles.Count, 1) } else { 0 }

Write-Host "`nTaux global de conformite (hors inaccessibles) : $taux % ($($conformes.Count)/$($controles.Count))" -ForegroundColor Cyan
Write-Host "Rapport exporte : $OutCsv" -ForegroundColor Green
