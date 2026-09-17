import os

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = 'Creates the initial admin user when admin environment variables are configured.'

    def handle(self, *args, **options):
        username = os.getenv('ADMIN_USERNAME')
        email = os.getenv('ADMIN_EMAIL')
        password = os.getenv('ADMIN_PASSWORD')

        if not any((username, email, password)):
            self.stdout.write('Admin variables not configured; skipping admin bootstrap.')
            return

        if not all((username, email, password)):
            raise ValueError(
                'ADMIN_USERNAME, ADMIN_EMAIL and ADMIN_PASSWORD must be configured together.'
            )

        User = get_user_model()
        Rol = User._meta.get_field('rol').remote_field.model
        admin_role, _ = Rol.objects.get_or_create(nombre='Admin')
        user, created = User.objects.get_or_create(
            username=username,
            defaults={'email': email},
        )
        user.email = email
        user.is_staff = True
        user.is_superuser = True
        user.is_active = True
        user.rol = admin_role
        user.set_password(password)
        user.save()

        action = 'created' if created else 'updated'
        self.stdout.write(
            self.style.SUCCESS(f'Admin user {username} {action}; password synchronized.')
        )
