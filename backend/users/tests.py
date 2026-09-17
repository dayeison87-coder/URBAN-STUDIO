from unittest.mock import patch

from django.test import TestCase
from rest_framework.test import APIClient

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

    @patch('users.views.send_mail', side_effect=TimeoutError)
    def test_email_timeout_returns_service_unavailable(self, send_mail):
        response = self.client.post('/api/register/request-code/', self.payload, format='json')

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json()['detail'],
            'No se pudo enviar el correo de verificación. Intenta de nuevo.',
        )
        send_mail.assert_called_once()
        self.assertTrue(VerificacionRegistro.objects.filter(email=self.payload['email']).exists())

    @patch('users.views.send_mail', return_value=1)
    def test_successful_email_returns_ok(self, send_mail):
        response = self.client.post('/api/register/request-code/', self.payload, format='json')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['detail'], 'Código enviado al correo.')
        send_mail.assert_called_once()
