from django.urls import path
from .views import AnalizarRostroView

urlpatterns = [
    path("servicios/analizar-rostro/", AnalizarRostroView.as_view(), name="analizar-rostro"),
]
