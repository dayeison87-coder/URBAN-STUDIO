from django.urls import include, path
from .views import (
    BarberoListView,
    CitaDetailView,
    PerfilBarberoView,
    PerfilClienteView,
    ConfiguracionCuentaView,
    ServicioListCreateView,
    UsuarioListCreateView,
    UsuarioDetailView,
    CitaListCreateView,
    RegisterView,
    SolicitarRegistroView,
    VerificarRegistroView,
    GoogleLoginView,
    GoogleCallbackView,
    GoogleTokenView,
    PerfilView,
    DisponibilidadView,        
    DisponibilidadDetailView,  
    BarberoDashboardView,
    CalificacionBarberoListCreateView,
    UltimosTestimoniosView  # 👈 1. Importamos la vista de testimonios globales
)
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

urlpatterns = [
    # --- 1. AUTENTICACIÓN Y REGISTRO ---
    path('register/', RegisterView.as_view(), name='register'),
    path('register/request-code/', SolicitarRegistroView.as_view(), name='register-request-code'),
    path('register/verify/', VerificarRegistroView.as_view(), name='register-verify'),
    path('auth/google/', GoogleLoginView.as_view(), name='google-login'),
    path('auth/google/token/', GoogleTokenView.as_view(), name='google-token'),
    path('auth/google/callback/', GoogleCallbackView.as_view(), name='google-callback'),
    path('login/', TokenObtainPairView.as_view(), name='login'),
    path('refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('perfil/', PerfilView.as_view(), name='perfil'),  
    path('perfil/barbero/', PerfilBarberoView.as_view(), name='perfil-barbero'),
    path('perfil/cliente/', PerfilClienteView.as_view(), name='perfil-cliente'),
    path('configuracion/cuenta/', ConfiguracionCuentaView.as_view(), name='configuracion-cuenta'),

    # --- 2. SERVICIOS Y USUARIOS ---
    path('servicios/', ServicioListCreateView.as_view(), name='servicios'),
    path('usuarios/', UsuarioListCreateView.as_view(), name='usuarios'),

    # --- 3. CRUD DE CITAS ---
    path('citas/', CitaListCreateView.as_view(), name='citas-list-create'),
    path('citas/<int:pk>/', CitaDetailView.as_view(), name='citas-detail'),

    # --- 4. BARBEROS Y DISPONIBILIDAD ---
    path('usuarios/barberos/', BarberoListView.as_view(), name='lista-barberos'),
    path('usuarios/<int:pk>/', UsuarioDetailView.as_view(), name='usuario-detail'),
    path('disponibilidad/', DisponibilidadView.as_view(), name='disponibilidad'),
    path('disponibilidad/<int:pk>/', DisponibilidadDetailView.as_view(), name='disponibilidad-detail'),
    path('barbero/dashboard/', BarberoDashboardView.as_view(), name='barbero-dashboard'),


    # --- 5. CALIFICACIONES Y RESEÑAS ---
    path('calificaciones/', CalificacionBarberoListCreateView.as_view(), name='calificaciones-list-create'),
    path('testimonios/ultimos/', UltimosTestimoniosView.as_view(), name='ultimos-testimonios'), # 👈 2. Ruta para el Home
      # 👈 Agrega esta línea para incluir las rutas de Gemini
]