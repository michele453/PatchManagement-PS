# Partie 8 : mesures de securisation (a executer sur le poste supervise, en administrateur)
param([string]$AdminIP = "192.168.192.1")

# 8.3 Compte d'audit a moindre privilege
if (-not (Get-LocalUser -Name patchsvc -ErrorAction SilentlyContinue)) {
    $pwd = Read-Host "Mot de passe patchsvc" -AsSecureString
    New-LocalUser -Name patchsvc -Password $pwd -PasswordNeverExpires -Description "Compte audit patchs"
}
Add-LocalGroupMember -Group "Remote Management Users" -Member patchsvc -ErrorAction SilentlyContinue

# 8.5 Pare-feu : WinRM uniquement depuis le poste d'administration
Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP-NoScope","WINRM-HTTP-In-TCP" -RemoteAddress $AdminIP

# 8.8 Journalisation PowerShell
$k = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
New-Item $k -Force | Out-Null
Set-ItemProperty $k -Name EnableScriptBlockLogging -Value 1

# Verification
Get-LocalGroupMember "Remote Management Users"
Get-NetFirewallRule -DisplayGroup "Windows Remote Management" | Get-NetFirewallAddressFilter | Select InstanceID, RemoteAddress
