from django.urls import path

from .views import (
    AnalizarRostroView,
    SolicitarCodigoIAView,
    ValidarCodigoIAView,
)


urlpatterns = [

    path(
        "servicios/analizar-rostro/",
        AnalizarRostroView.as_view(),
        name="analizar-rostro"
    ),

    path(
        "solicitar-codigo-ia/",
        SolicitarCodigoIAView.as_view(),
        name="solicitar-codigo-ia"
    ),

    path(
        "validar-codigo-ia/",
        ValidarCodigoIAView.as_view(),
        name="validar-codigo-ia"
    ),

]