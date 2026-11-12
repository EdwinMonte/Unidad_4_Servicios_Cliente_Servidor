# Tarea 4.3 · Correo interno

Postfix y Dovecot atienden mail.empresa.test en el segmento U4_LAB.
Ver docs/Reporte_Tarea_4_3.pdf para la topología, los resultados y la configuración.

- config contiene main.cf, master.cf, dovecot.conf, los mapas locales y la zona con SPF.
- scripts/crear_buzones.sh configura Maildir y la propiedad de sus directorios.
- scripts/cliente_correo.py envía por SMTP 587 con STARTTLS y lee por IMAPS 993.
- evidencias/mail.log y el registro del cliente conservan la trazabilidad del mismo mensaje.

La instalación requiere DHCP y DNS de la 4.1 y la CA de la 4.2.
Usar sudo bash scripts/instalar_4_3.sh. Para un nuevo ensayo, usar sudo bash scripts/probar_correo.sh.
Los certificados incluidos son públicos. Las contraseñas y llaves privadas permanecen en Ubuntu.
