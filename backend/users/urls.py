from django.urls import path
from .views import (
    BarberoListView,
    CitaDetailView,
    PerfilBarberoView,
    ServicioListCreateView,
    UsuarioListCreateView,
    UsuarioDetailView,
    CitaListCreateView,
    RegisterView,
    PerfilView,
    DisponibilidadView,        # 👈
    DisponibilidadDetailView ,  # 👈
    PerfilBarberoView
)
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)


urlpatterns = [
    # --- 1. AUTENTICACIÓN Y REGISTRO ---
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', TokenObtainPairView.as_view(), name='login'),
    path('refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('perfil/', PerfilView.as_view(), name='perfil'),  # 👈 agregado
    path('perfil/barbero/', PerfilBarberoView.as_view(), name='perfil-barbero'),

    # --- 2. SERVICIOS Y USUARIOS ---
    path('servicios/', ServicioListCreateView.as_view(), name='servicios'),
    path('usuarios/', UsuarioListCreateView.as_view(), name='usuarios'),

    # --- 3. CRUD DE CITAS ---
    path('citas/', CitaListCreateView.as_view(), name='citas-list-create'),
    path('citas/<int:pk>/', CitaDetailView.as_view(), name='citas-detail'),

    path('usuarios/barberos/', BarberoListView.as_view(), name='lista-barberos'),
    path('usuarios/<int:pk>/', UsuarioDetailView.as_view(), name='usuario-detail'),

    path('disponibilidad/', DisponibilidadView.as_view(), name='disponibilidad'),
    path('disponibilidad/<int:pk>/', DisponibilidadDetailView.as_view(), name='disponibilidad-detail'),
]