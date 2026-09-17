from django.db import migrations


CATALOG = {
    'cabello': {
        'nombre': 'Cabello',
        'descripcion': 'Cortes y estilos para cada ocasión.',
        'servicios': [
            ('Corte clásico', 'Corte tradicional con acabado y peinado.', 25000),
            ('Corte fade', 'Degradado personalizado con acabado profesional.', 30000),
            ('Corte + barba', 'Corte de cabello y arreglo completo de barba.', 45000),
        ],
    },
    'barba': {
        'nombre': 'Barba',
        'descripcion': 'Arreglo y cuidado profesional de la barba.',
        'servicios': [
            ('Perfilado de barba', 'Definición de contornos y recorte de barba.', 20000),
            ('Barba completa', 'Recorte, perfilado y tratamiento de barba.', 30000),
            ('Barba premium', 'Arreglo de barba con toalla caliente y cuidado facial.', 40000),
        ],
    },
    'rostro': {
        'nombre': 'Rostro',
        'descripcion': 'Cuidado facial para complementar tu estilo.',
        'servicios': [
            ('Limpieza facial', 'Limpieza profunda para una piel renovada.', 35000),
            ('Tratamiento facial', 'Hidratación y cuidado facial personalizado.', 45000),
        ],
    },
    'productos': {
        'nombre': 'Productos',
        'descripcion': 'Productos seleccionados para tu rutina diaria.',
        'servicios': [
            ('Cera para cabello', 'Producto profesional para fijación y textura.', 25000),
            ('Aceite para barba', 'Aceite nutritivo para el cuidado de la barba.', 30000),
        ],
    },
}


def seed_catalog(apps, schema_editor):
    Categoria = apps.get_model('servicios', 'Categoria')
    Servicio = apps.get_model('servicios', 'Servicio')

    for slug, category_data in CATALOG.items():
        categoria, _ = Categoria.objects.update_or_create(
            slug=slug,
            defaults={
                'nombre': category_data['nombre'],
                'descripcion': category_data['descripcion'],
            },
        )
        for nombre, descripcion, precio in category_data['servicios']:
            Servicio.objects.update_or_create(
                categoria=categoria,
                nombre=nombre,
                defaults={
                    'descripcion': descripcion,
                    'precio': precio,
                    'disponible': True,
                },
            )


def remove_catalog(apps, schema_editor):
    Categoria = apps.get_model('servicios', 'Categoria')
    Categoria.objects.filter(slug__in=CATALOG).delete()


class Migration(migrations.Migration):
    dependencies = [
        ('servicios', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(seed_catalog, remove_catalog),
    ]
