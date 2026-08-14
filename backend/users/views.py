from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from django.db.models import Avg
# ⬇️ Importamos el nuevo modelo de Calificaciones junto a los demás
from .models import Servicio, Usuario, Cita, Disponibilidad, CalificacionBarbero
# ⬇️ Importamos el nuevo Serializer de Calificaciones junto a los demás
from .serializers import (
    ServicioSerializer, UsuarioSerializer, CitaSerializer,
    RegisterSerializer, DisponibilidadSerializer,
    PerfilBarberoSerializer, CalificacionBarberoSerializer  
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
        if user.is_staff or (user.rol and user.rol.nombre in ['Admin', 'Barbero']):
            return Cita.objects.all()
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
        return Disponibilidad.objects.filter(barbero=self.request.user)

    def perform_create(self, serializer):
        serializer.save(barbero=self.request.user)


class DisponibilidadDetailView(generics.DestroyAPIView):
    serializer_class = DisponibilidadSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Disponibilidad.objects.filter(barbero=self.request.user)
    

class PerfilBarberoView(generics.RetrieveUpdateAPIView):
    serializer_class = PerfilBarberoSerializer
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