param(
    [string]$Path = "C:\PatchManagement\config\computers.txt",
    [string]$OutCsv = "C:\PatchManagement\output\PatchesInventory.csv",
    [System.Management.Automation.PSCredential]$Credential
)

if (-not $Credential) { $Credential = Get-Credential -Message "Compte administrateur des postes supervises" }

$bloc = {
    Get-HotFix | ForEach-Object {
        [PSCustomObject]@{
            KB          = $_.HotFixID
            Description = $_.Description
            Date        = $_.InstalledOn
            InstallePar = $_.InstalledBy
        }
    }
}

$patches = foreach ($ligne in Get-Content $Path | Where-Object { $_.Trim() -ne "" }) {
    $nom, $ip = ($ligne -split ';') | ForEach-Object { $_.Trim() }

    if (-not (Test-NetConnection -ComputerName $ip -Port 5985 -WarningAction SilentlyContinue -InformationLevel Quiet)) {
        Write-Warning "$nom ($ip) : inaccessible, ignore."
        continue
    }
    try {
        $r = Invoke-Command -ComputerName $ip -Credential $Credential -ScriptBlock $bloc -ErrorAction Stop
        foreach ($p in $r) {
            [PSCustomObject]@{
                Poste            = $nom
                AdresseIP        = $ip
                KB               = $p.KB
                Description      = $p.Description
                DateInstallation = $p.Date
                InstallePar      = $p.InstallePar
            }
        }
    }
    catch {
        Write-Warning "$nom ($ip) : erreur WinRM - $($_.Exception.Message)"
    }
}

$patches = $patches | Sort-Object Poste, @{Expression = 'DateInstallation'; Descending = $true}
$patches | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8 -Delimiter ';'

Write-Host "`n=== Resume par machine ===" -ForegroundColor Cyan
$patches | Group-Object Poste | ForEach-Object {
    $dernier = $_.Group | Where-Object DateInstallation | Sort-Object DateInstallation -Descending | Select-Object -First 1
    [PSCustomObject]@{
        Poste        = $_.Name
        NbCorrectifs = $_.Count
        DateDernier  = $dernier.DateInstallation
        DernierKB    = $dernier.KB
    }
} | Format-Table -AutoSize

Write-Host "Inventaire des correctifs exporte : $OutCsv" -ForegroundColor Green
