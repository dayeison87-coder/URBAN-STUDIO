from django.db import models


class Rol(models.Model):
    nombre = models.CharField(max_length=50)

    def __str__(self):
        return self.nombre


class Usuario(models.Model):
    nombre = models.CharField(max_length=100)
    correo = models.EmailField(unique=True)
    telefono = models.CharField(max_length=20)
    password_hash = models.CharField(max_length=255)

    rol = models.ForeignKey(
        Rol,
        on_delete=models.CASCADE
    )

    fecha_registro = models.DateTimeField(auto_now_add=True)
    es_activo = models.BooleanField(default=True)

    def __str__(self):
        return self.nombre


class Servicio(models.Model):
    nombre = models.CharField(max_length=100)
    descripcion = models.TextField()
    precio = models.DecimalField(max_digits=10, decimal_places=2)
    duracion = models.IntegerField()

    def __str__(self):
        return self.nombre


class Disponibilidad(models.Model):
    barbero = models.ForeignKey(
        Usuario,
        on_delete=models.CASCADE
    )

    dia_semana = models.CharField(max_length=20)
    hora_inicio = models.TimeField()
    hora_fin = models.TimeField()

    def __str__(self):
        return f"{self.barbero} - {self.dia_semana}"


class Cita(models.Model):
    cliente = models.ForeignKey(
        Usuario,
        on_delete=models.CASCADE,
        related_name="citas_cliente"
    )

    barbero = models.ForeignKey(
        Usuario,
        on_delete=models.CASCADE,
        related_name="citas_barbero"
    )

    servicio = models.ForeignKey(
        Servicio,
        on_delete=models.CASCADE
    )

    fecha = models.DateField()
    hora = models.TimeField()

    estado = models.CharField(
        max_length=20,
        default="Pendiente"
    )

    def __str__(self):
        return f"{self.cliente} - {self.fecha}"


class Notificacion(models.Model):
    usuario = models.ForeignKey(
        Usuario,
        on_delete=models.CASCADE
    )

    mensaje = models.TextField()

    fecha_envio = models.DateTimeField(
        auto_now_add=True
    )

    leida = models.BooleanField(
        default=False
    )

    def __str__(self):
        return self.usuario.nombre