from rest_framework import serializers
# 💡 Eliminamos la importación de User de Django para no causar conflictos
from .models import Servicio, Usuario, Cita


class ServicioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Servicio
        fields = '__all__'


class UsuarioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Usuario
        fields = '__all__'


class CitaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Cita
        fields = '__all__'


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(
        write_only=True,
        min_length=8
    )

    class Meta:
        model = Usuario  # 🔥 CAMBIADO: Ahora usa tu modelo personalizado
        fields = [
            'username',
            'email',
            'password'
        ]

    def create(self, validated_data):
        # 🔥 CAMBIADO: Usamos 'Usuario.objects.create_user' para que guarde en TU tabla 
        # y encripte la contraseña correctamente en SQLite.
        user = Usuario.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password']
        )
        return user