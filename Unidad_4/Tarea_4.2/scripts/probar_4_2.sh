#!/bin/bash
# Prueba HTTPS, MariaDB, FTPS y SFTP desde Ubuntu.
set -euo pipefail
umask 077
export LC_ALL=C
[[ $EUID == 0 ]] || { echo 'Ejecuta mediante sudo.'; exit 1; }
BASE=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$BASE"
grupo_admin=$(id -gn edwinmonte)
log="evidencias/pruebas_$(date +%Y%m%d_%H%M%S).log"
install -o edwinmonte -g "$grupo_admin" -m 600 /dev/null "$log"
exec > >(tee "$log") 2>&1
prueba=$(mktemp -d /root/unidad4/prueba.XXXXXXXX)
llaves=/run/unidad4-transfer-test
mkdir -m 755 "$llaves"
limpiar() {
    rm -f "$llaves/archivo1" "$llaves/archivo2"
    rmdir "$llaves"
    rm -f "$prueba/"*
    rmdir "$prueba"
}
trap limpiar EXIT
CA=/etc/unidad4/pki/ca.crt

echo 'PRUEBA HTTPS Y MARIADB'
curl --noproxy '*' -fsSI --resolve web.empresa.test:80:10.44.0.10 http://web.empresa.test/
openssl s_client -connect 10.44.0.10:443 -servername web.empresa.test \
    -CAfile "$CA" -verify_hostname web.empresa.test -verify_return_error -brief </dev/null
curl --noproxy '*' -fsS --cacert "$CA" --resolve web.empresa.test:443:10.44.0.10 \
    https://web.empresa.test/ -o "$prueba/web.html"
grep -F 'MariaDB OK - registro consultado por PHP' "$prueba/web.html"
install -o edwinmonte -g "$grupo_admin" -m 644 "$prueba/web.html" evidencias/respuesta_https.html

printf '%s\n' 'Transferencia cifrada Unidad 4.2' > "$prueba/original.txt"
probar_ftps() {
echo 'PRUEBA FTPS'
printf 'machine 10.44.0.10 login archivo1 password %s\n' \
    "$(cat /root/unidad4/transferencia/archivo1.pass)" > "$prueba/ftps.netrc"
opciones_ftps=(--noproxy '*' -fsS --max-time 30 --ssl-reqd --tlsv1.2 --tls-max 1.2 --cacert "$CA")
if ! curl "${opciones_ftps[@]}" --netrc-file "$prueba/ftps.netrc" -v \
    -T "$prueba/original.txt" ftp://10.44.0.10/datos/prueba-ftps.txt 2> "$prueba/ftps-traza.log"; then
    sed -E 's/^(> PASS ).*/\1[oculta]/I' "$prueba/ftps-traza.log"
    tail -n 12 /var/log/vsftpd.log
    return 1
fi
curl "${opciones_ftps[@]}" --netrc-file "$prueba/ftps.netrc" \
    ftp://10.44.0.10/datos/prueba-ftps.txt -o "$prueba/ftps-descarga.txt"
cmp "$prueba/original.txt" "$prueba/ftps-descarga.txt"
echo 'FTPS: subida y descarga idénticas.'
if curl "${opciones_ftps[@]}" --user 'anonymous:prueba' ftp://10.44.0.10/ > "$prueba/anonimo.txt" 2>&1; then
    echo 'ERROR: FTPS aceptó el acceso anónimo.'; exit 1
fi
cat "$prueba/anonimo.txt"
grep -q '(67)' "$prueba/anonimo.txt"
echo 'FTPS: acceso anónimo rechazado.'
}

echo 'PRUEBA SFTP Y CHROOT'
ssh-keygen -q -t ed25519 -N '' -f "$prueba/id"
install -m 644 "$prueba/id.pub" "$llaves/archivo1"
install -m 644 "$prueba/id.pub" "$llaves/archivo2"
printf '[10.44.0.10]:2222 %s\n' "$(cut -d' ' -f1,2 /etc/ssh/ssh_host_ed25519_key.pub)" > "$prueba/known_hosts"
sftp_args=(-P 2222 -i "$prueba/id" -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$prueba/known_hosts" -o ConnectTimeout=5)
cat > "$prueba/archivo1.batch" <<BATCH
put $prueba/original.txt /datos/solo-archivo1.txt
get /datos/solo-archivo1.txt $prueba/sftp-descarga.txt
cd /
cd ..
pwd
BATCH
sftp "${sftp_args[@]}" -b "$prueba/archivo1.batch" archivo1@10.44.0.10 | tee "$prueba/sftp1.log"
cmp "$prueba/original.txt" "$prueba/sftp-descarga.txt"
grep -Fxq 'Remote working directory: /' "$prueba/sftp1.log"
echo 'SFTP: subida y descarga idénticas. cd .. permanece en la raíz de la jaula.'

printf 'pwd\n' > "$prueba/archivo2.batch"
sftp "${sftp_args[@]}" -b "$prueba/archivo2.batch" archivo2@10.44.0.10
printf 'get /datos/solo-archivo1.txt %s\n' "$prueba/ajeno.txt" > "$prueba/ajeno.batch"
if sftp "${sftp_args[@]}" -b "$prueba/ajeno.batch" archivo2@10.44.0.10 > "$prueba/rechazo.log" 2>&1; then
    echo 'ERROR: archivo2 pudo leer el archivo de archivo1.'; exit 1
fi
cat "$prueba/rechazo.log"
grep -Ei 'No such file|not found' "$prueba/rechazo.log"
echo 'SFTP: archivo2 no ve el archivo de archivo1.'
probar_ftps
echo 'PRUEBAS_SERVIDOR_4_2_VERIFICADAS'
