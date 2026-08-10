from django.db import models
from django.conf import settings


class AnalisisFacial(models.Model):
    """
    Guarda cada análisis de rostro que hace un cliente:
    foto que subió, lo que detectó la IA, y el corte recomendado.
    """

    FORMAS_ROSTRO = [
        ("ovalado", "Ovalado"),
        ("redondo", "Redondo"),
        ("cuadrado", "Cuadrado"),
        ("corazon", "Corazón"),
        ("alargado", "Alargado / Oblongo"),
        ("diamante", "Diamante"),
        ("triangular", "Triangular"),
    ]

    INDICES_CEFALICOS = [
        ("dolicocefalo", "Dolicocéfalo (cabeza alargada)"),
        ("mesocefalo", "Mesocéfalo (cabeza proporcionada)"),
        ("braquicefalo", "Braquicéfalo (cabeza ancha)"),
    ]

    TIPOS_CABELLO = [
        ("1a", "1A - Liso fino"),
        ("1b", "1B - Liso medio"),
        ("1c", "1C - Liso grueso"),
        ("2a", "2A - Ondulado suave"),
        ("2b", "2B - Ondulado medio"),
        ("2c", "2C - Ondulado definido"),
        ("3a", "3A - Rizado suelto"),
        ("3b", "3B - Rizado medio"),
        ("3c", "3C - Rizado apretado"),
        ("4a", "4A - Afro suave"),
        ("4b", "4B - Afro definido"),
        ("4c", "4C - Afro muy apretado"),
    ]

    ESTADOS = [
        ("procesando", "Procesando"),
        ("completado", "Completado"),
        ("error", "Error"),
    ]

    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="analisis_faciales",
    )

    # Entrada del cliente
    foto_original = models.ImageField(upload_to="analisis_ia/originales/")

    # Resultado del análisis geométrico (MediaPipe, sin IA generativa)
    forma_rostro = models.CharField(max_length=20, choices=FORMAS_ROSTRO, blank=True)
    indice_cefalico = models.CharField(max_length=20, choices=INDICES_CEFALICOS, blank=True)
    medidas = models.JSONField(blank=True, null=True)  # proporciones calculadas, para depurar/mejorar el modelo luego

    # Resultado del análisis con Gemini (visión)
    tipo_cabello = models.CharField(max_length=5, choices=TIPOS_CABELLO, blank=True)
    descripcion_ia = models.TextField(blank=True)  # explicación en lenguaje natural

    # Recomendación (ligada a tu catálogo real de servicios)
    corte_recomendado = models.ForeignKey(
        "servicios.Servicio",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="recomendaciones_ia",
    )
    nombre_corte_sugerido = models.CharField(max_length=100, blank=True)  # texto libre si no matchea con el catálogo

    # Imagen generada (preview del corte puesto en la cara real)
    imagen_resultado = models.ImageField(upload_to="analisis_ia/resultados/", blank=True, null=True)
    imagen_resultado_perfil = models.ImageField(upload_to="analisis_ia/resultados/", blank=True, null=True)

    estado = models.CharField(max_length=20, choices=ESTADOS, default="procesando")
    error_detalle = models.TextField(blank=True)

    creado_en = models.DateTimeField(auto_now_add=True)
    actualizado_en = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-creado_en"]

    def __str__(self):
        return f"Análisis #{self.pk} - {self.usuario.username} - {self.estado}"
