param([string]$Path = "C:\PatchManagement\config\computers.txt")

$resultats = foreach ($ligne in Get-Content $Path | Where-Object { $_.Trim() -ne "" }) {
    $nom, $ip = ($ligne -split ';') | ForEach-Object { $_.Trim() }
    $ping  = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue
    $wsman = [bool](Test-NetConnection -ComputerName $ip -Port 5985 -WarningAction SilentlyContinue -InformationLevel Quiet)
    [PSCustomObject]@{
        Poste     = $nom
        AdresseIP = $ip
        Ping      = $ping
        WinRM     = $wsman
        Etat      = if ($wsman) { "Accessible" } else { "Inaccessible" }
    }
}
$resultats | Format-Table -AutoSize
