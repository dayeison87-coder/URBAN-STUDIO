import logging

from django.core.files.base import ContentFile
from rest_framework import status
from rest_framework.parsers import MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from servicios.models import Servicio
from .models import AnalisisFacial
from .serializers import AnalisisFacialOutputSerializer
from .services.face_shape import analizar_rostro, RostroNoDetectadoError
from .services.gemini_client import analizar_cabello_y_recomendar
from .services.gemini_image import generar_preview_corte, GeneracionImagenError
from .services.prompts_cortes import obtener_prompt_corte

logger = logging.getLogger(__name__)


class AnalizarRostroView(APIView):
    """
    POST /api/servicios/analizar-rostro/
    Body: multipart/form-data con el campo "foto" (imagen del cliente).

    Flujo:
    1. MediaPipe calcula forma de rostro e índice cefálico (matemática, sin IA generativa).
    2. Gemini (texto) analiza tipo de cabello y redacta la recomendación.
    3. Gemini (imagen) genera la foto final con el corte puesto.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser]

    def post(self, request):
        foto = request.FILES.get("foto")
        if not foto:
            return Response(
                {"error": "Debes enviar una foto en el campo 'foto'."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        foto_bytes = foto.read()

        analisis = AnalisisFacial.objects.create(
            usuario=request.user,
            foto_original=ContentFile(foto_bytes, name=foto.name),
            estado="procesando",
        )

        try:
            # 1. Forma de rostro (geometría, MediaPipe)
            geometria = analizar_rostro(foto_bytes)
            analisis.forma_rostro = geometria["forma_rostro"]
            analisis.indice_cefalico = geometria["indice_cefalico"]
            analisis.medidas = geometria["medidas"]
            analisis.save()

            # 2. Tipo de cabello + recomendación (Gemini, texto)
            nombres_servicios = list(
                Servicio.objects.filter(categoria__slug="cabello", disponible=True)
                .values_list("nombre", flat=True)
            )
            analisis_ia_texto = analizar_cabello_y_recomendar(
                imagen_bytes=foto_bytes,
                forma_rostro=geometria["forma_rostro"],
                indice_cefalico=geometria["indice_cefalico"],
                nombres_servicios_disponibles=nombres_servicios,
            )

            analisis.tipo_cabello = analisis_ia_texto.get("tipo_cabello", "")
            analisis.descripcion_ia = analisis_ia_texto.get("descripcion_ia", "")
            analisis.nombre_corte_sugerido = analisis_ia_texto.get("nombre_corte_sugerido", "")

            nombre_catalogo = analisis_ia_texto.get("corte_del_catalogo")
            if nombre_catalogo:
                servicio = Servicio.objects.filter(nombre__iexact=nombre_catalogo).first()
                analisis.corte_recomendado = servicio

            analisis.save()

                        # 3. Imagen final con el corte puesto (Gemini, 1 sola imagen con 4 ángulos)

            prompt_corte = obtener_prompt_corte(
                analisis.nombre_corte_sugerido or "corte de cabello moderno"
            )

            print("======================================")
            print("IMAGEN QUE VA A GEMINI")
            print("Tamaño:", len(foto_bytes), "bytes")
            print("Primeros bytes:", foto_bytes[:20])
            print("======================================")

            imagen_resultado_bytes = generar_preview_corte(
                imagen_original_bytes=foto_bytes,
                prompt_corte=prompt_corte,
            )

            analisis.imagen_resultado.save(
                f"resultado_{analisis.id}.png",
                ContentFile(imagen_resultado_bytes),
                save=False,
            )

            analisis.estado = "completado"
            analisis.save()

        except (RostroNoDetectadoError, GeneracionImagenError) as e:
            analisis.estado = "error"
            analisis.error_detalle = str(e)
            analisis.save()
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        except Exception as e:
            logger.exception("Error analizando rostro")
            analisis.estado = "error"
            analisis.error_detalle = str(e)
            analisis.save()
            return Response(
                {"error": "Hubo un error al analizar el rostro. Inténtalo de nuevo."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        serializer = AnalisisFacialOutputSerializer(analisis, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)