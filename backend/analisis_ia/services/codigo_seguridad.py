import secrets
from datetime import timedelta

from django.utils import timezone
from django.core.mail import send_mail

from analisis_ia.models import CodigoSeguridadIA


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

    # Enviar correo
    send_mail(
    subject="Código de verificación IA - Urban Studio",
    message=(
        f"Hola {barbero.username},\n\n"
        f"El cliente {cliente.username} solicitó acceso a IA Estilo.\n\n"
        f"{codigo}\n\n"
        f"Este código vence en 10 minutos.\n\n"
        f"Compártelo solo si el cliente está presente contigo."
    ),
    from_email=None,
    recipient_list=[barbero.email],
    fail_silently=False,
)

    return codigo_seguridad
