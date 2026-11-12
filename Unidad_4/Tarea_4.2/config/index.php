<?php
declare(strict_types=1);

try {
    $settings = require '/etc/unidad4/db.php';
    $database = new PDO($settings['dsn'], $settings['user'], $settings['password']);
    $message = $database->query('SELECT mensaje FROM verificacion WHERE id = 1')->fetchColumn();
    if (!is_string($message)) {
        throw new RuntimeException('Registro de prueba ausente');
    }
} catch (Throwable $error) {
    http_response_code(503);
    exit('La consulta a la base de datos no está disponible.');
}
?>
<!doctype html>
<html lang="es">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Unidad 4.2 | Servicios web</title>
<main>
    <h1>Unidad 4.2</h1>
    <p>Nginx sirve esta página por HTTPS. PHP consulta el registro en MariaDB.</p>
    <p><strong><?= htmlspecialchars($message, ENT_QUOTES, 'UTF-8') ?></strong></p>
</main>
</html>
