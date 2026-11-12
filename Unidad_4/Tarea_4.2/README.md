# Tarea 4.2 · HTTPS, FTPS y SFTP

El reporte técnico está en docs/Reporte_Tarea_4_2.pdf.

- Servidor 10.44.0.10, dominio web.empresa.test, segmento U4_LAB.
- Nginx sirve index.php con PHP-FPM y MariaDB mediante socket local.
- vsftpd ofrece FTPS explícito, sin acceso anónimo y con chroot.
- OpenSSH ofrece SFTP en 2222, con una jaula distinta por cuenta.
- La captura de Fedora comprueba HTTPS. Los logs de Ubuntu comprueban FTPS, SFTP y aislamiento.

Instalar en el servidor del laboratorio con sudo bash scripts/instalar_4_2.sh.
La instalación requiere la red y los servicios de la tarea 4.1.
Para repetir las pruebas del servidor, usar sudo bash scripts/probar_4_2.sh.
El ensayo final consta en evidencias/pruebas_20261112_170033.log.
El certificado u4-ca.crt es público. Las llaves privadas y credenciales permanecen en el servidor.
