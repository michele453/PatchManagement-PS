# PatchManagement-PS

Audit des correctifs de securite d'un parc Windows avec PowerShell Remoting (WinRM).

## Prerequis
- PowerShell 5.1, poste d'administration Windows
- WinRM actif sur les postes supervises (`Enable-PSRemoting`)
- Compte d'audit (ex. `patchsvc`, membre de *Remote Management Users*)

## Configuration
- `config/computers.txt` : `NOM;IP`, une machine par ligne
- `config/required-patches.txt` : un KB obligatoire par ligne
- `secrets/smtp.cred` (non versionne) : `Get-Credential | Export-Clixml secrets\smtp.cred`

## Utilisation
    Set-ExecutionPolicy -Scope Process Bypass
    $cred = Get-Credential
    .\scripts\01-Test-Parc.ps1
    .\scripts\02-Inventaire.ps1 -Credential $cred
    .\scripts\03-Correctifs.ps1 -Credential $cred
    .\scripts\04-Conformite.ps1 -Credential $cred
    .\scripts\06-Rapport.ps1    -Credential $cred
    .\scripts\07-Notification.ps1

## Sorties (dossier `output/`, ignore par Git)
Inventory.csv, PatchesInventory.csv, ComplianceReport.csv, SecurityReport.csv/.html, PatchManager.log.
Des exemples sont dans `exemples/`.

## Securite
Aucun mot de passe dans le code ; identifiants chiffres (DPAPI) ; `.gitignore` sur `secrets/` et `output/`.
