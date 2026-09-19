from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('analisis_ia', '0005_alter_codigoseguridadia_barbero'),
    ]

    operations = [
        migrations.AddField(
            model_name='analisisfacial',
            name='detalles_corte_ia',
            field=models.JSONField(blank=True, default=dict),
        ),
    ]
