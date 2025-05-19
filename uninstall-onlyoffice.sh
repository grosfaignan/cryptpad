#!/usr/bin/env bash

# Désinstalle tous les composants OnlyOffice installés par install-onlyoffice.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CONF_DIR="$SCRIPT_DIR/onlyoffice-conf"
BUILDS_DIR="$CONF_DIR/onlyoffice-builds.git"
OO_DIR="$SCRIPT_DIR/www/common/onlyoffice/dist"
PROPS_FILE="$CONF_DIR/onlyoffice.properties"

remove_if_exists() {
    local path="$1"
    if [ -e "$path" ]; then
        echo "Suppression : $path"
        rm -rf "$path"
    fi
}

main() {
    echo "Désinstallation des composants OnlyOffice..."

    # Supprimer les versions spécifiques
    for version in v1 v2b v4 v5 v6 v7 x2t; do
        remove_if_exists "$OO_DIR/$version"
    done

    # Supprimer le repo Git clone
    remove_if_exists "$BUILDS_DIR"

    # Supprimer les fichiers de config
    remove_if_exists "$PROPS_FILE"

    # Supprimer le dossier dist s'il est vide
    if [ -d "$OO_DIR" ] && [ -z "$(ls -A "$OO_DIR")" ]; then
        rm -rf "$OO_DIR"
        echo "Le dossier dist était vide et a été supprimé."
    fi

    # Supprimer le dossier onlyoffice-conf s'il est vide
    if [ -d "$CONF_DIR" ] && [ -z "$(ls -A "$CONF_DIR")" ]; then
        rm -rf "$CONF_DIR"
        echo "Le dossier onlyoffice-conf était vide et a été supprimé."
    fi

    echo "Désinstallation terminée."
}

main "$@"
