from rest_framework import serializers
from .models import AnalisisFacial


class AnalisisFacialInputSerializer(serializers.Serializer):
    foto = serializers.ImageField()


class AnalisisFacialOutputSerializer(serializers.ModelSerializer):
    class Meta:
        model = AnalisisFacial
        fields = [
            "id",
            "foto_original",
            "forma_rostro",
            "indice_cefalico",
            "tipo_cabello",
            "descripcion_ia",
            "corte_recomendado",
            "nombre_corte_sugerido",
            "imagen_resultado",
            "imagen_resultado_perfil",
            "estado",
            "error_detalle",
            "creado_en",
        ]
        read_only_fields = fields
