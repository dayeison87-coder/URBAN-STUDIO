from rest_framework import viewsets, permissions
from rest_framework.decorators import api_view, permission_classes, parser_classes, action
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework import status
from django.db import transaction
import logging
from .models import Categoria, Servicio, Producto, OrdenProducto, DetalleOrdenProducto
from .serializers import (
    CategoriaSerializer, ServicioSerializer, ProductoSerializer, OrdenProductoSerializer,
)
from .gemini_service import analizar_rostro_con_ia

logger = logging.getLogger(__name__)


class IsUrbanStudioAdmin(permissions.BasePermission):
    """Permite administrar el catálogo a usuarios Django o con rol Admin."""

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and (
                user.is_staff
                or user.is_superuser
                or (user.rol and user.rol.nombre == 'Admin')
            )
        )


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
    permission_classes = [IsUrbanStudioAdmin]

    def get_queryset(self):
        qs = super().get_queryset()
        categoria = self.request.query_params.get('categoria')
        if categoria:
            qs = qs.filter(categoria__slug=categoria)
        return qs


class ProductoAdminViewSet(viewsets.ModelViewSet):
    queryset = Producto.objects.select_related('categoria').all()
    serializer_class = ProductoSerializer
    permission_classes = [IsUrbanStudioAdmin]
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def get_queryset(self):
        qs = super().get_queryset()
        categoria = self.request.query_params.get('categoria')
        return qs.filter(categoria__slug=categoria) if categoria else qs

    def create(self, request, *args, **kwargs):
        try:
            return super().create(request, *args, **kwargs)
        except (OSError, ValueError) as exc:
            logger.exception('Error de almacenamiento al crear producto')
            return Response(
                {'detail': f'No se pudo guardar la imagen del producto: {exc}'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        except Exception:
            logger.exception('Error inesperado al crear producto')
            return Response(
                {'detail': 'El servidor no pudo guardar el producto. Revisa los logs de Render.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    def update(self, request, *args, **kwargs):
        try:
            return super().update(request, *args, **kwargs)
        except (OSError, ValueError) as exc:
            logger.exception('Error de almacenamiento al actualizar producto')
            return Response(
                {'detail': f'No se pudo guardar la imagen del producto: {exc}'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        except Exception:
            logger.exception('Error inesperado al actualizar producto')
            return Response(
                {'detail': 'El servidor no pudo actualizar el producto. Revisa los logs de Render.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class OrdenProductoViewSet(viewsets.ModelViewSet):
    serializer_class = OrdenProductoSerializer
    permission_classes = [IsAuthenticated]
    http_method_names = ['get', 'post', 'patch', 'head', 'options']

    def get_queryset(self):
        queryset = OrdenProducto.objects.prefetch_related('items__producto')
        if self._es_admin():
            return queryset.order_by('-creado_en')
        return queryset.filter(cliente=self.request.user).order_by('-creado_en')

    def _es_admin(self):
        user = self.request.user
        return bool(
            user.is_staff or user.is_superuser
            or (user.rol and user.rol.nombre == 'Admin')
        )

    def update(self, request, *args, **kwargs):
        if not self._es_admin():
            return Response(
                {'detail': 'Solo un administrador puede cambiar el estado.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        order = self.get_object()
        nuevo_estado = request.data.get('estado')
        estados_validos = {choice[0] for choice in OrdenProducto.ESTADOS}
        if nuevo_estado not in estados_validos:
            return Response(
                {'estado': 'Estado no válido.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if nuevo_estado != 'retirada':
            return Response(
                {'detail': 'El apartado solo puede marcarse como pago y recogido.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if order.estado != 'pendiente':
            return Response(
                {'detail': 'Este apartado ya no se puede editar.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        order.estado = nuevo_estado
        order.save(update_fields=['estado', 'actualizado'])
        return Response(self.get_serializer(order).data)

    @action(detail=True, methods=['post'])
    def cancelar(self, request, pk=None):
        order = self.get_object()
        if self._es_admin() or order.cliente_id != request.user.id:
            pass
        elif order.estado != 'pendiente':
            return Response(
                {'detail': 'Solo puedes cancelar apartados pendientes de pago.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        else:
            self._cancelar_y_devolver_inventario(order)
            return Response(self.get_serializer(order).data)
        return Response(
            {'detail': 'Usa el cambio de estado desde el panel administrativo.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    @transaction.atomic
    def _cancelar_y_devolver_inventario(self, order):
        for item in order.items.select_related('producto').select_for_update():
            product = item.producto
            product.inventario += item.cantidad
            product.save(update_fields=['inventario', 'actualizado'])
        order.estado = 'cancelada'
        order.save(update_fields=['estado', 'actualizado'])

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