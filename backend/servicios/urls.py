# servicios/urls.py

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    CategoriaViewSet, ServicioAdminViewSet, ProductoAdminViewSet, OrdenProductoViewSet,
)


router = DefaultRouter()
router.register(r'categorias',       CategoriaViewSet,     basename='categoria')
router.register(r'admin/servicios',  ServicioAdminViewSet, basename='servicio-admin')
router.register(r'admin/productos', ProductoAdminViewSet, basename='producto-admin')
router.register(r'ordenes-productos', OrdenProductoViewSet, basename='orden-producto')

urlpatterns = [
    path('', include(router.urls)),
   
    
]