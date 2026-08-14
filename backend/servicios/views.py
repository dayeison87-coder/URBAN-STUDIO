from rest_framework import viewsets, permissions
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework import status
from .models import Categoria, Servicio
from .serializers import CategoriaSerializer, ServicioSerializer
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