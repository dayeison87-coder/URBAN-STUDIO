from django.db import models
from django.contrib.auth.models import AbstractUser

class Rol(models.Model):
    nombre = models.CharField(max_length=50)

    def __str__(self):
        return self.nombre


class Usuario(AbstractUser):
    telefono = models.CharField(max_length=20, blank=True, null=True)
    rol = models.ForeignKey(
        Rol,
        on_delete=models.CASCADE,
        null=True,
        blank=True
    )
    fecha_registro = models.DateTimeField(auto_now_add=True)
    
    # 👈 Campos nuevos para el perfil del barbero
    foto = models.ImageField(upload_to='fotos_barberos/', blank=True, null=True)
    descripcion = models.TextField(blank=True, null=True)
    experiencia = models.IntegerField(blank=True, null=True)  # años de experiencia

    def __str__(self):
        return self.username


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
        on_delete=models.CASCADE,
        related_name="disponibilidades"
    )
    dia_semana = models.CharField(max_length=20)
    hora_inicio = models.TimeField()
    hora_fin = models.TimeField()

    def __str__(self):
        return f"{self.barbero.username} - {self.dia_semana}"


class Cita(models.Model):
    ESTADOS_CITA = [
        ('Pendiente', 'Pendiente'),
        ('Completada', 'Completada'),
        ('Cancelada', 'Cancelada'),
    ]

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
    'servicios.Servicio',   # ← apunta a la nueva tabla
    on_delete=models.CASCADE
    )
    fecha = models.DateField()
    hora = models.TimeField()
    estado = models.CharField(
        max_length=20,
        choices=ESTADOS_CITA,
        default="Pendiente"
    )

    def __str__(self):
        return f"Cita: {self.cliente.username} con {self.barbero.username} - {self.fecha} a las {self.hora}"


class Notificacion(models.Model):
    usuario = models.ForeignKey(
        Usuario,
        on_delete=models.CASCADE
    )
    mensaje = models.TextField()
    fecha_envio = models.DateTimeField(auto_now_add=True)
    leida = models.BooleanField(default=False)

    def __str__(self):
        return f"Notificación para {self.usuario.username}"