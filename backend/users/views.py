from rest_framework import generics
from rest_framework.permissions import IsAuthenticated, AllowAny
from .models import Servicio, Usuario, Cita
from .serializers import ServicioSerializer, UsuarioSerializer, CitaSerializer, RegisterSerializer

# Vista pública: cualquiera puede registrarse
class RegisterView(generics.CreateAPIView):
    queryset = Usuario.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]

# Vistas protegidas: requieren estar logueado (Tener Token JWT)
class ServicioListCreateView(generics.ListCreateAPIView):
    queryset = Servicio.objects.all()
    serializer_class = ServicioSerializer
    permission_classes = [IsAuthenticated]

class UsuarioListCreateView(generics.ListCreateAPIView):
    queryset = Usuario.objects.all()
    serializer_class = UsuarioSerializer
    permission_classes = [IsAuthenticated]

class CitaListCreateView(generics.ListCreateAPIView):
    queryset = Cita.objects.all()
    serializer_class = CitaSerializer
    permission_classes = [IsAuthenticated]