# servicios/urls.py

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import CategoriaViewSet, ServicioAdminViewSet


router = DefaultRouter()
router.register(r'categorias',       CategoriaViewSet,     basename='categoria')
router.register(r'admin/servicios',  ServicioAdminViewSet, basename='servicio-admin')

urlpatterns = [
    path('', include(router.urls)),
]