from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('users', '0007_verificacionregistro'),
    ]

    operations = [
        migrations.AddConstraint(
            model_name='disponibilidad',
            constraint=models.UniqueConstraint(
                fields=('barbero', 'dia_semana'),
                name='unique_barbero_dia_semana',
            ),
        ),
    ]
