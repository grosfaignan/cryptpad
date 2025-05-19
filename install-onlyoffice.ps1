<#
.SYNOPSIS
Installe ou met à niveau OnlyOffice.

.DESCRIPTION
Ce script télécharge et installe les versions nécessaires d'OnlyOffice.

.NOTES
Nom du fichier: install-onlyoffice.ps1
#>

# Définir la stratégie d'exécution pour permettre l'exécution du script
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Paramètres
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$CONF_DIR = "$SCRIPT_DIR/onlyoffice-conf"
$BUILDS_DIR = "$CONF_DIR/onlyoffice-builds.git"
$OO_DIR = "$SCRIPT_DIR/www/common/onlyoffice/dist"
$PROPS_FILE = "$CONF_DIR/onlyoffice.properties"
$PROPS = @{}
$ACCEPT_LICENSE = $false
$TRUST_REPOSITORY = $false
$CHECK = $false
$RDFIND = $null

# Fonctions

function Load-Props {
    if (Test-Path $PROPS_FILE) {
        (Get-Content $PROPS_FILE) | ForEach-Object {
            $line = $_.Trim()
            if ($line -match '=') {
                $key, $value = $line.Split('=')
                $PROPS[$key.Trim()] = $value.Trim()
            }
        }
    }
}

function Set-Prop {
    param (
        [string]$Key,
        [string]$Value
    )
    $PROPS[$Key] = $Value
    $PROPS.GetEnumerator() | ForEach-Object {
        "$($_.Key)=$($_.Value)" | Out-File -FilePath $PROPS_FILE -Encoding UTF8 -Append
    }
}

function Parse-Arguments {
    param (
        [string[]]$Arguments
    )

    for ($i = 0; $i -lt $Arguments.Length; $i++) {
        switch ($Arguments[$i]) {
            "-h" {
                Show-Help
                exit
            }
            "--help" {
                Show-Help
                exit
            }
            "-a" {
                $script:ACCEPT_LICENSE = $true
            }
            "--accept-license" {
                $script:ACCEPT_LICENSE = $true
            }
            "-t" {
                $script:TRUST_REPOSITORY = $true
            }
            "--trust-repository" {
                $script:TRUST_REPOSITORY = $true
            }
            "--check" {
                $script:CHECK = $true
            }
            "--rdfind" {
                $script:RDFIND = "1"
            }
            "--no-rdfind" {
                $script:RDFIND = "0"
            }
            default {
                Show-Help
                exit
            }
        }
    }
}


function Ask-For-License {
    if ($ACCEPT_LICENSE -or ($PROPS["agree_license"] -eq "yes")) {
        return
    }

    Ensure-Command-Available curl

    Write-Host "Please review the license of OnlyOffice:"
    curl https://raw.githubusercontent.com/ONLYOFFICE/web-apps/master/LICENSE.txt

    $confirm = Read-Host "Do you accept the license? (Y/N)"
    if ($confirm -match "^[yY]|^[yY][eE][sS]") {
        Set-Prop "agree_license" "yes"
    } else {
        exit 1
    }
}

function Show-Help {
    Write-Host @"
install-onlyoffice installs or upgrades OnlyOffice.

OPTIONS:
    -h, --help
            Show this help.

    -a, --accept-license
            Accept the license of OnlyOffice and do not ask when running this
            script. Read and accept this before using this option:
            https://github.com/ONLYOFFICE/web-apps/blob/master/LICENSE.txt

    -t, --trust-repository
            Automatically configure the cloned onlyoffice-builds repository
            as a safe.directory.
            https://git-scm.com/docs/git-config/#Documentation/git-config.txt-safedirectory

    --check
            Do not install OnlyOffice, only check if the existing installation
            is up to date. Exits 0 if it is up to date, nonzero otherwise.

    --rdfind
            Run rdfind to save ~650MB of disk space.
            If neither '--rdfind' nor '--no-rdfind' is specified, then rdfind
            will only run if rdfind is installed.

    --no-rdfind
            Do not run rdfind, even if it is installed.
"@
    exit 1
}

function Ensure-OO-Is-Downloaded {
    Ensure-Command-Available git

    if (!(Test-Path $BUILDS_DIR -PathType Container)) {
        Write-Host "Downloading OnlyOffice..."
        git clone --bare https://github.com/cryptpad/onlyoffice-builds.git $BUILDS_DIR
    }
    if ($TRUST_REPOSITORY -or ($PROPS["trust_repository"] -eq "yes")) {
        git config --global --add safe.directory /cryptpad/onlyoffice-conf/onlyoffice-builds.git
    }
}

