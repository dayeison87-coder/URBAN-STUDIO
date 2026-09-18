from unittest.mock import patch

from django.test import TestCase
from rest_framework.test import APIClient

from .email_service import BrevoEmailError
from .models import Rol, Usuario, VerificacionRegistro


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


class UsuarioRolBarberoViewTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.payload = {
            'username': 'registro-exitoso',
            'email': 'registro@example.com',
            'telefono': '3001234567',
            'password': 'una-clave-segura',
        }
        admin_role = Rol.objects.create(nombre='Admin')
        self.admin = Usuario.objects.create_user(
            username='admin', password='una-clave-segura', rol=admin_role,
        )
        self.usuario = Usuario.objects.create_user(
            username='cliente', password='una-clave-segura',
        )
        self.client.force_authenticate(self.admin)

    def test_assigns_barber_role_without_relying_on_role_id(self):
        response = self.client.patch(
            f'/api/usuarios/{self.usuario.id}/rol-barbero/',
            {'barbero': True},
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        self.usuario.refresh_from_db()
        self.assertEqual(self.usuario.rol.nombre, 'Barbero')

    def test_removes_barber_role(self):
        barber_role = Rol.objects.create(nombre='Barbero')
        self.usuario.rol = barber_role
        self.usuario.save()

        response = self.client.patch(
            f'/api/usuarios/{self.usuario.id}/rol-barbero/',
            {'barbero': False},
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        self.usuario.refresh_from_db()
        self.assertIsNone(self.usuario.rol)
    @patch('users.views.send_registration_code')
    def test_successful_email_returns_ok(self, send_registration_code):
        response = self.client.post('/api/register/request-code/', self.payload, format='json')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['detail'], 'Código enviado al correo.')
        send_registration_code.assert_called_once()
