# Tarea 4.1 · DHCP y DNS

Ubuntu Server aloja Kea y BIND9. Fedora Server es el cliente en U4_LAB.
Consulte docs/Memoria_Tarea_4_1.pdf para el plan de red, las pruebas y el procedimiento.

- config/kea-dhcp4.conf configura la fase dinámica.
- config/kea-dhcp4.reserva.conf configura la fase final con reserva por MAC.
- config/dhcpd.conf es una equivalencia de referencia para ISC DHCP, sin ensayo de ejecución.
- config/named.conf y los archivos incluidos documentan BIND9.
- evidencias contiene capturas de Fedora, registros de Kea y consultas dig desde Ubuntu.

Ejecute scripts/instalar_4_1.sh únicamente en el servidor del laboratorio previsto.
Reproduzca primero la asignación dinámica y después ejecute scripts/aplicar_reserva_4_1.sh.
Los scripts requieren sudo. Compruebe que ens37 pertenezca a U4_LAB antes de activar Kea.
