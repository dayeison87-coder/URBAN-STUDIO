# config/urls.py

from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

urlpatterns = [
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

if settings.DEBUG:
    from django.urls import re_path
    from django.views.static import serve
    urlpatterns += [
        re_path(r'^media/(?P<path>.*)$', serve, {'document_root': settings.MEDIA_ROOT}),
    ]
    # resto del código...