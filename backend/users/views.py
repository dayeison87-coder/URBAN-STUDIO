from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
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


# --- 3. VISTAS DE USUARIOS / BARBEROS ---
class UsuarioListCreateView(generics.ListCreateAPIView):
    queryset = Usuario.objects.all()
    serializer_class = UsuarioSerializer
    permission_classes = [IsAuthenticated]


# 🔥 NUEVA VISTA: Endpoint exclusivo para retornar solo Barberos dinámicamente
class BarberoListView(generics.ListAPIView):
    serializer_class = UsuarioSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # Filtra los usuarios cuyo campo 'rol' tenga el nombre exacto 'Barbero'
        return Usuario.objects.filter(rol__nombre='Barbero')


# --- 4. VISTAS DE CITAS ---

# A. Para Listar y Crear Citas
class CitaListCreateView(generics.ListCreateAPIView):
    serializer_class = CitaSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.is_staff or (user.rol and user.rol.nombre in ['Admin', 'Barbero']):
            return Cita.objects.all()
        return Cita.objects.filter(cliente=user)

    # 🛠️ Interceptamos el método de creación para rastrear errores en consola
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        if not serializer.is_valid():
            # 🔥 Esto te imprimirá detalladamente en la consola de Django el campo exacto que causa el 400
            print("❌ ERROR DE VALIDACIÓN EN CITAS:", serializer.errors)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)

    def perform_create(self, serializer):
        # El cliente se asigna automáticamente del token de sesión
        serializer.save(cliente=self.request.user)


# B. Para Editar (PUT/PATCH) y Eliminar (DELETE)
class CitaDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CitaSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.is_staff or (user.rol and user.rol.nombre in ['Admin', 'Barbero']):
            return Cita.objects.all()
        return Cita.objects.filter(cliente=user)

    # 🛠️ Rastreador también para las actualizaciones/ediciones
    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        if not serializer.is_valid():
            print("❌ ERROR DE VALIDACIÓN AL EDITAR CITA:", serializer.errors)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
        self.perform_update(serializer)
        return Response(serializer.data)