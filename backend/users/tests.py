from unittest.mock import patch

from django.test import TestCase
from rest_framework.test import APIClient

from .email_service import BrevoEmailError
from .models import VerificacionRegistro


class SolicitarRegistroViewTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.payload = {
            'username': 'nuevo-usuario',
            'email': 'nuevo@example.com',
            'telefono': '3001234567',
            'password': 'una-clave-segura',
        }

    @patch('users.views.send_registration_code', side_effect=BrevoEmailError)
    def test_email_timeout_returns_service_unavailable(self, send_registration_code):
        response = self.client.post('/api/register/request-code/', self.payload, format='json')

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json()['detail'],
            'No se pudo enviar el correo de verificación. Intenta de nuevo.',
        )
        send_registration_code.assert_called_once()
        self.assertTrue(VerificacionRegistro.objects.filter(email=self.payload['email']).exists())

    @patch('users.views.send_registration_code')
    def test_successful_email_returns_ok(self, send_registration_code):
        response = self.client.post('/api/register/request-code/', self.payload, format='json')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['detail'], 'Código enviado al correo.')
        send_registration_code.assert_called_once()
