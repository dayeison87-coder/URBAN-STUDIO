from django.contrib import admin

from django.contrib import admin

from .models import Categoria, Servicio, Producto, OrdenProducto, DetalleOrdenProducto


@admin.register(OrdenProducto)
class OrdenProductoAdmin(admin.ModelAdmin):
    list_display = ('id', 'cliente', 'estado', 'total', 'creado_en')
    list_filter = ('estado', 'creado_en')
    search_fields = ('cliente__username', 'cliente__email')
    readonly_fields = ('total', 'creado_en', 'actualizado')


admin.site.register(Categoria)
admin.site.register(Servicio)
admin.site.register(Producto)
admin.site.register(DetalleOrdenProducto)
