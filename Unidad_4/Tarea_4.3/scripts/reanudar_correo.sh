#!/bin/bash
# Corrige los buzones existentes y repite la prueba de correo.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Ejecuta mediante sudo.'; exit 1; }
BASE=$(cd -- "$(dirname -- "$0")/.." && pwd)
bash "$BASE/scripts/crear_buzones.sh"
if [[ $# == 1 && $1 =~ ^[A-Za-z0-9]+$ ]]; then
    postqueue -i "$1" || true
fi
bash "$BASE/scripts/probar_correo.sh"
