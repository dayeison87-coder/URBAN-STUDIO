from django.urls import path
from .views import (
    CitaDetailView,
    ServicioListCreateView,
    UsuarioListCreateView,
    CitaListCreateView,
    RegisterView
)
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

urlpatterns = [
    # --- 1. AUTENTICACIÓN Y REGISTRO ---
    path(
        'register/',
        RegisterView.as_view(),
        name='register'
    ),
    path(
        'login/',
        TokenObtainPairView.as_view(),
        name='login'
    ),
    path(
        'refresh/',
        TokenRefreshView.as_view(),
        name='token_refresh'
    ),

    # --- 2. SERVICIOS Y USUARIOS ---
    path(
        'servicios/',
        ServicioListCreateView.as_view(),
        name='servicios'
    ),
    path(
        'usuarios/',
        UsuarioListCreateView.as_view(),
        name='usuarios'
    ),

    # --- 3. CRUD DE CITAS (UNIFICADO) ---
    path(
        'citas/', 
        CitaListCreateView.as_view(), 
        name='citas-list-create'
    ), # GET (Listar) y POST (Crear)
    
    path(
        'citas/<int:pk>/', 
        CitaDetailView.as_view(), 
        name='citas-detail'
    ), # GET (Individual), PUT/PATCH (Editar) y DELETE (Eliminar)
]