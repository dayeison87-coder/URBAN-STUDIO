import secrets
from datetime import timedelta

from django.utils import timezone
from analisis_ia.models import CodigoSeguridadIA
from users.email_service import send_transactional_email


def generar_codigo_seguridad(cliente, barbero):
    """
    Genera un código de seguridad de 6 dígitos para un barbero,
    válido durante 10 minutos.
    """

    # Invalidar códigos anteriores del cliente, incluso los ya validados.
    CodigoSeguridadIA.objects.filter(
        usuario=cliente,
        usado=False,
        # Tambien invalidamos codigos previamente validados.
    ).update(usado=True)

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

    # Enviar por la API HTTPS de Brevo. Render no permite SMTP saliente.
    send_transactional_email(
        recipient=barbero.email,
        subject='Código de verificación IA | Urban Studio',
        text_content=(
            f'Hola {barbero.username},\n\n'
            f'El cliente {cliente.username} solicitó acceso a IA Estilo.\n\n'
            f'Código: {codigo}\n\n'
            'Este código vence en 10 minutos.\n\n'
            'Compártelo solo si el cliente está presente contigo.'
        ),
    )
    return codigo_seguridad
