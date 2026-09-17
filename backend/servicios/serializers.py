# servicios/serializers.py

from rest_framework import serializers
from .models import (
    Categoria, Servicio, Producto, OrdenProducto, DetalleOrdenProducto,
)


class ServicioSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Servicio
        fields = ['id', 'nombre', 'descripcion', 'precio', 'disponible', 'categoria']


class CategoriaSerializer(serializers.ModelSerializer):
    servicios = ServicioSerializer(many=True, read_only=True)
    productos = serializers.SerializerMethodField()

    def get_productos(self, obj):
        return ProductoSerializer(
            obj.productos.filter(disponible=True), many=True,
            context=self.context,
        ).data

    class Meta:
        model  = Categoria
        fields = ['id', 'slug', 'nombre', 'descripcion', 'servicios', 'productos']


class ProductoSerializer(serializers.ModelSerializer):
    imagen_url = serializers.SerializerMethodField()
    categoria_nombre = serializers.ReadOnlyField(source='categoria.nombre')

    class Meta:
        model = Producto
        fields = [
            'id', 'categoria', 'categoria_nombre', 'nombre', 'descripcion',
            'imagen', 'imagen_url', 'precio', 'inventario', 'disponible',
        ]
        extra_kwargs = {'imagen': {'required': False}}

    def get_imagen_url(self, obj):
        if not obj.imagen:
            return None
        request = self.context.get('request')
        url = obj.imagen.url
        return request.build_absolute_uri(url) if request else url


class DetalleOrdenProductoSerializer(serializers.ModelSerializer):
    producto_nombre = serializers.ReadOnlyField(source='producto.nombre')
    subtotal = serializers.ReadOnlyField()

    class Meta:
        model = DetalleOrdenProducto
        fields = ['id', 'producto', 'producto_nombre', 'cantidad', 'precio_unitario', 'subtotal']


class OrdenProductoSerializer(serializers.ModelSerializer):
    items = DetalleOrdenProductoSerializer(many=True, read_only=True)
    cliente_nombre = serializers.ReadOnlyField(source='cliente.username')

    class Meta:
        model = OrdenProducto
        fields = ['id', 'cliente', 'cliente_nombre', 'estado', 'total', 'creado_en', 'items']
        read_only_fields = ['cliente', 'estado', 'total', 'creado_en']