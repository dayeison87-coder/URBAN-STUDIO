from django.urls import path

from .views import (
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

    path(
        'citas/',
        CitaListCreateView.as_view(),
        name='citas'
    ),

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
]