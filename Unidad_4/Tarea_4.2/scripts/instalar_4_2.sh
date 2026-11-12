#!/bin/bash
# Configura servicios web y transferencia en U4_LAB.
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
systemctl is-active named.service kea-dhcp4-server.service

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y nginx php-fpm php-cli php-mysql mariadb-server vsftpd curl openssl
version=$(php -r 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION;')
php_service="php$version-fpm.service"
php_socket="/run/php/php$version-fpm.sock"

echo 'CERTIFICADOS DEL LABORATORIO'
install -d -o root -g www-data -m 750 /etc/unidad4
install -d -m 700 /etc/unidad4/pki /root/unidad4/transferencia
pki=/etc/unidad4/pki
if [[ ! -e $pki/ca.key && ! -e $pki/ca.crt ]]; then
    openssl req -x509 -newkey rsa:3072 -nodes -sha256 -days 3650 \
        -subj '/CN=Unidad 4 Lab CA' \
        -addext 'basicConstraints=critical,CA:TRUE,pathlen:0' \
        -addext 'keyUsage=critical,keyCertSign,cRLSign' \
        -keyout "$pki/ca.key" -out "$pki/ca.crt"
fi
test -s "$pki/ca.key"
test -s "$pki/ca.crt"
openssl req -new -newkey rsa:2048 -nodes -sha256 \
    -subj '/CN=web.empresa.test' -keyout "$pki/web.key" -out "$pki/web.csr"
openssl x509 -req -sha256 -days 365 -in "$pki/web.csr" \
    -CA "$pki/ca.crt" -CAkey "$pki/ca.key" -CAcreateserial \
    -extfile config/web.ext -out "$pki/web.crt"
openssl verify -CAfile "$pki/ca.crt" -verify_hostname web.empresa.test "$pki/web.crt"
install -o edwinmonte -g "$grupo_admin" -m 644 "$pki/ca.crt" config/u4-ca.crt

echo 'MARIADB Y PHP'
printf '%s\n' '[mariadbd]' 'skip-networking' > /etc/mysql/mariadb.conf.d/90-unidad4.cnf
chmod 644 /etc/mysql/mariadb.conf.d/90-unidad4.cnf
systemctl restart mariadb.service
clave_bd=$(openssl rand -hex 24)
mariadb <<SQL
CREATE DATABASE IF NOT EXISTS unidad4 CHARACTER SET utf8mb4;
CREATE TABLE IF NOT EXISTS unidad4.verificacion (id INT PRIMARY KEY, mensaje VARCHAR(200) NOT NULL);
INSERT INTO unidad4.verificacion VALUES (1, 'MariaDB OK - registro consultado por PHP')
ON DUPLICATE KEY UPDATE mensaje = VALUES(mensaje);
CREATE USER IF NOT EXISTS 'u4web'@'localhost';
ALTER USER 'u4web'@'localhost' IDENTIFIED BY '$clave_bd';
GRANT SELECT ON unidad4.verificacion TO 'u4web'@'localhost';
SQL
cat > /etc/unidad4/db.php <<PHP
<?php
return [
    'dsn' => 'mysql:unix_socket=/run/mysqld/mysqld.sock;dbname=unidad4;charset=utf8mb4',
    'user' => 'u4web',
    'password' => '$clave_bd',
];
PHP
unset clave_bd
chown root:www-data /etc/unidad4/db.php
chmod 640 /etc/unidad4/db.php
systemctl enable --now "$php_service"
test -S "$php_socket"
install -d -m 755 /var/www/unidad4
install -m 644 config/index.php /var/www/unidad4/index.php
php -l /var/www/unidad4/index.php

echo 'VIRTUAL HOST HTTPS'
sed "s|__PHP_SOCKET__|$php_socket|" config/web.empresa.test.conf > /etc/nginx/sites-available/unidad4
chmod 644 /etc/nginx/sites-available/unidad4
if [[ -L /etc/nginx/sites-enabled/default && $(readlink -f /etc/nginx/sites-enabled/default) == /etc/nginx/sites-available/default ]]; then
    unlink /etc/nginx/sites-enabled/default
fi
ln -sfn /etc/nginx/sites-available/unidad4 /etc/nginx/sites-enabled/unidad4
nginx -t
systemctl restart nginx.service
install -o edwinmonte -g "$grupo_admin" -m 644 /etc/nginx/sites-available/unidad4 config/web.aplicado.conf

echo 'USUARIOS Y SERVICIOS DE TRANSFERENCIA'
getent group u4transfer >/dev/null || groupadd u4transfer
install -d -m 755 /srv/u4transfer /etc/ssh/u4-transfer-keys /run/vsftpd/empty
for usuario in archivo1 archivo2; do
    if ! getent passwd "$usuario" >/dev/null; then
        useradd -M -d "/srv/u4transfer/$usuario" -s /usr/sbin/nologin -g u4transfer "$usuario"
    fi
    [[ $(id -gn "$usuario") == u4transfer ]]
    [[ $(getent passwd "$usuario" | cut -d: -f7) == /usr/sbin/nologin ]]
    archivo_clave="/root/unidad4/transferencia/$usuario.pass"
    if [[ ! -s $archivo_clave ]]; then
        openssl rand -hex 16 > "$archivo_clave"
    fi
    printf '%s:%s\n' "$usuario" "$(cat "$archivo_clave")" | chpasswd
    install -d -o root -g root -m 755 "/srv/u4transfer/$usuario"
    install -d -o "$usuario" -g u4transfer -m 700 "/srv/u4transfer/$usuario/datos"
done
printf '%s\n' archivo1 archivo2 > /etc/vsftpd-u4.users
chmod 644 /etc/vsftpd-u4.users
install -m 644 config/vsftpd-u4.pam /etc/pam.d/vsftpd-u4
if [[ ! -e /root/unidad4/vsftpd.conf.anterior ]]; then
    cp -p /etc/vsftpd.conf /root/unidad4/vsftpd.conf.anterior
fi
install -m 644 config/vsftpd.conf /etc/vsftpd.conf
systemctl enable vsftpd.service
systemctl restart vsftpd.service

install -m 644 config/sshd_config_u4 /etc/ssh/sshd_config_u4
install -m 644 config/ssh-u4-sftp.service /etc/systemd/system/ssh-u4-sftp.service
/usr/sbin/sshd -t -f /etc/ssh/sshd_config_u4
printf '%s\n' 'DenyGroups u4transfer' > /etc/ssh/sshd_config.d/00-unidad4-transfer.conf
chmod 644 /etc/ssh/sshd_config.d/00-unidad4-transfer.conf
/usr/sbin/sshd -t
systemctl reload ssh.service
systemctl daemon-reload
systemctl enable --now ssh-u4-sftp.service
systemctl is-active nginx.service "$php_service" mariadb.service vsftpd.service ssh-u4-sftp.service
echo 'INSTALACION_4_2_LISTA'
bash "$BASE/scripts/probar_4_2.sh"
