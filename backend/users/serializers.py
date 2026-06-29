from rest_framework import serializers
from .models import Servicio, Usuario, Cita, Disponibilidad  # 👈 agregar Disponibilidad


class ServicioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Servicio
        fields = '__all__'


class UsuarioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Usuario
        fields = ['id', 'username', 'email', 'telefono', 'rol']


class CitaSerializer(serializers.ModelSerializer):
    cliente_nombre  = serializers.ReadOnlyField(source='cliente.username')
    barbero_nombre  = serializers.ReadOnlyField(source='barbero.username')
    servicio_nombre = serializers.ReadOnlyField(source='servicio.nombre')
    servicio_precio = serializers.ReadOnlyField(source='servicio.precio')

    class Meta:
        model = Cita
        fields = [
            'id', 'cliente', 'cliente_nombre',
            'barbero', 'barbero_nombre',
            'servicio', 'servicio_nombre', 'servicio_precio',
            'fecha', 'hora', 'estado'
        ]
        extra_kwargs = {
            'cliente': {'required': False}
        }


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = Usuario
        fields = ['username', 'email', 'telefono', 'password']

    def create(self, validated_data):
        user = Usuario.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            telefono=validated_data.get('telefono', ''),
            password=validated_data['password']
        )
        return user


class DisponibilidadSerializer(serializers.ModelSerializer):  # 👈 fuera de RegisterSerializer
    class Meta:
        model = Disponibilidad
        fields = ['id', 'dia_semana', 'hora_inicio', 'hora_fin']



class PerfilBarberoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Usuario
        fields = ['id', 'username', 'email', 'telefono', 'descripcion', 'experiencia', 'foto']
