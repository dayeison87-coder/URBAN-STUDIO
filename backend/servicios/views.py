# servicios/views.py

from rest_framework import viewsets, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from .models import Categoria, Servicio
from .serializers import CategoriaSerializer, ServicioSerializer


# ── Vista pública: cualquiera puede ver categorías y servicios ──────────────

class CategoriaViewSet(viewsets.ReadOnlyModelViewSet):
    """
    GET /api/categorias/          → lista todas las categorías con sus servicios
    GET /api/categorias/{slug}/   → detalle de una categoría
    """
    queryset         = Categoria.objects.prefetch_related('servicios').all()
    serializer_class = CategoriaSerializer
    permission_classes = [AllowAny]
    lookup_field     = 'slug'


# ── Vistas de admin: solo usuarios autenticados ─────────────────────────────

class ServicioAdminViewSet(viewsets.ModelViewSet):
    """
    GET    /api/admin/servicios/        → listar todos
    POST   /api/admin/servicios/        → crear nuevo
    GET    /api/admin/servicios/{id}/   → detalle
    PUT    /api/admin/servicios/{id}/   → editar completo
    PATCH  /api/admin/servicios/{id}/   → editar parcial
    DELETE /api/admin/servicios/{id}/   → eliminar
    """
    queryset           = Servicio.objects.select_related('categoria').all()
    serializer_class   = ServicioSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = super().get_queryset()
        categoria = self.request.query_params.get('categoria')
        if categoria:
            qs = qs.filter(categoria__slug=categoria)
        return qs