function Install-Version {
    param (
        [string]$DIR,
        [string]$COMMIT
    )

    $FULL_DIR = "$OO_DIR/$DIR"
    $ACTUAL_COMMIT = "not installed"
    if (Test-Path "$FULL_DIR/.commit") {
        $ACTUAL_COMMIT = Get-Content "$FULL_DIR/.commit"
    }

    if ($ACTUAL_COMMIT -ne $COMMIT) {
        if ($CHECK) {
            Write-Host "Wrong commit of $FULL_DIR found. Expected: $COMMIT. Actual: $ACTUAL_COMMIT"
            exit 1
        }

        Ensure-OO-Is-Downloaded

        Remove-Item -Path $FULL_DIR -Recurse -Force

        Push-Location $BUILDS_DIR
        git worktree add "$FULL_DIR" "$COMMIT"
        Pop-Location

        "$COMMIT" | Out-File -FilePath "$FULL_DIR/.commit" -Encoding UTF8

        Write-Host "$DIR updated"
    } else {
        Write-Host "$DIR was up to date"
    }

    if ($PSBoundParameters.ContainsKey("CLEAR")) {
        Remove-Item -Path "$FULL_DIR/.git" -Recurse -Force
    }
}

function Install-X2T {
    param (
        [string]$VERSION,
        [string]$HASH
    )

    $X2T_DIR = "$OO_DIR/x2t"
    $ACTUAL_VERSION = "not installed"
    if (Test-Path "$X2T_DIR/.version") {
        $ACTUAL_VERSION = Get-Content "$X2T_DIR/.version"
    }

    if (!(Test-Path "$X2T_DIR/.version") -or ((Get-Content "$X2T_DIR/.version") -ne $VERSION)) {
        if ($CHECK) {
            Write-Host "Wrong version of x2t found. Expected: $VERSION. Actual: $ACTUAL_VERSION"
            exit 1
        }

        Remove-Item -Path $X2T_DIR -Recurse -Force
        New-Item -ItemType Directory -Path $X2T_DIR | Out-Null

        Push-Location $X2T_DIR

        Ensure-Command-Available curl
        Ensure-Command-Available sha512sum
        Ensure-Command-Available unzip

        curl "https://github.com/cryptpad/onlyoffice-x2t-wasm/releases/download/$VERSION/x2t.zip" --location --output x2t.zip
        "$HASH x2t.zip" | Out-File -FilePath x2t.zip.sha512 -Encoding UTF8
        if (!(sha512sum --check x2t.zip.sha512)) {
            Write-Host "x2t.zip does not match expected checksum"
            exit 1
        }
        unzip x2t.zip
        Remove-Item x2t.zip*, x2t.zip

        "$VERSION" | Out-File -FilePath "$X2T_DIR/.version" -Encoding UTF8

        Write-Host "x2t updated"
        Pop-Location
    } else {
        Write-Host "x2t was up to date"
    }
}

function Ensure-Command-Available {
    param (
        [string]$Command
    )
    if (!(Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Host "$Command needs to be installed to run this script"
        exit 1
    }
}

# Main

# Préparer l'environnement
New-Item -ItemType Directory -Force -Path $CONF_DIR | Out-Null
Load-Props
Parse-Arguments $args

Ask-For-License

# Se souvenir de la 1ère version installée. Cela nous aidera à installer uniquement
# les versions d'OnlyOffice nécessaires dans une version ultérieure de ce script.
Set-Prop oldest_needed_version v1

New-Item -ItemType Directory -Force -Path $OO_DIR | Out-Null
Install-Version v1 4f370beb
Install-Version v2b d9da72fd
Install-Version v4 6ebc6938
Install-Version v5 88a356f0
Install-Version v6 abd8a309
Install-Version v7 e1267803
Install-X2T "v7.3+1" ab0c05b0e4c81071acea83f0c6a8e75f5870c360ec4abc4af09105dd9b52264af9711ec0b7020e87095193ac9b6e20305e446f2321a541f743626a598e5318c1

Remove-Item -Path $BUILDS_DIR -Recurse -Force

if ($RDFIND -ne "0") {
    if ($RDFIND -eq "1" -or (Get-Command rdfind -ErrorAction SilentlyContinue)) {
        Ensure-Command-Available rdfind
        rdfind -makehardlinks true -makeresultsfile false "$OO_DIR/v*"
    }
}