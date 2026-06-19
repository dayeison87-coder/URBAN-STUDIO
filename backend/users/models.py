from django.db import models
from django.contrib.auth.models import AbstractUser # 🔥 IMPORTACIÓN CLAVE

class Rol(models.Model):
    nombre = models.CharField(max_length=50)

    def __str__(self):
        return self.nombre


# 🔥 CAMBIO PRINCIPAL: Ahora hereda de AbstractUser
class Usuario(AbstractUser):
    # 💡 NOTA: 'username', 'email', 'password' y 'is_active' YA VIENEN INCLUIDOS gracias a AbstractUser.
    # No hace falta declararlos aquí. Django usa 'email' en vez de 'correo'.
    
    telefono = models.CharField(max_length=20, blank=True, null=True)
    
    rol = models.ForeignKey(
        Rol,
        on_delete=models.CASCADE,
        null=True,   # Permite que al crear el primer superusuario no falle por falta de rol
        blank=True
    )
    
    fecha_registro = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        # Usamos 'username' o 'first_name' que vienen heredados
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
    fecha_envio = models.DateTimeField(auto_now_add=True)
    leida = models.BooleanField(default=False)

    def __str__(self):
        return self.usuario.username