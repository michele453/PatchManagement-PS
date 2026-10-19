param(
    [string]$Path = "C:\PatchManagement\config\computers.txt",
    [string]$OutCsv = "C:\PatchManagement\output\Inventory.csv",
    [System.Management.Automation.PSCredential]$Credential
)

if (-not $Credential) { $Credential = Get-Credential -Message "Compte administrateur des postes supervises" }

$bloc = {
    $os   = Get-CimInstance Win32_OperatingSystem
    $cs   = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"
    $hf   = Get-HotFix | Where-Object InstalledOn | Sort-Object InstalledOn -Descending
    $wu   = Get-Service wuauserv
    [PSCustomObject]@{
        NomPoste         = $env:COMPUTERNAME
        Modele           = $cs.Model
        VersionBIOS      = $bios.SMBIOSBIOSVersion
        Windows          = $os.Caption
        VersionWindows   = $os.Version
        Architecture     = $os.OSArchitecture
        DernierDemarrage = $os.LastBootUpTime
        RAM_Go           = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        DisqueLibre_Go   = [math]::Round($disk.FreeSpace / 1GB, 1)
        DerniereMAJ      = ($hf | Select-Object -First 1).InstalledOn
        NbMAJ            = @(Get-HotFix).Count
        WindowsUpdate    = $wu.Status.ToString()
    }
}

$inventaire = foreach ($ligne in Get-Content $Path | Where-Object { $_.Trim() -ne "" }) {
    $nom, $ip = ($ligne -split ';') | ForEach-Object { $_.Trim() }

    $obj = [ordered]@{
        Poste = $nom; AdresseIP = $ip; Modele = "-"; VersionBIOS = "-"; Windows = "-"
        VersionWindows = "-"; Architecture = "-"; DernierDemarrage = "-"; RAM_Go = "-"
        DisqueLibre_Go = "-"; DerniereMAJ = "-"; NbMAJ = "-"; WindowsUpdate = "-"
        Etat = "Inaccessible"; Erreur = ""
    }

    if (-not (Test-NetConnection -ComputerName $ip -Port 5985 -WarningAction SilentlyContinue -InformationLevel Quiet)) {
        $obj.Erreur = "WinRM (5985) sans reponse"
        [PSCustomObject]$obj
        continue
    }

    try {
        $r = Invoke-Command -ComputerName $ip -Credential $Credential -ScriptBlock $bloc -ErrorAction Stop
        $obj.Etat             = "Accessible"
        $obj.Modele           = $r.Modele
        $obj.VersionBIOS      = $r.VersionBIOS
        $obj.Windows          = $r.Windows
        $obj.VersionWindows   = $r.VersionWindows
        $obj.Architecture     = $r.Architecture
        $obj.DernierDemarrage = $r.DernierDemarrage
        $obj.RAM_Go           = $r.RAM_Go
        $obj.DisqueLibre_Go   = $r.DisqueLibre_Go
        $obj.DerniereMAJ      = $r.DerniereMAJ
        $obj.NbMAJ            = $r.NbMAJ
        $obj.WindowsUpdate    = $r.WindowsUpdate
    }
    catch {
        $obj.Etat   = "Inaccessible"
        $obj.Erreur = $_.Exception.Message
    }
    [PSCustomObject]$obj
}

$inventaire | Format-Table Poste, AdresseIP, Windows, Architecture, DernierDemarrage, WindowsUpdate, Etat -AutoSize
$inventaire | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8 -Delimiter ';'
Write-Host "Inventaire exporte : $OutCsv" -ForegroundColor Green
