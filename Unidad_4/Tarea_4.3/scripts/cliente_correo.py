"""Cliente de prueba SMTP autenticado e IMAPS para U4_LAB."""

import argparse
from datetime import datetime, timezone
from email import policy
from email.message import EmailMessage
from email.parser import BytesParser
from email.utils import format_datetime, make_msgid
from getpass import getpass
import imaplib
from pathlib import Path
import re
import smtplib
import ssl
import time


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--servidor", default="mail.empresa.test")
    parser.add_argument("--ca", type=Path, default=Path.home() / "u4-ca.crt")
    parser.add_argument("--claves", type=Path, help="Directorio privado de claves para pruebas del servidor")
    args = parser.parse_args()
    context = ssl.create_default_context(cafile=str(args.ca))
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    passwords = {}
    for user in ("correo1", "correo2"):
        if args.claves:
            passwords[user] = (args.claves / f"{user}.pass").read_text().strip()
        else:
            passwords[user] = getpass(f"Contraseña de {user}: ")

    sender = "correo1@empresa.test"
    recipient = "correo2@empresa.test"
    content = "Mensaje de prueba recibido y verificado en la Unidad 4.3."
    message = EmailMessage(policy=policy.SMTP)
    now = datetime.now(timezone.utc)
    message["From"] = sender
    message["To"] = recipient
    message["Subject"] = f"Prueba Unidad 4.3 {now.isoformat(timespec='seconds')}"
    message["Date"] = format_datetime(now)
    message["Message-ID"] = make_msgid(domain="empresa.test")
    message.set_content(content)

    with smtplib.SMTP(args.servidor, 587, timeout=10) as smtp:
        smtp.ehlo()
        smtp.starttls(context=context)
        smtp.ehlo()
        print(f"SMTP 587: certificado verificado, {smtp.sock.version()}", flush=True)
        auth_code, _ = smtp.login("correo1", passwords["correo1"])
        require(auth_code == 235, "Postfix no confirmó la autenticación")
        print("SMTP: correo1 autenticado (235)", flush=True)
        code, detail = smtp.mail(sender)
        require(code == 250, f"MAIL FROM rechazado: {code} {detail!r}")
        code, detail = smtp.rcpt("prueba-externa@example.net")
        require(500 <= code <= 599, f"El servidor no rechazó el destinatario externo: {code}")
        print(f"Relay externo rechazado en RCPT: {code} {detail.decode(errors='replace')}", flush=True)
        smtp.rset()
        code, detail = smtp.mail(sender)
        require(code == 250, f"MAIL FROM rechazado: {code} {detail!r}")
        code, detail = smtp.rcpt(recipient)
        require(code == 250, f"Destinatario interno rechazado: {code} {detail!r}")
        code, detail = smtp.data(message.as_bytes())
        require(code == 250, f"El mensaje no se aceptó: {code} {detail!r}")
        response = detail.decode(errors="replace")
        print(f"SMTP: {code} {response}", flush=True)
        queued = re.search(r"queued as ([A-Za-z0-9]+)", response)
        require(queued is not None, "Postfix no devolvió el identificador de cola")
        print(f"QUEUE_ID={queued.group(1)}", flush=True)

    with imaplib.IMAP4_SSL(args.servidor, 993, ssl_context=context, timeout=10) as imap:
        print(f"IMAPS 993: certificado verificado, {imap.sock.version()}", flush=True)
        imap.login("correo2", passwords["correo2"])
        for _ in range(10):
            status, detail = imap.select("INBOX", readonly=True)
            require(status == "OK", f"Dovecot no pudo abrir INBOX: {detail!r}")
            status, data = imap.search(None, "HEADER", "Message-ID", f'"{message["Message-ID"]}"')
            if status == "OK" and data[0]:
                break
            time.sleep(1)
        else:
            raise RuntimeError("El mensaje no apareció en la bandeja de correo2")
        status, response = imap.fetch(data[0].split()[-1], "(BODY.PEEK[])")
        require(status == "OK", "Falló la lectura del mensaje")
        payload = next(item[1] for item in response if isinstance(item, tuple))
        received = BytesParser(policy=policy.default).parsebytes(payload)
        require(str(received["Message-ID"]) == str(message["Message-ID"]), "Message-ID inesperado")
        require(received["From"].addresses[0].addr_spec == sender, "Remitente inesperado")
        require(received["To"].addresses[0].addr_spec == recipient, "Destinatario inesperado")
        require(received.get_content().strip() == content, "El cuerpo recibido no coincide")
        print("Mensaje recibido en INBOX de correo2")
        for field in ("From", "To", "Subject", "Message-ID"):
            print(f"{field}: {received[field]}")
        print(received.get_content().strip())
    print("SMTP_IMAPS_VERIFICADOS")


if __name__ == "__main__":
    run()
