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


class Producto(models.Model):
    categoria = models.ForeignKey(
        Categoria, on_delete=models.CASCADE, related_name='productos'
    )
    nombre = models.CharField(max_length=100)
    descripcion = models.CharField(max_length=200, blank=True)
    imagen = models.ImageField(upload_to='productos/', blank=True, null=True)
    precio = models.DecimalField(max_digits=10, decimal_places=2)
    inventario = models.PositiveIntegerField(default=0)
    disponible = models.BooleanField(default=True)
    creado_en = models.DateTimeField(auto_now_add=True)
    actualizado = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.nombre


class OrdenProducto(models.Model):
    ESTADOS = [
        ('pendiente', 'Pendiente de pago'),
        ('pagada', 'Pagada'),
        ('retirada', 'Retirada'),
        ('cancelada', 'Cancelada'),
    ]
    cliente = models.ForeignKey(
        'users.Usuario', on_delete=models.CASCADE, related_name='ordenes_productos'
    )
    estado = models.CharField(max_length=20, choices=ESTADOS, default='pendiente')
    total = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    creado_en = models.DateTimeField(auto_now_add=True)
    actualizado = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Orden #{self.pk} — {self.cliente.username}"


class DetalleOrdenProducto(models.Model):
    orden = models.ForeignKey(
        OrdenProducto, on_delete=models.CASCADE, related_name='items'
    )
    producto = models.ForeignKey(Producto, on_delete=models.PROTECT)
    cantidad = models.PositiveIntegerField()
    precio_unitario = models.DecimalField(max_digits=10, decimal_places=2)

    @property
    def subtotal(self):
        return self.cantidad * self.precio_unitario