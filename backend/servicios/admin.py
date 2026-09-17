from django.contrib import admin

from django.contrib import admin

from .models import Categoria, Servicio, Producto, OrdenProducto, DetalleOrdenProducto


admin.site.register(Categoria)
admin.site.register(Servicio)
admin.site.register(Producto)
admin.site.register(OrdenProducto)
admin.site.register(DetalleOrdenProducto)
