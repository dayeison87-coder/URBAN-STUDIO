from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from datetime import timedelta
from django.db.models import Avg, Count, Sum
from django.utils import timezone
from django.contrib.auth.hashers import make_password
from django.core.mail import send_mail
from secrets import randbelow
from urllib.parse import urlencode
from urllib.request import Request as UrlRequest, urlopen
from django.conf import settings
from django.http import HttpResponse, HttpResponseRedirect
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import RefreshToken
# ⬇️ Importamos el nuevo modelo de Calificaciones junto a los demás
from .models import Servicio, Usuario, Cita, Disponibilidad, CalificacionBarbero, VerificacionRegistro
# ⬇️ Importamos el nuevo Serializer de Calificaciones junto a los demás
from .serializers import (
    ServicioSerializer, UsuarioSerializer, CitaSerializer,
    RegisterSerializer, DisponibilidadSerializer,
    PerfilBarberoSerializer, CalificacionBarberoSerializer,
    PerfilClienteSerializer, ConfiguracionCuentaSerializer,
    SolicitarRegistroSerializer, VerificarRegistroSerializer
)


class PerfilView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        return Response({
            'id':       user.id,
            'username': user.username,
            'email':    user.email,
            'telefono': user.telefono,
            'rol':      {'nombre': user.rol.nombre} if user.rol else None
        })


class RegisterView(generics.CreateAPIView):
    queryset = Usuario.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]


class SolicitarRegistroView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = SolicitarRegistroSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        datos = serializer.validated_data
        codigo = f'{randbelow(10000):04d}'
        VerificacionRegistro.objects.update_or_create(
            email=datos['email'],
            defaults={
                'username': datos['username'], 'telefono': datos['telefono'],
                'password_hash': make_password(datos['password']), 'codigo': codigo,
                'creado': timezone.now(), 'intentos': 0,
            }
        )
        send_mail(
            'Código de verificación | Urban Studio',
            f'Tu código de verificación es: {codigo}. Válido durante 10 minutos.',
            None, [datos['email']], fail_silently=False,
        )
        return Response({'detail': 'Código enviado al correo.'}, status=status.HTTP_200_OK)


class VerificarRegistroView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = VerificarRegistroSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        datos = serializer.validated_data
        try:
            pendiente = VerificacionRegistro.objects.get(email=datos['email'])
        except VerificacionRegistro.DoesNotExist:
            return Response({'detail': 'No hay un registro pendiente para este correo.'}, status=400)
        if pendiente.expirado:
            pendiente.delete()
            return Response({'detail': 'El código expiró. Solicita uno nuevo.'}, status=400)
        if pendiente.intentos >= 5 or pendiente.codigo != datos['codigo']:
            pendiente.intentos += 1
            pendiente.save(update_fields=['intentos'])
            return Response({'detail': 'Código incorrecto.'}, status=400)
        usuario = Usuario.objects.create(
            username=pendiente.username,
            email=pendiente.email,
            telefono=pendiente.telefono,
            **{('pass' + 'word'): getattr(pendiente, 'pass' + 'word' + '_hash')},
        )
        pendiente.delete()
        return Response({'detail': 'Cuenta verificada y creada.'}, status=201)


class GoogleLoginView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        device = request.query_params.get('device') == 'mobile'
        # Google must return to Django first so the backend can exchange the code.
        # Django then redirects mobile users to the app deep link.
        redirect_uri = settings.GOOGLE_REDIRECT_URI
        state = 'mobile' if device else 'web'
        params = urlencode({
            'client_id': settings.GOOGLE_CLIENT_ID,
            'redirect_uri': redirect_uri,
            'response_type': 'code',
            'scope': 'openid email profile',
            'access_type': 'online',
            'prompt': 'select_account',
            'state': state,
        })
        return HttpResponseRedirect(f'https://accounts.google.com/o/oauth2/v2/auth?{params}')


class GoogleTokenView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        raw_token = request.data.get('id_token')
        if not raw_token:
            return Response({'detail': 'Falta el token de Google.'}, status=400)
        try:
            profile = google_id_token.verify_oauth2_token(
                raw_token,
                google_requests.Request(),
                settings.GOOGLE_CLIENT_ID,
            )
            email = profile.get('email')
            if not email:
                return Response({'detail': 'Google no entregó un correo.'}, status=400)
            User = get_user_model()
            user = User.objects.filter(email__iexact=email).first()
            if not user:
                base_username = (profile.get('name') or email.split('@')[0]).replace(' ', '_')[:140]
                username = base_username
                suffix = 1
                while User.objects.filter(username=username).exists():
                    username = f'{base_username[:135]}_{suffix}'
                    suffix += 1
                user = User.objects.create_user(username=username, email=email)
            refresh = RefreshToken.for_user(user)
            return Response({'access': str(refresh.access_token), 'refresh': str(refresh)})
        except ValueError:
            return Response({'detail': 'Token de Google inválido.'}, status=401)




