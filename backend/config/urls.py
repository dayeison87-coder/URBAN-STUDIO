# config/urls.py

from django.contrib import admin
from django.urls import path, include, re_path
from django.conf import settings
from django.views.static import serve
from django.http import JsonResponse
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)


def api_root(request):
    """Respuesta simple para la URL principal y el health check de Render."""
    return JsonResponse({"status": "ok", "service": "Urban Studio API"})


urlpatterns = [
    path('', api_root, name='api-root'),
    path('admin/', admin.site.urls),

    # Auth
    path('api/login/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/login/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

    # Users (rutas ya existentes en users)
    path('api/', include('users.urls')),

    # Análisis facial con IA (MediaPipe + Gemini + Stable Diffusion)
    path('api/', include('analisis_ia.urls')),

    # Servicios
    path('api/', include('servicios.urls')),
]

urlpatterns += [
    re_path(r'^media/(?P<path>.*)$', serve, {'document_root': settings.MEDIA_ROOT}),
]
