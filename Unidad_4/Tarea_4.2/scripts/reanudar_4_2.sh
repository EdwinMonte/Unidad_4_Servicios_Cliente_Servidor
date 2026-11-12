#!/bin/bash
# Ajusta el home de las dos cuentas de transferencia y repite solo las pruebas.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Ejecuta mediante sudo.'; exit 1; }
BASE=$(cd -- "$(dirname -- "$0")/.." && pwd)
for usuario in archivo1 archivo2; do
    [[ $(id -gn "$usuario") == u4transfer ]]
    test -d "/srv/u4transfer/$usuario/datos"
    usermod -d "/srv/u4transfer/$usuario" "$usuario"
done
bash "$BASE/scripts/probar_4_2.sh"