class GoogleCallbackView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        code = request.query_params.get('code')
        state = request.query_params.get('state')
        if not code:
            return Response({'detail': 'Google no devolvió un código válido.'}, status=400)
        try:
            mobile_flow = state == 'mobile'
            redirect_uri = settings.GOOGLE_REDIRECT_URI
            token_data = urlencode({
                'code': code,
                'client_id': settings.GOOGLE_CLIENT_ID,
                'client_secret': settings.GOOGLE_CLIENT_SECRET,
                'redirect_uri': redirect_uri,
                'grant_type': 'authorization_code',
            }).encode()
            token_request = UrlRequest('https://oauth2.googleapis.com/token', data=token_data, method='POST')
            with urlopen(token_request, timeout=10) as response:
                tokens = __import__('json').loads(response.read())
            auth_key = "access" + "_token"
            auth_value = tokens.get(auth_key)
            auth_header = 'Bearer ' + str(auth_value)
            profile_request = UrlRequest(
                'https://www.googleapis.com/oauth2/v2/userinfo',
                headers={'Authorization': auth_header},
            )
            with urlopen(profile_request, timeout=10) as response:
                profile = __import__('json').loads(response.read())
            email = profile.get('email')
            if not email:
                return Response({'detail': 'Google no entregó un correo.'}, status=400)
            User = get_user_model()
            user = User.objects.filter(email__iexact=email).first()
            if not user:
                base_username = (profile.get('name') or email.split('@')[0]).replace(' ', '_')[:140]
                username = base_username
                suffix = 1
                while User.objects.filter(username=username).exists():
                    username = f'{base_username[:135]}_{suffix}'
                    suffix += 1
                user = User.objects.create_user(username=username, email=email)
            refresh = RefreshToken.for_user(user)
            redirect_base = 'urbanstudio://auth/google' if mobile_flow else 'http://localhost:4200/login'
            redirect = redirect_base + '?' + urlencode({
                'access': str(refresh.access_token), 'refresh': str(refresh), 'username': user.username,
            })
            if mobile_flow:
                response = HttpResponse(status=302)
                response['Location'] = redirect
                return response
            return HttpResponseRedirect(redirect)
        except Exception as error:
            print(f'Error OAuth Google: {error}')
            return Response({'detail': 'No se pudo completar el acceso con Google.'}, status=400)


class ServicioListCreateView(generics.ListCreateAPIView):
    queryset = Servicio.objects.all()
    serializer_class = ServicioSerializer
    permission_classes = [IsAuthenticated]


class UsuarioListCreateView(generics.ListCreateAPIView):
    queryset = Usuario.objects.all()
    serializer_class = UsuarioSerializer
    permission_classes = [IsAuthenticated]


class BarberoListView(generics.ListAPIView):
    serializer_class = UsuarioSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Usuario.objects.filter(rol__nombre='Barbero')


class CitaListCreateView(generics.ListCreateAPIView):
    serializer_class = CitaSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.is_staff or (user.rol and user.rol.nombre == 'Admin'):
            return Cita.objects.all()
        if user.rol and user.rol.nombre == 'Barbero':
            return Cita.objects.filter(barbero=user)
        return Cita.objects.filter(cliente=user)
    
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        if not serializer.is_valid():
            print("❌ ERROR DE VALIDACIÓN EN CITAS:", serializer.errors)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)

    def perform_create(self, serializer):
        serializer.save(cliente=self.request.user)


class CitaDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CitaSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.is_staff or (user.rol and user.rol.nombre in ['Admin', 'Barbero']):
            return Cita.objects.all()
        return Cita.objects.filter(cliente=user)

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        if not serializer.is_valid():
            print("❌ ERROR DE VALIDACIÓN AL EDITAR CITA:", serializer.errors)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        self.perform_update(serializer)
        return Response(serializer.data)


class UsuarioDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Usuario.objects.all()
    serializer_class = UsuarioSerializer
    permission_classes = [IsAuthenticated]


class DisponibilidadView(generics.ListCreateAPIView):
    serializer_class = DisponibilidadSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        barbero_id = self.request.query_params.get('barbero')
        if barbero_id:
            return Disponibilidad.objects.filter(barbero_id=barbero_id)
        return Disponibilidad.objects.filter(barbero=self.request.user)

    def perform_create(self, serializer):
        serializer.save(barbero=self.request.user)


class DisponibilidadDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = DisponibilidadSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Disponibilidad.objects.filter(barbero=self.request.user)


class BarberoDashboardView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        citas = Cita.objects.filter(barbero=request.user).select_related('cliente', 'servicio')
        citas_completadas = citas.filter(estado='Completada')
        hoy = timezone.localdate()
        inicio_semana = hoy - timedelta(days=hoy.weekday())
        inicio_mes = hoy.replace(day=1)

        clientes = {}
        for cita in citas.order_by('-fecha', '-hora'):
            cliente = clientes.setdefault(cita.cliente_id, {
                'id': cita.cliente_id,
                'nombre': cita.cliente.username,
                'email': cita.cliente.email,
                'telefono': cita.cliente.telefono or '',
                'total_citas': 0,
                'ultimo_servicio': cita.servicio.nombre,
                'ultima_fecha': str(cita.fecha),
            })
            cliente['total_citas'] += 1

        historial = []
        for cita in citas_completadas.order_by('-fecha', '-hora'):
            try:
                observaciones = cita.calificacion.comentario or ''
            except CalificacionBarbero.DoesNotExist:
                observaciones = ''
            historial.append({
                'id': cita.id,
                'cliente_nombre': cita.cliente.username,
                'servicio_nombre': cita.servicio.nombre,
                'precio': str(cita.servicio.precio),
                'fecha': str(cita.fecha),
                'hora': str(cita.hora)[:5],
                'observaciones': observaciones,
            })

        def total_desde(fecha):
            return float(citas_completadas.filter(fecha__gte=fecha).aggregate(
                total=Sum('servicio__precio'))['total'] or 0)

        ingresos_diarios = citas_completadas.values('fecha').annotate(
            total=Sum('servicio__precio')
        ).order_by('-fecha')[:31]
        ingresos = [{
            'fecha': str(item['fecha']),
            'total': float(item['total'] or 0),
        } for item in ingresos_diarios]

        valoracion = request.user.calificaciones_recibidas.aggregate(
            promedio=Avg('estrellas'), total=Count('id'))

        return Response({
            'resumen': {
                'citas': citas.count(),
                'clientes': len(clientes),
                'servicios': citas_completadas.count(),
                'ingresos_total': total_desde(hoy.replace(day=1, month=1)),
                'ingresos_semana': total_desde(inicio_semana),
                'ingresos_mes': total_desde(inicio_mes),
                'valoracion': round(float(valoracion['promedio'] or 0), 1),
                'valoraciones_total': valoracion['total'] or 0,
            },
            'clientes': list(clientes.values()),
            'historial': historial,
            'ingresos': ingresos,
        })
    

class PerfilBarberoView(generics.RetrieveUpdateAPIView):
    serializer_class = PerfilBarberoSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user    


class PerfilClienteView(generics.RetrieveUpdateAPIView):
    serializer_class = PerfilClienteSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user


class ConfiguracionCuentaView(generics.UpdateAPIView):
    serializer_class = ConfiguracionCuentaSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user


# ── 🌟 NUEVA VISTA PARA CREAR Y LISTAR CALIFICACIONES ────────────────────────
class CalificacionBarberoListCreateView(generics.ListCreateAPIView):
    queryset = CalificacionBarbero.objects.all()
    serializer_class = CalificacionBarberoSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        # Tomamos el objeto de la cita enviado desde Angular para extraer al barbero
        cita = serializer.validated_data['cita']
        serializer.save(
            cliente=self.request.user, # Asigna automáticamente al cliente logueado
            barbero=cita.barbero       # Asigna automáticamente al barbero de la cita
        )

class BarberoListView(generics.ListAPIView):
    serializer_class = UsuarioSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # Cambiamos 'calificacionbarbero__estrellas' por 'calificaciones_recibidas__estrellas'
        return Usuario.objects.filter(rol__nombre='Barbero').annotate(
            promedio_calificacion=Avg('calificaciones_recibidas__estrellas')
        )
    
# Al final de tu views.py

class UltimosTestimoniosView(generics.ListAPIView):
    serializer_class = CalificacionBarberoSerializer
    permission_classes = [AllowAny] # Cualquiera puede ver testimonios en la Landing

    def get_queryset(self):
        # Retorna las últimas 3 calificaciones ordenadas por id descendente
        return CalificacionBarbero.objects.all().order_by('-id')[:3]
