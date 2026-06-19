from rest_framework import generics
from .models import Servicio, Usuario, Cita
from .serializers import ServicioSerializer, UsuarioSerializer, CitaSerializer, RegisterSerializer

# 💡 Eliminamos la importación de 'User' de Django para no confundirnos

class ServicioListCreateView(generics.ListCreateAPIView):
    queryset = Servicio.objects.all()
    serializer_class = ServicioSerializer

class UsuarioListCreateView(generics.ListCreateAPIView):
    queryset = Usuario.objects.all()
    serializer_class = UsuarioSerializer

class CitaListCreateView(generics.ListCreateAPIView):
    queryset = Cita.objects.all()
    serializer_class = CitaSerializer

# 🔥 AQUÍ ESTÁ EL CAMBIO IMPORTANTE:
class RegisterView(generics.CreateAPIView):
    queryset = Usuario.objects.all()  # 👈 Cambiado 'User' por tu modelo 'Usuario'
    serializer_class = RegisterSerializer