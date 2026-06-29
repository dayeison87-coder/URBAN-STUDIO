# config/urls.py

from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

urlpatterns = [
    path('admin/', admin.site.urls),

    # Auth
    path('api/login/',          TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/login/refresh/',  TokenRefreshView.as_view(),    name='token_refresh'),

    # Users (tus rutas existentes)
    path('api/', include('users.urls')),

    # Servicios (nuevas rutas)
    path('api/', include('servicios.urls')),
]