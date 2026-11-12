#!/bin/bash
# Valida y activa los servicios después de instalar los paquetes y configurar ens37.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Ejecuta mediante sudo.'; exit 1; }
BASE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$BASE"
log="evidencias/activacion_$(date +%Y%m%d_%H%M%S).log"
install -o edwinmonte -g "$(id -gn edwinmonte)" -m 600 /dev/null "$log"
exec > >(tee "$log") 2>&1
[[ $(cat /sys/class/net/ens37/address) == 00:0c:29:be:a2:18 ]]
ip -4 -o addr show dev ens37 | grep -F '10.44.0.10/24'
ip -4 route show default dev ens33 | grep '^default '
[[ -z $(ip -4 route show default dev ens37) ]]

install -o root -g _kea -m 640 config/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf
install -d -o _kea -g _kea -m 750 /run/lock/kea
named-checkconf -z
runuser -u _kea -- env KEA_LOCKFILE_DIR=/run/lock/kea /usr/sbin/kea-dhcp4 -t /etc/kea/kea-dhcp4.conf

systemctl enable named.service
systemctl restart named.service
for intento in {1..5}; do
    if [[ $(dig +short +time=1 +tries=1 @10.44.0.10 web.empresa.test A) == 10.44.0.10 ]]; then
        break
    fi
    sleep 1
done
[[ $(dig +short +time=2 +tries=1 @10.44.0.10 web.empresa.test A) == 10.44.0.10 ]]
[[ $(dig +short +time=2 +tries=1 @10.44.0.10 -x 10.44.0.10) == servidor.empresa.test. ]]
dig +short @10.44.0.10 www.empresa.test CNAME
dig +short @10.44.0.10 empresa.test MX

systemctl unmask --runtime kea-dhcp4-server.service
systemctl enable kea-dhcp4-server.service
if ! systemctl restart kea-dhcp4-server.service; then
    journalctl -u kea-dhcp4-server.service -n 30 --no-pager
    exit 1
fi
systemctl is-active named.service kea-dhcp4-server.service
echo 'INFRAESTRUCTURA_4_1_LISTA'
