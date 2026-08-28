import logging

from django.core.files.base import ContentFile

from rest_framework import status
from rest_framework.parsers import MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from servicios.models import Servicio

from .models import AnalisisFacial, CodigoSeguridadIA
from .serializers import AnalisisFacialOutputSerializer
from .services.codigo_seguridad import generar_codigo_seguridad
from .services.face_shape import analizar_rostro, RostroNoDetectadoError
from .services.gemini_client import analizar_cabello_y_recomendar
from .services.gemini_image import (
    generar_preview_corte,
    GeneracionImagenError
)
from .services.prompts_cortes import obtener_prompt_corte


logger = logging.getLogger(__name__)


# ==================================================
# SOLICITAR CÓDIGO DE SEGURIDAD
# ==================================================

class SolicitarCodigoIAView(APIView):
    """
    Genera y envía un código de seguridad de 6 dígitos.
    El código tiene una duración de 4 minutos.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        usuario = request.user

        if not usuario.email:
            return Response(
                {
                    "error": (
                        "Tu usuario no tiene un correo electrónico "
                        "registrado."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            generar_codigo_seguridad(usuario)

            return Response(
                {
                    "mensaje": (
                        "Código de seguridad enviado correctamente "
                        "a tu correo."
                    ),
                    "duracion_minutos": 4
                },
                status=status.HTTP_200_OK
            )

        except Exception:
            logger.exception(
                "Error enviando código de seguridad"
            )

            return Response(
                {
                    "error": (
                        "No fue posible enviar el código "
                        "de seguridad."
                    )
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


# ==================================================
# VALIDAR CÓDIGO DE SEGURIDAD
# ==================================================

class ValidarCodigoIAView(APIView):
    """
    Valida el código de seguridad enviado al correo.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):

        codigo = request.data.get("codigo")

        if not codigo:
            return Response(
                {
                    "error": (
                        "Debes ingresar el código de seguridad."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        codigo = str(codigo).strip()

        codigo_seguridad = (
            CodigoSeguridadIA.objects.filter(
                usuario=request.user,
                codigo=codigo,
                usado=False
            )
            .order_by("-creado_en")
            .first()
        )

        if not codigo_seguridad:
            return Response(
                {
                    "error": (
                        "El código ingresado no es válido."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Verificar si venció
        if codigo_seguridad.esta_vencido():

            codigo_seguridad.usado = True
            codigo_seguridad.save()

            return Response(
                {
                    "error": (
                        "El código ha vencido. "
                        "Solicita uno nuevo."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Verificar si ya fue validado
        if codigo_seguridad.validado:

            return Response(
                {
                    "error": (
                        "Este código ya fue utilizado."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Marcar como validado
        codigo_seguridad.validado = True
        codigo_seguridad.save()

        return Response(
            {
                "mensaje": (
                    "Código validado correctamente."
                ),
                "validado": True
            },
            status=status.HTTP_200_OK
        )


# ==================================================
# ANALIZAR ROSTRO CON IA
# ==================================================

class AnalizarRostroView(APIView):
    """
    POST /api/servicios/analizar-rostro/

    Antes de usar la IA, el usuario debe tener un
    código de seguridad validado y vigente.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser]

    def post(self, request):

        # ==========================================
        # 1. VERIFICAR CÓDIGO DE SEGURIDAD
        # ==========================================

        codigo_seguridad = (
            CodigoSeguridadIA.objects.filter(
                usuario=request.user,
                validado=True,
                usado=False
            )
            .order_by("-creado_en")
            .first()
        )

        if not codigo_seguridad:

            return Response(
                {
                    "error": (
                        "Debes validar un código de seguridad "
                        "antes de utilizar la IA."
                    )
                },
                status=status.HTTP_403_FORBIDDEN
            )

        # Verificar nuevamente que no haya vencido
        if codigo_seguridad.esta_vencido():

            codigo_seguridad.usado = True
            codigo_seguridad.save()

            return Response(
                {
                    "error": (
                        "Tu código de seguridad ha vencido. "
                        "Solicita uno nuevo."
                    )
                },
                status=status.HTTP_403_FORBIDDEN
            )

        # ==========================================
        # 2. OBTENER LA FOTO
        # ==========================================

        foto = request.FILES.get("foto")

        if not foto:

            return Response(
                {
                    "error": (
                        "Debes enviar una foto "
                        "en el campo 'foto'."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        foto_bytes = foto.read()

        # ==========================================
        # 3. CREAR ANÁLISIS
        # ==========================================

        analisis = AnalisisFacial.objects.create(
            usuario=request.user,
            foto_original=ContentFile(
                foto_bytes,
                name=foto.name
            ),
            estado="procesando",
        )

        try:

            # ======================================
            # 4. ANALIZAR FORMA DEL ROSTRO
            # ======================================

            geometria = analizar_rostro(
                foto_bytes
            )

            analisis.forma_rostro = (
                geometria["forma_rostro"]
            )

            analisis.indice_cefalico = (
                geometria["indice_cefalico"]
            )

            analisis.medidas = (
                geometria["medidas"]
            )

            analisis.save()

            # ======================================
            # 5. ANALIZAR CABELLO CON GEMINI
            # ======================================

            nombres_servicios = list(
                Servicio.objects.filter(
                    categoria__slug="cabello",
                    disponible=True
                ).values_list(
                    "nombre",
                    flat=True
                )
            )

            analisis_ia_texto = (
                analizar_cabello_y_recomendar(
                    imagen_bytes=foto_bytes,
                    forma_rostro=(
                        geometria["forma_rostro"]
                    ),
                    indice_cefalico=(
                        geometria["indice_cefalico"]
                    ),
                    nombres_servicios_disponibles=(
                        nombres_servicios
                    ),
                )
            )

            analisis.tipo_cabello = (
                analisis_ia_texto.get(
                    "tipo_cabello",
                    ""
                )
            )

            analisis.descripcion_ia = (
                analisis_ia_texto.get(
                    "descripcion_ia",
                    ""
                )
            )

            analisis.nombre_corte_sugerido = (
                analisis_ia_texto.get(
                    "nombre_corte_sugerido",
                    ""
                )
            )

            nombre_catalogo = (
                analisis_ia_texto.get(
                    "corte_del_catalogo"
                )
            )

            if nombre_catalogo:
                servicio = (
                    Servicio.objects.filter(
                        nombre__iexact=nombre_catalogo
                    ).first()
                )

                analisis.corte_recomendado = (
                    servicio
                )

            analisis.save()

            # ======================================
            # 6. GENERAR IMAGEN DEL CORTE
            # ======================================

            prompt_corte = obtener_prompt_corte(
                analisis.nombre_corte_sugerido
                or "corte de cabello moderno"
            )

            imagen_resultado_bytes = (
                generar_preview_corte(
                    imagen_original_bytes=foto_bytes,
                    prompt_corte=prompt_corte,
                )
            )

            analisis.imagen_resultado.save(
                f"resultado_{analisis.id}.png",
                ContentFile(
                    imagen_resultado_bytes
                ),
                save=False,
            )

            analisis.estado = "completado"
            analisis.save()

            # ======================================
            # 7. MARCAR CÓDIGO COMO USADO
            # ======================================

            codigo_seguridad.usado = True
            codigo_seguridad.save()

        except (
            RostroNoDetectadoError,
            GeneracionImagenError
        ) as e:

            analisis.estado = "error"
            analisis.error_detalle = str(e)
            analisis.save()

            return Response(
                {
                    "error": str(e)
                },
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            logger.exception(
                "Error analizando rostro"
            )
            analisis.estado = "error"
            analisis.error_detalle = str(e)
            analisis.save()
            return Response(
                {
                    "error": (
                        "Hubo un error al analizar "
                        "el rostro. Inténtalo de nuevo."
                    )
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        serializer = AnalisisFacialOutputSerializer(
            analisis,
            context={"request": request}
        )
        return Response(
            serializer.data,
            status=status.HTTP_200_OK
        )