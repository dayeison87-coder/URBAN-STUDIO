import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from django.conf import settings


class BrevoEmailError(Exception):
    """Raised when Brevo rejects or cannot receive an email request."""


def send_registration_code(recipient, code):
    if not settings.BREVO_API_KEY or not settings.BREVO_SENDER_EMAIL:
        raise BrevoEmailError('Brevo no está configurado correctamente.')

    payload = {
        'sender': {
            'email': settings.BREVO_SENDER_EMAIL,
            'name': settings.BREVO_SENDER_NAME,
        },
        'to': [{'email': recipient}],
        'subject': 'Código de verificación | Urban Studio',
        'textContent': (
            f'Tu código de verificación es: {code}. '
            'Válido durante 10 minutos.'
        ),
    }
    request = Request(
        'https://api.brevo.com/v3/smtp/email',
        data=json.dumps(payload).encode('utf-8'),
        headers={
            'accept': 'application/json',
            'api-key': settings.BREVO_API_KEY,
            'content-type': 'application/json',
        },
        method='POST',
    )

    try:
        with urlopen(request, timeout=settings.BREVO_TIMEOUT) as response:
            if response.status < 200 or response.status >= 300:
                raise BrevoEmailError(
                    f'Brevo respondió con estado HTTP {response.status}.'
                )
    except HTTPError as error:
        raise BrevoEmailError(
            f'Brevo rechazó el envío con estado HTTP {error.code}.'
        ) from error
    except (TimeoutError, URLError, OSError) as error:
        raise BrevoEmailError('No se pudo conectar con Brevo.') from error
