# Generated manually for the IA barber verification flow.

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("analisis_ia", "0003_codigoseguridadia"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name="codigoseguridadia",
            name="barbero",
            field=models.ForeignKey(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="codigos_ia_recibidos",
                to=settings.AUTH_USER_MODEL,
            ),
        ),
    ]
