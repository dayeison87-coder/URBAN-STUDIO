from rest_framework import serializers
# ⬇️ Importamos el nuevo modelo de calificaciones junto a los demás
from .models import Servicio, Usuario, Cita, Disponibilidad, CalificacionBarbero  


class ServicioSerializer(serializers.ModelSerializer):
    class Meta:
        model = Servicio
        fields = '__all__'


class UsuarioSerializer(serializers.ModelSerializer):
    # Declaramos el campo calculado como FloatField de solo lectura para las tarjetas
    promedio_calificacion = serializers.FloatField(read_only=True, required=False)

    class Meta:
        model = Usuario
        fields = ['id', 'username', 'email', 'telefono', 'rol', 'promedio_calificacion']


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


class DisponibilidadSerializer(serializers.ModelSerializer):  
    class Meta:
        model = Disponibilidad
        fields = ['id', 'dia_semana', 'hora_inicio', 'hora_fin']


class PerfilBarberoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Usuario
        fields = ['id', 'username', 'email', 'telefono', 'descripcion', 'experiencia', 'foto']


# ── 🌟 NUEVO SERIALIZER PARA CALIFICACIONES (ACTUALIZADO) ────────────────────────────────────────
class CalificacionBarberoSerializer(serializers.ModelSerializer):
    cliente_nombre = serializers.ReadOnlyField(source='cliente.username')
    # 👈 Mapeamos el alias exacto que pusimos en el home.html para evitar fallos de lectura
    cliente_username = serializers.ReadOnlyField(source='cliente.username') 
    barbero_nombre = serializers.ReadOnlyField(source='barbero.username')

    class Meta:
        model = CalificacionBarbero
        fields = [
            'id', 'cita', 'cliente', 'cliente_nombre', 'cliente_username',
            'barbero', 'barbero_nombre', 'estrellas', 
            'comentario', 'fecha'
        ]
        # Estos se llenan automáticamente en el backend usando la Cita y el token
        read_only_fields = ['cliente', 'barbero']

    def validate(self, data):
        cita = data['cita']
        # Validamos que la cita esté realmente terminada para poder dejar la reseña
        if cita.estado != 'Completada':
            raise serializers.ValidationError(
                "Solo puedes calificar servicios que ya hayan sido marcados como 'Completada'."
            )
        return data