param(
    [string]$Path = "C:\PatchManagement\config\computers.txt",
    [string]$Required = "C:\PatchManagement\config\required-patches.txt",
    [string]$OutDir = "C:\PatchManagement\output",
    [System.Management.Automation.PSCredential]$Credential
)

if (-not $Credential) { $Credential = Get-Credential -Message "Compte administrateur des postes supervises" }
$Log = Join-Path $OutDir "PatchManager.log"
function Write-Log([string]$msg) {
    "$(Get-Date -Format 'dd/MM/yyyy HH:mm:ss') ; $msg" | Add-Content -Path $Log -Encoding UTF8
}

Write-Log "Debut de l'audit"
$requis = Get-Content $Required | ForEach-Object { $_.Trim().ToUpper() } | Where-Object { $_ -match '^KB\d+$' }
$dateControle = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

$bloc = {
    $os = Get-CimInstance Win32_OperatingSystem
    [PSCustomObject]@{
        Windows   = $os.Caption
        Demarrage = $os.LastBootUpTime.ToString("dd/MM/yyyy HH:mm")
        WU        = (Get-Service wuauserv).Status.ToString()
        KB        = @((Get-HotFix).HotFixID)
    }
}

$rapport = foreach ($ligne in Get-Content $Path | Where-Object { $_.Trim() -ne "" }) {
    $nom, $ip = ($ligne -split ';') | ForEach-Object { $_.Trim() }
    $o = [ordered]@{
        Poste = $nom; AdresseIP = $ip; Accessibilite = "Inaccessible"; Windows = "-"
        DernierDemarrage = "-"; WindowsUpdate = "-"; KB_Requises = $requis.Count
        KB_Manquantes = 0; ListeManquantes = "-"; Etat = "INACCESSIBLE"; DateControle = $dateControle
    }

    if (-not (Test-NetConnection -ComputerName $ip -Port 5985 -WarningAction SilentlyContinue -InformationLevel Quiet)) {
        Write-Log "$nom ; WinRM inaccessible"
        [PSCustomObject]$o; continue
    }
    try {
        $r = Invoke-Command -ComputerName $ip -Credential $Credential -ScriptBlock $bloc -ErrorAction Stop
        Write-Log "$nom ; Accessible"
        $manq = @($requis | Where-Object { $r.KB -notcontains $_ })
        $o.Accessibilite = "Accessible"; $o.Windows = $r.Windows
        $o.DernierDemarrage = $r.Demarrage; $o.WindowsUpdate = $r.WU
        $o.KB_Manquantes = $manq.Count
        if ($manq.Count -eq 0) {
            $o.ListeManquantes = "Aucune"; $o.Etat = "CONFORME"; Write-Log "$nom ; Conforme"
        } else {
            $o.ListeManquantes = $manq -join ', '; $o.Etat = "NON CONFORME"
            Write-Log "$nom ; Non conforme ; $($manq -join ', ')"
        }
    }
    catch { Write-Log "$nom ; ERREUR ; $($_.Exception.Message)" }
    [PSCustomObject]$o
}

# Synthese
$total   = @($rapport).Count
$acc     = @($rapport | Where-Object Accessibilite -eq "Accessible").Count
$inacc   = $total - $acc
$conf    = @($rapport | Where-Object Etat -eq "CONFORME").Count
$nonconf = @($rapport | Where-Object Etat -eq "NON CONFORME").Count
$kbManq  = ($rapport | Measure-Object KB_Manquantes -Sum).Sum
$taux    = if (($conf + $nonconf) -gt 0) { [math]::Round(100 * $conf / ($conf + $nonconf), 1) } else { 0 }
$aTraiter = @($rapport | Where-Object { $_.Etat -ne "CONFORME" })

$rapport | Export-Csv "$OutDir\SecurityReport.csv" -NoTypeInformation -Encoding UTF8 -Delimiter ';'

# HTML
$style = "<style>body{font-family:Segoe UI,Arial;margin:30px}h1{color:#1f3a5f}table{border-collapse:collapse;margin-bottom:20px}th,td{border:1px solid #ccc;padding:6px 10px}th{background:#1f3a5f;color:#fff}.ok{color:#1a7f37;font-weight:bold}.ko{color:#c62828;font-weight:bold}</style>"
$syn = @"
<table><tr><th>Indicateur</th><th>Valeur</th></tr>
<tr><td>Nombre total de postes</td><td>$total</td></tr>
<tr><td>Postes accessibles</td><td>$acc</td></tr>
<tr><td>Postes inaccessibles</td><td>$inacc</td></tr>
<tr><td>Postes conformes</td><td>$conf</td></tr>
<tr><td>Postes non conformes</td><td>$nonconf</td></tr>
<tr><td>Total correctifs manquants</td><td>$kbManq</td></tr>
<tr><td>Taux de conformite</td><td>$taux %</td></tr></table>
"@
$detail = $rapport | Select-Object Poste, AdresseIP, Accessibilite, Windows, DernierDemarrage, WindowsUpdate, KB_Requises, KB_Manquantes, ListeManquantes, Etat, DateControle | ConvertTo-Html -Fragment
$interv = if ($aTraiter.Count -gt 0) {
    $aTraiter | Select-Object Poste, AdresseIP, Etat, ListeManquantes | ConvertTo-Html -Fragment
} else { "<p class='ok'>Aucune intervention necessaire.</p>" }

$html = "<html><head><meta charset='utf-8'><title>Rapport de securite</title>$style</head><body>" +
        "<h1>Rapport de securite - Patch Management</h1><p>Date du controle : $dateControle</p>" +
        "<h2>Synthese globale</h2>$syn<h2>Detail par poste</h2>$detail" +
        "<h2>Postes necessitant une intervention</h2>$interv</body></html>"
$html = $html -replace '<td>CONFORME</td>', "<td class='ok'>CONFORME</td>" -replace '<td>NON CONFORME</td>', "<td class='ko'>NON CONFORME</td>" -replace '<td>INACCESSIBLE</td>', "<td class='ko'>INACCESSIBLE</td>"
$html | Set-Content "$OutDir\SecurityReport.html" -Encoding UTF8

Write-Log "Rapport genere"
Write-Log "Fin de l'audit"

Write-Host "`n=== Synthese ===" -ForegroundColor Cyan
"Total: $total | Accessibles: $acc | Inaccessibles: $inacc | Conformes: $conf | Non conformes: $nonconf | KB manquants: $kbManq | Taux: $taux %"
Write-Host "Rapport : $OutDir\SecurityReport.html" -ForegroundColor Green
