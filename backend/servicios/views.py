from rest_framework import viewsets, permissions
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework import status
from django.db import transaction
from .models import Categoria, Servicio, Producto, OrdenProducto, DetalleOrdenProducto
from .serializers import (
    CategoriaSerializer, ServicioSerializer, ProductoSerializer, OrdenProductoSerializer,
)
from .gemini_service import analizar_rostro_con_ia


# ── Vista pública: cualquiera puede ver categorías y servicios ──────────────

class CategoriaViewSet(viewsets.ReadOnlyModelViewSet):
    """
    GET /api/categorias/        → lista todas las categorías con sus servicios
    GET /api/categorias/{slug}/   → detalle de una categoría
    """
    queryset         = Categoria.objects.prefetch_related('servicios').all()
    serializer_class = CategoriaSerializer
    permission_classes = [AllowAny]
    lookup_field     = 'slug'


# ── Vistas de admin: solo usuarios autenticados ─────────────────────────────

class ServicioAdminViewSet(viewsets.ModelViewSet):
    """
    GET     /api/admin/servicios/        → listar todos
    POST    /api/admin/servicios/        → crear nuevo
    GET     /api/admin/servicios/{id}/   → detalle
    PUT     /api/admin/servicios/{id}/   → editar completo
    PATCH   /api/admin/servicios/{id}/   → editar parcial
    DELETE  /api/admin/servicios/{id}/   → eliminar
    """
    queryset             = Servicio.objects.select_related('categoria').all()
    serializer_class     = ServicioSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = super().get_queryset()
        categoria = self.request.query_params.get('categoria')
        if categoria:
            qs = qs.filter(categoria__slug=categoria)
        return qs


class ProductoAdminViewSet(viewsets.ModelViewSet):
    queryset = Producto.objects.select_related('categoria').all()
    serializer_class = ProductoSerializer
    permission_classes = [permissions.IsAdminUser]
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def get_queryset(self):
        qs = super().get_queryset()
        categoria = self.request.query_params.get('categoria')
        return qs.filter(categoria__slug=categoria) if categoria else qs


class OrdenProductoViewSet(viewsets.ModelViewSet):
    serializer_class = OrdenProductoSerializer
    permission_classes = [IsAuthenticated]
    http_method_names = ['get', 'post', 'head', 'options']

    def get_queryset(self):
        return OrdenProducto.objects.filter(cliente=self.request.user).prefetch_related(
            'items__producto'
        ).order_by('-creado_en')

    @transaction.atomic
    def create(self, request, *args, **kwargs):
        items = request.data.get('items', [])
        if not isinstance(items, list) or not items:
            return Response({'items': 'Debes seleccionar al menos un producto.'},
                            status=status.HTTP_400_BAD_REQUEST)
        order = OrdenProducto.objects.create(cliente=request.user)
        total = 0
        try:
            for item in items:
                product_id = item.get('producto')
                quantity = int(item.get('cantidad', 0))
                if quantity < 1:
                    raise ValueError('La cantidad debe ser mayor que cero.')
                product = Producto.objects.select_for_update().get(
                    pk=product_id, disponible=True
                )
                if product.inventario < quantity:
                    raise ValueError(f'No hay inventario suficiente para {product.nombre}.')
                product.inventario -= quantity
                product.save(update_fields=['inventario', 'actualizado'])
                DetalleOrdenProducto.objects.create(
                    orden=order, producto=product, cantidad=quantity,
                    precio_unitario=product.precio,
                )
                total += product.precio * quantity
        except (Producto.DoesNotExist, ValueError) as exc:
            transaction.set_rollback(True)
            order.delete()
            return Response({'detail': str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        order.total = total
        order.save(update_fields=['total', 'actualizado'])
        return Response(self.get_serializer(order).data, status=status.HTTP_201_CREATED)


# ── Vista de Inteligencia Artificial: Análisis de Rostro ────────────────────

@api_view(['POST'])
@permission_classes([AllowAny]) # Cambia a [IsAuthenticated] si prefieres que solo usuarios logueados usen la IA
@parser_classes([MultiPartParser, FormParser])
def analizar_rostro_view(request):
    """
    POST /api/servicios/analizar-rostro/ → Recibe una imagen ('imagen') y retorna el JSON con el análisis morfológico.
    """
    image_file = request.FILES.get('imagen')
    
    if not image_file:
        return Response({"error": "No se ha proporcionado ninguna imagen."}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        resultado = analizar_rostro_con_ia(image_file)
        return Response({"success": True, "data": resultado}, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({"success": False, "error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)