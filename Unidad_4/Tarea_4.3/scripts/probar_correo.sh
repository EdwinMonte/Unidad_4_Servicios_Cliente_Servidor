#!/bin/bash
# Comprueba nombre TLS, entrega LMTP y lectura IMAPS del mismo mensaje.
set -euo pipefail
umask 077
[[ $EUID == 0 ]] || { echo 'Ejecuta mediante sudo.'; exit 1; }
BASE=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$BASE"
grupo_admin=$(id -gn edwinmonte)
log="evidencias/prueba_correo_$(date +%Y%m%d_%H%M%S).log"
install -o edwinmonte -g "$grupo_admin" -m 600 /dev/null "$log"
exec > >(tee "$log") 2>&1
ca=/etc/unidad4/pki/ca.crt
echo 'DNS DE CORREO'
dig +noall +answer @10.44.0.10 mail.empresa.test A
dig +noall +answer @10.44.0.10 empresa.test MX
dig +noall +answer @10.44.0.10 empresa.test TXT
echo 'NOMBRE DEL CERTIFICADO SMTP'
timeout 12 openssl s_client -starttls smtp -connect 10.44.0.10:587 \
    -servername mail.empresa.test -verify_hostname mail.empresa.test \
    -verify_return_error -CAfile "$ca" -brief </dev/null
echo 'NOMBRE DEL CERTIFICADO IMAPS'
timeout 12 openssl s_client -connect 10.44.0.10:993 \
    -servername mail.empresa.test -verify_hostname mail.empresa.test \
    -verify_return_error -CAfile "$ca" -brief </dev/null
transaccion="evidencias/cliente_ubuntu_$(date +%Y%m%d_%H%M%S).log"
install -o edwinmonte -g "$grupo_admin" -m 600 /dev/null "$transaccion"
python3 scripts/cliente_correo.py --servidor 10.44.0.10 --ca "$ca" --claves /root/unidad4/correo | tee "$transaccion"
cola=$(awk -F= '/^QUEUE_ID=/ {print $2}' "$transaccion")
[[ $cola =~ ^[A-Za-z0-9]+$ ]]
for intento in {1..5}; do
    if grep -F "$cola:" /var/log/mail.log | grep -F 'status=sent' >/dev/null; then
        break
    fi
    sleep 1
done
grep -F "$cola:" /var/log/mail.log > evidencias/mail.log
grep -F 'status=sent' evidencias/mail.log
chown edwinmonte:"$grupo_admin" evidencias/mail.log
echo 'ENTREGA_CORREO_4_3_VERIFICADA'
