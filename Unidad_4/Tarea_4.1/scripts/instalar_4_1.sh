#!/bin/bash
# Instala BIND9 y Kea DHCPv4 para el segmento aislado U4_LAB.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Ejecuta mediante sudo.'; exit 1; }
BASE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$BASE"
install -d -o edwinmonte -g "$(id -gn edwinmonte)" -m 750 evidencias
log="evidencias/instalacion_$(date +%Y%m%d_%H%M%S).log"
install -o edwinmonte -g "$(id -gn edwinmonte)" -m 600 /dev/null "$log"
exec > >(tee "$log") 2>&1

[[ $(cat /sys/class/net/ens37/address) == 00:0c:29:be:a2:18 ]]
ip -4 route show default dev ens33 | grep -q '^default '
[[ -z $(ip -4 route show default dev ens37) ]]
ip -br addr

# Impedir el arranque automático de Kea mientras se instala el paquete.
systemctl mask --runtime kea-dhcp4-server.service
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y bind9 bind9-utils dnsutils kea-dhcp4-server

respaldo=$(mktemp -d /root/unidad4-41.XXXXXXXX)
cp -p /etc/bind/named.conf.local /etc/bind/named.conf.options /etc/kea/kea-dhcp4.conf "$respaldo/"
echo "Configuración anterior: $respaldo"

install -m 600 config/90-unidad4-lab.yaml /etc/netplan/90-unidad4-lab.yaml
netplan generate
netplan apply
ip -4 -o addr show dev ens37 | grep -F '10.44.0.10/24'
ip -4 route show default dev ens33 | grep '^default '

for archivo in named.conf.local named.conf.options db.empresa.test db.rev; do
    install -m 644 "config/$archivo" "/etc/bind/$archivo"
done
exec bash "$BASE/scripts/activar_4_1.sh"
