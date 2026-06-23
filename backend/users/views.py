from rest_framework import generics
from rest_framework.permissions import IsAuthenticated, AllowAny
from .models import Servicio, Usuario, Cita
from .serializers import ServicioSerializer, UsuarioSerializer, CitaSerializer, RegisterSerializer

# --- 1. REGISTRO DE USUARIOS ---
class RegisterView(generics.CreateAPIView):
    queryset = Usuario.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]


# --- 2. VISTAS DE SERVICIOS ---
class ServicioListCreateView(generics.ListCreateAPIView):
    queryset = Servicio.objects.all()
    serializer_class = ServicioSerializer
    permission_classes = [IsAuthenticated]


# --- 3. VISTAS DE USUARIOS ---
class UsuarioListCreateView(generics.ListCreateAPIView):
    queryset = Usuario.objects.all()
    serializer_class = UsuarioSerializer
    permission_classes = [IsAuthenticated]


# --- 4. VISTAS DE CITAS (EL CRUD SEPARADO EN DOS CLASES) ---

# A. Para Listar (Punto 11) y Crear (Punto 10)
class CitaListCreateView(generics.ListCreateAPIView):
    serializer_class = CitaSerializer
    permission_classes = [IsAuthenticated]

    # Filtrado inteligente: El cliente logueado solo ve sus citas.
    # Si es un administrador o barbero, podría verlas todas.
    def get_queryset(self):
        user = self.request.user
        if user.is_staff or (user.rol and user.rol.nombre in ['Admin', 'Barbero']):
            return Cita.objects.all()
        return Cita.objects.filter(cliente=user)

    # Inyección automática del cliente logueado
    def perform_create(self, serializer):
        serializer.save(cliente=self.request.user)


# B. NUEVA VISTA: Para Editar (Punto 12) y Eliminar (Punto 13)
# RetrieveUpdateDestroyAPIView maneja GET (unitaria), PUT, PATCH y DELETE pasándole el ID en la URL
class CitaDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CitaSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.is_staff or (user.rol and user.rol.nombre in ['Admin', 'Barbero']):
            return Cita.objects.all()
        return Cita.objects.filter(cliente=user)