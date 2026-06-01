from django.urls import path
from .views import ServicioListCreateView

urlpatterns = [
    path(
        'servicios/',
        ServicioListCreateView.as_view(),
        name='servicios'
    ),
]