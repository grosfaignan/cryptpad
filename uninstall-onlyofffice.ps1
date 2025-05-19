# uninstall-onlyoffice.ps1
# Supprime les composants OnlyOffice installés par install-onlyoffice.ps1

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfDir = Join-Path $ScriptDir "onlyoffice-conf"
$BuildsDir = Join-Path $ConfDir "onlyoffice-builds.git"
$OOdir = Join-Path $ScriptDir "www/common/onlyoffice/dist"
$PropsFile = Join-Path $ConfDir "onlyoffice.properties"

function Remove-IfExists {
    param([string]$Path)
    if (Test-Path $Path) {
        Write-Host "Supprime : $Path"
        Remove-Item $Path -Recurse -Force
    }
}

function Main {
    Write-Host "Désinstallation des composants OnlyOffice..."

    # Supprimer chaque version installée
    $Versions = @("v1", "v2b", "v4", "v5", "v6", "v7", "x2t")
    foreach ($version in $Versions) {
        $path = Join-Path $OOdir $version
        Remove-IfExists -Path $path
    }

    # Supprimer le repo git clone
    Remove-IfExists -Path $BuildsDir

    # Supprimer les fichiers de config
    Remove-IfExists -Path $PropsFile

    # Supprimer le dossier dist s'il est vide
    if (Test-Path $OOdir) {
        $contents = Get-ChildItem $OOdir
        if ($contents.Count -eq 0) {
            Remove-Item $OOdir -Force
            Write-Host "Le dossier dist était vide et a été supprimé."
        }
    }

    # Supprimer le dossier onlyoffice-conf s'il est vide
    if (Test-Path $ConfDir) {
        $contents = Get-ChildItem $ConfDir
        if ($contents.Count -eq 0) {
            Remove-Item $ConfDir -Force
            Write-Host "Le dossier onlyoffice-conf était vide et a été supprimé."
        }
    }

    Write-Host "Désinstallation terminée."
}

Main
