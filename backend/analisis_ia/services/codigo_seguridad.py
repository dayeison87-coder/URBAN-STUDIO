import secrets

from datetime import timedelta

from django.utils import timezone
from django.core.mail import send_mail
from django.utils.html import escape

from analisis_ia.models import CodigoSeguridadIA


def generar_codigo_seguridad(cliente, barbero):
    """
    Genera un código de seguridad de 6 dígitos para un barbero,
    válido durante 10 minutos.
    """

    # Invalidar códigos anteriores del cliente, incluyendo los ya validados.
    CodigoSeguridadIA.objects.filter(
        usuario=cliente,
        usado=False,
        validado=False
    ).update(
        usado=True
    )

    # Generar código aleatorio de 6 dígitos
    codigo = str(secrets.randbelow(900000) + 100000)

    # Fecha de expiración: 10 minutos
    expira_en = timezone.now() + timedelta(minutes=10)

    # Guardar código
    codigo_seguridad = CodigoSeguridadIA.objects.create(
        usuario=cliente,
        barbero=barbero,
        codigo=codigo,
        expira_en=expira_en
    )

    # ---------------------------------------------------------
    # DATOS DEL USUARIO
    # ---------------------------------------------------------

    nombre_usuario = escape(cliente.username)

    # ---------------------------------------------------------
    # MENSAJE DE TEXTO (RESPALDO)
    # ---------------------------------------------------------

    mensaje_texto = (
        f"Hola {barbero.username},\n\n"
        f"El cliente {cliente.username} solicitó acceso a IA Estilo.\n\n"
        f"Tu código de seguridad para utilizar el análisis con IA "
        f"de Urban Studio es:\n\n"
        f"{codigo}\n\n"
        f"Este código vence en 10 minutos.\n\n"
        f"Compártelo solo si el cliente está presente contigo.\n\n"
        f"Urban Studio\n"
        f"Barbería & Estilo"
    )

    # ---------------------------------------------------------
    # CORREO HTML
    # ---------------------------------------------------------

    mensaje_html = f"""
    <!DOCTYPE html>
    <html lang="es">

    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">

        <title>Código de seguridad - Urban Studio</title>
    </head>

    <body style="
        margin: 0;
        padding: 0;
        background-color: #111111;
        font-family: Arial, Helvetica, sans-serif;
        color: #ffffff;
    ">

        <table
            width="100%"
            cellpadding="0"
            cellspacing="0"
            border="0"
            style="background-color: #111111; padding: 35px 15px;"
        >

            <tr>

                <td align="center">

                    <!-- CONTENEDOR PRINCIPAL -->

                    <table
                        width="600"
                        cellpadding="0"
                        cellspacing="0"
                        border="0"
                        style="
                            max-width: 600px;
                            width: 100%;
                            background-color: #1b1b1b;
                            border-radius: 16px;
                            overflow: hidden;
                            border: 1px solid #333333;
                        "
                    >

                        <!-- ENCABEZADO -->

                        <tr>

                            <td
                                align="center"
                                style="
                                    padding: 35px 25px;
                                    background-color: #0d0d0d;
                                    border-bottom: 1px solid #333333;
                                "
                            >

                                <div style="
                                    font-size: 38px;
                                    margin-bottom: 8px;
                                ">
                                    ✂
                                </div>

                                <div style="
                                    font-size: 28px;
                                    font-weight: bold;
                                    letter-spacing: 3px;
                                    color: #d4af37;
                                ">
                                    URBAN STUDIO
                                </div>

                                <div style="
                                    margin-top: 8px;
                                    font-size: 12px;
                                    letter-spacing: 3px;
                                    color: #aaaaaa;
                                ">
                                    BARBERÍA · ESTILO · CUIDADO
                                </div>

                            </td>

                        </tr>


                        <!-- CONTENIDO -->

                        <tr>

                            <td style="
                                padding: 40px 35px;
                            ">

                                <div style="
                                    font-size: 24px;
                                    font-weight: bold;
                                    color: #ffffff;
                                    margin-bottom: 15px;
                                ">
                                    Hola {nombre_usuario} 👋
                                </div>

                                <div style="
                                    font-size: 15px;
                                    line-height: 1.7;
                                    color: #cccccc;
                                    margin-bottom: 30px;
                                ">
                                    Hemos recibido una solicitud para utilizar
                                    el análisis con Inteligencia Artificial
                                    de <strong style="color: #d4af37;">
                                    Urban Studio</strong>.
                                </div>


                                <!-- TARJETA DEL CÓDIGO -->

                                <table
                                    width="100%"
                                    cellpadding="0"
                                    cellspacing="0"
                                    border="0"
                                    style="
                                        background-color: #111111;
                                        border: 1px solid #3a3a3a;
                                        border-radius: 12px;
                                    "
                                >

                                    <tr>

                                        <td
                                            align="center"
                                            style="padding: 28px 20px;"
                                        >

                                            <div style="
                                                font-size: 12px;
                                                color: #999999;
                                                letter-spacing: 2px;
                                                margin-bottom: 15px;
                                            ">
                                                CÓDIGO DE SEGURIDAD
                                            </div>

                                            <div style="
                                                font-size: 38px;
                                                font-weight: bold;
                                                letter-spacing: 10px;
                                                color: #d4af37;
                                                margin-left: 10px;
                                            ">
                                                {codigo}
                                            </div>

                                            <div style="
                                                margin-top: 18px;
                                                font-size: 13px;
                                                color: #aaaaaa;
                                            ">
                                                Este código vence en
                                                <strong style="color: #ffffff;">
                                                    10 minutos
                                                </strong>.
                                            </div>

                                        </td>

                                    </tr>

                                </table>


                                <!-- ADVERTENCIA -->

                                <table
                                    width="100%"
                                    cellpadding="0"
                                    cellspacing="0"
                                    border="0"
                                    style="
                                        margin-top: 25px;
                                        background-color: #241f12;
                                        border-left: 4px solid #d4af37;
                                    "
                                >

                                    <tr>

                                        <td style="
                                            padding: 15px 18px;
                                            font-size: 13px;
                                            line-height: 1.6;
                                            color: #cccccc;
                                        ">

                                            <strong style="color: #d4af37;">
                                                🔒 Importante
                                            </strong>
                                            <br>

                                            No compartas este código con
                                            ninguna persona. Urban Studio
                                            nunca te solicitará que envíes
                                            este código por otros medios.

                                        </td>

                                    </tr>

                                </table>


                                <div style="
                                    margin-top: 30px;
                                    font-size: 14px;
                                    line-height: 1.6;
                                    color: #999999;
                                ">
                                    Si tú no solicitaste este código,
                                    puedes ignorar este mensaje.
                                </div>

                            </td>

                        </tr>


                        <!-- PIE DE PÁGINA -->

                        <tr>

                            <td
                                align="center"
                                style="
                                    padding: 25px;
                                    background-color: #0d0d0d;
                                    border-top: 1px solid #333333;
                                "
                            >

                                <div style="
                                    font-size: 16px;
                                    font-weight: bold;
                                    color: #d4af37;
                                    letter-spacing: 2px;
                                ">
                                    URBAN STUDIO
                                </div>

                                <div style="
                                    margin-top: 8px;
                                    font-size: 12px;
                                    color: #777777;
                                ">
                                    Barbería & Estilo
                                </div>

                                <div style="
                                    margin-top: 15px;
                                    font-size: 11px;
                                    color: #555555;
                                ">
                                    © 2026 Urban Studio · Todos los derechos reservados
                                </div>

                            </td>

                        </tr>

                    </table>

                </td>

            </tr>

        </table>

    </body>

    </html>
    """

    # ---------------------------------------------------------
    # ENVIAR CORREO
    # ---------------------------------------------------------

    send_mail(
        subject="Código de verificación IA - Urban Studio",
        message=mensaje_texto,
        from_email=None,
        recipient_list=[barbero.email],
        fail_silently=False,
        html_message=mensaje_html,
    )

    return codigo_seguridad