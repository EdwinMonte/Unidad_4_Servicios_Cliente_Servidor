#!/bin/bash
# Añade la reserva de Fedora y comprueba el reenviador DNS con DNSSEC activo.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Ejecuta mediante sudo.'; exit 1; }
BASE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$BASE"
log="evidencias/reserva_$(date +%Y%m%d_%H%M%S).log"
install -o edwinmonte -g "$(id -gn edwinmonte)" -m 600 /dev/null "$log"
exec > >(tee "$log") 2>&1
[[ $(cat /sys/class/net/ens37/address) == 00:0c:29:be:a2:18 ]]
ip -4 -o addr show dev ens37 | grep -F '10.44.0.10/24'
ip -4 route show default dev ens33 | grep '^default '
respaldo=$(mktemp -d /root/unidad4-reserva.XXXXXXXX)
cp -p /etc/kea/kea-dhcp4.conf /etc/bind/named.conf.options "$respaldo/"

restaurar() {
    trap - ERR
    echo 'Falló la activación. Restaurando la configuración anterior.'
    journalctl -u named.service -u kea-dhcp4-server.service -n 20 --no-pager || true
    cp -p "$respaldo/kea-dhcp4.conf" /etc/kea/kea-dhcp4.conf
    cp -p "$respaldo/named.conf.options" /etc/bind/named.conf.options
    systemctl restart named.service kea-dhcp4-server.service
    exit 1
}
trap restaurar ERR
install -o root -g _kea -m 640 config/kea-dhcp4.reserva.conf /etc/kea/kea-dhcp4.conf
runuser -u _kea -- env KEA_LOCKFILE_DIR=/run/lock/kea /usr/sbin/kea-dhcp4 -t /etc/kea/kea-dhcp4.conf
install -o root -g root -m 644 config/named.conf.options /etc/bind/named.conf.options
named-checkconf -z
systemctl restart named.service
consulta=$(dig +time=3 +tries=2 @10.44.0.10 iana.org A +noall +comments +answer)
printf '%s\n' "$consulta"
grep -Fq 'status: NOERROR' <<< "$consulta"
grep -Eq '^iana\.org\.[[:space:]].*[[:space:]]A[[:space:]]' <<< "$consulta"
systemctl restart kea-dhcp4-server.service
systemctl is-active named.service kea-dhcp4-server.service
trap - ERR
echo 'RESERVA_4_1_LISTA: 00:0c:29:19:b5:f5 -> 10.44.0.50'
