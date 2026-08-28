import secrets
from datetime import timedelta

from django.utils import timezone
from django.core.mail import send_mail

from analisis_ia.models import CodigoSeguridadIA


def generar_codigo_seguridad(usuario):
    """
    Genera un código de seguridad de 6 dígitos,
    válido durante 4 minutos.
    """

    # Invalidar códigos anteriores del usuario
    CodigoSeguridadIA.objects.filter(
        usuario=usuario,
        usado=False,
        validado=False
    ).update(usado=True)

    # Generar código aleatorio de 6 dígitos
    codigo = str(secrets.randbelow(900000) + 100000)

    # Fecha de expiración: 4 minutos
    expira_en = timezone.now() + timedelta(minutes=4)

    # Guardar código
    codigo_seguridad = CodigoSeguridadIA.objects.create(
        usuario=usuario,
        codigo=codigo,
        expira_en=expira_en
    )

    # Enviar correo
    send_mail(
        subject="Código de seguridad - Urban Studio",
        message=(
            f"Hola {usuario.username},\n\n"
            f"Tu código de seguridad para utilizar el análisis con IA es:\n\n"
            f"{codigo}\n\n"
            f"Este código vence en 4 minutos.\n\n"
            f"No compartas este código con nadie."
        ),
        from_email=None,
        recipient_list=[usuario.email],
        fail_silently=False,
    )

    return codigo_seguridad