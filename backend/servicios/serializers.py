# servicios/serializers.py

from rest_framework import serializers
from .models import Categoria, Servicio


class ServicioSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Servicio
        fields = ['id', 'nombre', 'descripcion', 'precio', 'disponible', 'categoria']


class CategoriaSerializer(serializers.ModelSerializer):
    servicios = ServicioSerializer(many=True, read_only=True)

    class Meta:
        model  = Categoria
        fields = ['id', 'slug', 'nombre', 'descripcion', 'servicios']