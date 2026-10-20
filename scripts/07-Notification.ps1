param(
    [string]$Csv = "C:\PatchManagement\output\SecurityReport.csv",
    [string]$Html = "C:\PatchManagement\output\SecurityReport.html",
    [string]$Log = "C:\PatchManagement\output\PatchManager.log",
    [string]$CredFile = "C:\PatchManagement\secrets\smtp.cred",
    [string]$SmtpServer = "smtp.gmail.com",
    [int]$Port = 587,
    [string]$From = "rstainglionel@gmail.com",
    [string]$To = "simomichele453@gmail.com"
)

function Write-Log([string]$msg) {
    "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') ; $msg" | Add-Content -Path $Log -Encoding UTF8
}

$rapport = Import-Csv $Csv -Delimiter ';'
$nonconf = @($rapport | Where-Object Etat -eq "NON CONFORME")
$inacc   = @($rapport | Where-Object Etat -eq "INACCESSIBLE")

if (($nonconf.Count + $inacc.Count) -eq 0) {
    Write-Host "Aucune anomalie : pas de notification." -ForegroundColor Green
    Write-Log "Aucune anomalie ; notification non necessaire"
    return
}

$date = Get-Date -Format "dd/MM/yyyy"
$corps = @"
Date du controle : $date

Postes controles      : $($rapport.Count)
Postes non conformes  : $($nonconf.Count)
Postes inaccessibles  : $($inacc.Count)

"@
foreach ($p in $nonconf) {
    $corps += "$($p.Poste) : NON CONFORME`r`n"
    foreach ($kb in ($p.ListeManquantes -split ',\s*')) { $corps += "        $kb manquante`r`n" }
    $corps += "`r`n"
}
foreach ($p in $inacc) { $corps += "$($p.Poste) : INACCESSIBLE`r`n`r`n" }

try {
    $cred = Import-Clixml $CredFile
    Send-MailMessage -From $From -To $To -Subject "[PATCH MANAGEMENT] Anomalies detectees" `
        -Body $corps -Attachments $Html -SmtpServer $SmtpServer -Port $Port -UseSsl `
        -Credential $cred -Encoding UTF8 -ErrorAction Stop
    Write-Log "Notification envoyee a $To"
    Write-Host "Notification envoyee a $To" -ForegroundColor Green
}
catch {
    Write-Log "ERREUR ; Notification non envoyee"
    Write-Host "Notification non envoyee : $($_.Exception.Message)" -ForegroundColor Red
}
