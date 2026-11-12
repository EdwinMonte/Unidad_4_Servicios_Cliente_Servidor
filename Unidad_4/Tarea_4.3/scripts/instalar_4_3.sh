#!/bin/bash
# Instala correo interno de laboratorio con Postfix y Dovecot 2.4.
set -euo pipefail
umask 077
[[ $EUID == 0 ]] || { echo 'Ejecuta mediante sudo.'; exit 1; }
BASE=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$BASE"
grupo_admin=$(id -gn edwinmonte)
install -d -o edwinmonte -g "$grupo_admin" -m 750 evidencias
log="evidencias/instalacion_$(date +%Y%m%d_%H%M%S).log"
install -o edwinmonte -g "$grupo_admin" -m 600 /dev/null "$log"
exec > >(tee "$log") 2>&1
ip -4 -o addr show dev ens37 | grep -F '10.44.0.10/24'
systemctl is-active named.service
pki=/etc/unidad4/pki
test -s "$pki/ca.key"
test -s "$pki/ca.crt"

export DEBIAN_FRONTEND=noninteractive
systemctl mask --runtime postfix.service postfix@-.service dovecot.service
printf '%s\n' 'postfix postfix/main_mailer_type select Local only' \
    'postfix postfix/mailname string empresa.test' | debconf-set-selections
apt-get update
apt-get install -y postfix dovecot-core dovecot-imapd dovecot-lmtpd
postconf mail_version
dovecot --version

echo 'CERTIFICADO DE CORREO'
openssl req -new -newkey rsa:2048 -nodes -sha256 -subj '/CN=mail.empresa.test' \
    -keyout /etc/ssl/private/u4-mail.key -out "$pki/mail.csr"
chmod 600 /etc/ssl/private/u4-mail.key
openssl x509 -req -sha256 -days 365 -in "$pki/mail.csr" \
    -CA "$pki/ca.crt" -CAkey "$pki/ca.key" -CAcreateserial \
    -extfile config/mail.ext -out /etc/ssl/certs/u4-mail.crt
chmod 644 /etc/ssl/certs/u4-mail.crt
openssl verify -CAfile "$pki/ca.crt" -verify_hostname mail.empresa.test /etc/ssl/certs/u4-mail.crt
install -o edwinmonte -g "$grupo_admin" -m 644 "$pki/ca.crt" config/u4-ca.crt
install -o edwinmonte -g "$grupo_admin" -m 644 /etc/ssl/certs/u4-mail.crt config/mail.crt

echo 'BUZONES Y PAM'
bash scripts/crear_buzones.sh
install -m 644 config/dovecot-u4.pam /etc/pam.d/dovecot-u4
printf '%s\n' 'DenyGroups u4correo' > /etc/ssh/sshd_config.d/00-unidad4-correo.conf
chmod 644 /etc/ssh/sshd_config.d/00-unidad4-correo.conf
/usr/sbin/sshd -t
if systemctl is-active --quiet ssh.service; then
    systemctl reload ssh.service
fi

echo 'CONFIGURACION POSTFIX Y DOVECOT'
respaldo=$(mktemp -d /root/unidad4/correo-config.XXXXXXXX)
cp -p /etc/postfix/main.cf /etc/postfix/master.cf /etc/dovecot/dovecot.conf /etc/bind/db.empresa.test "$respaldo/"
echo "Configuración anterior: $respaldo"
install -m 644 config/main.cf /etc/postfix/main.cf
install -m 644 config/recipients /etc/postfix/recipients_u4
install -m 644 config/sender_login /etc/postfix/sender_login_u4
printf '%s\n' 'postmaster@empresa.test correo1@empresa.test' \
    'postmaster@mail.empresa.test correo1@empresa.test' > /etc/postfix/aliases_u4
chmod 644 /etc/postfix/aliases_u4
postconf -M 'smtp/inet=smtp inet n - n - - smtpd'
postconf -M 'submission/inet=submission inet n - n - - smtpd'
postconf -M 'postlog/unix-dgram=postlog unix-dgram n - n - 1 postlogd'
postconf -P 'submission/inet/smtpd_sasl_auth_enable=yes'
postconf -P 'submission/inet/smtpd_recipient_restrictions=permit_sasl_authenticated,reject'
postconf -P 'submission/inet/smtpd_sender_restrictions=reject_sender_login_mismatch'
install -m 644 config/dovecot.conf /etc/dovecot/dovecot.conf
doveconf -n
postfix check

echo 'REGISTROS DNS DE CORREO'
named-checkzone empresa.test config/db.empresa.test.correo
install -m 644 config/db.empresa.test.correo /etc/bind/db.empresa.test
rndc reload empresa.test
dig +short @10.44.0.10 mail.empresa.test A
dig +short @10.44.0.10 empresa.test MX
dig +short @10.44.0.10 empresa.test TXT

systemctl unmask --runtime postfix.service postfix@-.service dovecot.service
systemctl enable --now dovecot.service
systemctl restart dovecot.service
systemctl enable --now postfix.service
systemctl restart postfix.service
systemctl is-active dovecot.service postfix.service
postfix status
install -o edwinmonte -g "$grupo_admin" -m 644 /etc/postfix/master.cf config/master.cf
echo 'INSTALACION_4_3_LISTA'
bash "$BASE/scripts/probar_correo.sh"
