from rest_framework import generics

from .models import Servicio, Usuario, Cita
from .serializers import ServicioSerializer, UsuarioSerializer, CitaSerializer

from .models import Servicio, Usuario



class ServicioListCreateView(
    generics.ListCreateAPIView
):
    queryset = Servicio.objects.all()
    serializer_class = ServicioSerializer

class UsuarioListCreateView(
    generics.ListCreateAPIView
):
    queryset = Usuario.objects.all()
    serializer_class = UsuarioSerializer

class CitaListCreateView(
    generics.ListCreateAPIView
):
    queryset = Cita.objects.all()
    serializer_class = CitaSerializer