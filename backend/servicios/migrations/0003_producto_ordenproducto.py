from django.db import migrations, models
import django.db.models.deletion


def move_product_services(apps, schema_editor):
    Categoria = apps.get_model('servicios', 'Categoria')
    Servicio = apps.get_model('servicios', 'Servicio')
    Producto = apps.get_model('servicios', 'Producto')
    try:
        categoria = Categoria.objects.get(slug='productos')
    except Categoria.DoesNotExist:
        return
    for servicio in Servicio.objects.filter(categoria=categoria):
        Producto.objects.create(
            categoria=categoria,
            nombre=servicio.nombre,
            descripcion=servicio.descripcion,
            precio=servicio.precio,
            inventario=0,
            disponible=servicio.disponible,
        )
    Servicio.objects.filter(categoria=categoria).delete()


class Migration(migrations.Migration):
    dependencies = [
        ('servicios', '0002_seed_catalog'),
        ('users', '0007_verificacionregistro'),
    ]

    operations = [
        migrations.CreateModel(
            name='Producto',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('nombre', models.CharField(max_length=100)),
                ('descripcion', models.CharField(blank=True, max_length=200)),
                ('imagen', models.ImageField(blank=True, null=True, upload_to='productos/')),
                ('precio', models.DecimalField(decimal_places=2, max_digits=10)),
                ('inventario', models.PositiveIntegerField(default=0)),
                ('disponible', models.BooleanField(default=True)),
                ('creado_en', models.DateTimeField(auto_now_add=True)),
                ('actualizado', models.DateTimeField(auto_now=True)),
                ('categoria', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='productos', to='servicios.categoria')),
            ],
        ),
        migrations.CreateModel(
            name='OrdenProducto',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('estado', models.CharField(choices=[('pendiente', 'Pendiente de pago'), ('pagada', 'Pagada'), ('retirada', 'Retirada'), ('cancelada', 'Cancelada')], default='pendiente', max_length=20)),
                ('total', models.DecimalField(decimal_places=2, default=0, max_digits=10)),
                ('creado_en', models.DateTimeField(auto_now_add=True)),
                ('actualizado', models.DateTimeField(auto_now=True)),
                ('cliente', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='ordenes_productos', to='users.usuario')),
            ],
        ),
        migrations.CreateModel(
            name='DetalleOrdenProducto',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('cantidad', models.PositiveIntegerField()),
                ('precio_unitario', models.DecimalField(decimal_places=2, max_digits=10)),
                ('orden', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='items', to='servicios.ordenproducto')),
                ('producto', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, to='servicios.producto')),
            ],
        ),
        migrations.RunPython(move_product_services, migrations.RunPython.noop),
    ]
