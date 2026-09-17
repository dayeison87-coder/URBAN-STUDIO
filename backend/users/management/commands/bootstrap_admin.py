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
        user, created = User.objects.get_or_create(
            username=username,
            defaults={'email': email},
        )
        if created:
            user.email = email
            user.is_staff = True
            user.is_superuser = True
            user.set_password(password)
            user.save()
            self.stdout.write(self.style.SUCCESS(f'Admin user {username} created.'))
        elif not user.is_superuser or not user.is_staff:
            user.email = email
            user.is_staff = True
            user.is_superuser = True
            user.set_password(password)
            user.save()
            self.stdout.write(self.style.SUCCESS(f'Admin user {username} promoted.'))
        else:
            self.stdout.write(f'Admin user {username} already exists; password unchanged.')
