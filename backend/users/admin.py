from django.contrib import admin
from .models import (
    Rol,
    Usuario,
    Servicio,
    Disponibilidad,
    Cita,
    Notificacion
)

admin.site.register(Rol)
admin.site.register(Usuario)
admin.site.register(Servicio)
admin.site.register(Disponibilidad)
admin.site.register(Cita)
admin.site.register(Notificacion)