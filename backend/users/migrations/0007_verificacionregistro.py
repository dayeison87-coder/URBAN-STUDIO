from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('users', '0006_calificacionbarbero'),
    ]

    operations = [
        migrations.CreateModel(
            name='VerificacionRegistro',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('email', models.EmailField(max_length=254, unique=True)),
                ('username', models.CharField(max_length=150)),
                ('telefono', models.CharField(blank=True, max_length=20)),
                ('password_hash', models.CharField(max_length=128)),
                ('codigo', models.CharField(max_length=4)),
                ('creado', models.DateTimeField(auto_now_add=True)),
                ('intentos', models.PositiveSmallIntegerField(default=0)),
            ],
        ),
    ]
