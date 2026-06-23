from rest_framework import serializers
from .models import Servicio, Usuario, Cita

class ServicioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Servicio
        fields = '__all__'


class UsuarioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Usuario
        # Excluimos la contraseña por seguridad al consultar usuarios
        fields = ['id', 'username', 'email', 'telefono', 'rol']


class CitaSerializer(serializers.ModelSerializer):
    # 📝 Campos de lectura (Para que Angular reciba los nombres reales, no solo IDs)
    cliente_nombre = serializers.ReadOnlyField(source='cliente.username')
    barbero_nombre = serializers.ReadOnlyField(source='barbero.username')
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
        # Hacemos que el cliente sea opcional al escribir, porque lo asignaremos en la vista
        extra_kwargs = {
            'cliente': {'required': False}
        }


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(
        write_only=True,
        min_length=8
    )

    class Meta:
        model = Usuario  
        fields = ['username', 'email', 'password']

    def create(self, validated_data):
        user = Usuario.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password']
        )
        return user