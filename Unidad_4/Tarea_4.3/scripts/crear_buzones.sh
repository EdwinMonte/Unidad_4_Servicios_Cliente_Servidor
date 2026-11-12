#!/bin/bash
# Crea las cuentas locales de correo y sus directorios Maildir.
set -euo pipefail
umask 077
[[ $EUID == 0 ]] || { echo 'Ejecuta mediante sudo.'; exit 1; }
getent group u4correo >/dev/null || groupadd u4correo
install -d -m 700 /root/unidad4/correo
for usuario in correo1 correo2; do
    if ! getent passwd "$usuario" >/dev/null; then
        useradd -m -d "/home/$usuario" -s /usr/sbin/nologin -g u4correo "$usuario"
    fi
    [[ $(id -gn "$usuario") == u4correo ]]
    [[ $(getent passwd "$usuario" | cut -d: -f6) == "/home/$usuario" ]]
    [[ $(getent passwd "$usuario" | cut -d: -f7) == /usr/sbin/nologin ]]
    chmod 700 "/home/$usuario"
    install -d -o "$usuario" -g u4correo -m 700 "/home/$usuario/Maildir"
    install -d -o "$usuario" -g u4correo -m 700 "/home/$usuario/Maildir/"{cur,new,tmp}
    archivo_clave="/root/unidad4/correo/$usuario.pass"
    if [[ ! -s $archivo_clave ]]; then
        openssl rand -hex 16 > "$archivo_clave"
    fi
    printf '%s:%s\n' "$usuario" "$(cat "$archivo_clave")" | chpasswd
    echo "Buzón preparado: $usuario@empresa.test"
done
