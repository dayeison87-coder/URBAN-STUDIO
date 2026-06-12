from django.urls import path

from .views import (
    ServicioListCreateView,
    UsuarioListCreateView,
    CitaListCreateView,
    RegisterView
)

urlpatterns = [
    path('servicios/', ServicioListCreateView.as_view(), name='servicios'),

    path('usuarios/', UsuarioListCreateView.as_view(), name='usuarios'),
    
    path('citas/', CitaListCreateView.as_view(), name='citas'),

    path(
        'register/',
        RegisterView.as_view(),
        name='register'
    ),
]