from rest_framework import serializers

from .models import Servicio, Usuario, Cita, Disponibilidad, VerificacionRegistro
from rest_framework.validators import UniqueValidator
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
        fields = ['id', 'username', 'email', 'telefono', 'rol', 'promedio_calificacion', 'foto']


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
    username = serializers.CharField(
        max_length=150,
        validators=[
            UniqueValidator(
                queryset=Usuario.objects.all(),
                message='Este nombre de usuario ya está registrado.'
            )
        ]
    )
    
    email = serializers.EmailField(
        validators=[
            UniqueValidator(
                queryset=Usuario.objects.all(),
                message='Este correo ya está registrado.'
            )
        ]
    )

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


class SolicitarRegistroSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    telefono = serializers.CharField(max_length=20)
    password = serializers.CharField(min_length=8, write_only=True)

    def validate(self, attrs):
        if Usuario.objects.filter(username=attrs['username']).exists():
            raise serializers.ValidationError({'username': 'Este nombre de usuario ya está registrado.'})
        if Usuario.objects.filter(email=attrs['email']).exists():
            raise serializers.ValidationError({'email': 'Este correo ya está registrado.'})
        return attrs


class VerificarRegistroSerializer(serializers.Serializer):
    email = serializers.EmailField()
    codigo = serializers.RegexField(regex=r'^\d{4}$')


class DisponibilidadSerializer(serializers.ModelSerializer):  
    class Meta:
        model = Disponibilidad
        fields = ['id', 'dia_semana', 'hora_inicio', 'hora_fin']


class PerfilBarberoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Usuario
        fields = ['id', 'username', 'email', 'telefono', 'descripcion', 'experiencia', 'foto']


class PerfilClienteSerializer(serializers.ModelSerializer):
    class Meta:
        model = Usuario
        fields = ['id', 'username', 'email', 'telefono', 'foto']
        read_only_fields = ['id']


class ConfiguracionCuentaSerializer(serializers.ModelSerializer):
    password_actual = serializers.CharField(write_only=True, required=True)
    password_nueva = serializers.CharField(write_only=True, required=False, min_length=8)

    class Meta:
        model = Usuario
        fields = ['id', 'email', 'password_actual', 'password_nueva']
        read_only_fields = ['id']

    def update(self, instance, validated_data):
        password_actual = validated_data.pop('password_actual')
        password_nueva = validated_data.pop('password_nueva', None)
        if not instance.check_password(password_actual):
            raise serializers.ValidationError({'password_actual': 'La contraseña actual no es correcta.'})
        if password_nueva:
            instance.set_password(password_nueva)
        instance.save()
        return instance


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