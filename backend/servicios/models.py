# servicios/models.py

from django.db import models


class Categoria(models.Model):
    CATEGORIAS = [
        ('cabello',   'Cabello'),
        ('barba',     'Barba'),
        ('rostro',    'Rostro'),
        ('productos', 'Productos'),
    ]

    slug  = models.CharField(max_length=20, choices=CATEGORIAS, unique=True)
    nombre = models.CharField(max_length=50)
    descripcion = models.CharField(max_length=120, blank=True)

    def __str__(self):
        return self.nombre


class Servicio(models.Model):
    categoria   = models.ForeignKey(Categoria, on_delete=models.CASCADE, related_name='servicios')
    nombre      = models.CharField(max_length=100)
    descripcion = models.CharField(max_length=200, blank=True)
    precio      = models.DecimalField(max_digits=10, decimal_places=0)
    disponible  = models.BooleanField(default=True)
    creado_en   = models.DateTimeField(auto_now_add=True)
    actualizado = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.categoria.nombre} — {self.nombre}"