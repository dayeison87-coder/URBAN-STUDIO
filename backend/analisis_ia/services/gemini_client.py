"""
Usa la API de Gemini (capa gratuita, modelos Flash) para:

1. Describir el tipo de cabello del cliente a partir de la foto.
2. Redactar una recomendación de corte en lenguaje natural, tomando en
   cuenta la forma de rostro/cabello ya calculada por MediaPipe y el
   catálogo real de servicios de la barbería.

No entrena nada: usa el modelo ya entrenado por Google a través de su API.
"""

import os
import json
import re


MODELO_TEXTO = "gemini-3.6-flash"
TIPOS_CABELLO_VALIDOS = {
    "1a", "1b", "1c", "2a", "2b", "2c",
    "3a", "3b", "3c", "4a", "4b", "4c",
}


def _normalizar_tipo_cabello(valor) -> str:
    """Keep the compact 1a-4c code even if Gemini adds a description."""
    coincidencia = re.search(r"\b([1-4][abc])\b", str(valor or "").lower())
    if coincidencia and coincidencia.group(1) in TIPOS_CABELLO_VALIDOS:
        return coincidencia.group(1)
    return ""


def _get_client():
    """
    Crea el cliente de Gemini solamente cuando realmente se necesita.
    Esto evita cargar google.genai durante el arranque de Django.
    """
    from google import genai

    api_key = os.environ.get("GEMINI_API_KEY")

    if not api_key:
        raise RuntimeError(
            "Falta configurar GEMINI_API_KEY en las variables de entorno"
        )

    return genai.Client(api_key=api_key)


def analizar_cabello_y_recomendar(
    imagen_bytes: bytes,
    forma_rostro: str,
    indice_cefalico: str,
    nombres_servicios_disponibles: list[str],
) -> dict:
    """
    Analiza una fotografía del cliente y devuelve:

    {
        "tipo_cabello": "1a" | "1b" | ... | "4c",
        "nombre_corte_sugerido": "texto libre",
        "corte_del_catalogo": "nombre EXACTO del servicio o null",
        "descripcion_ia": "explicación en español"
    }
    """

    # Importamos Gemini solamente cuando se llama esta función.
    from google.genai import types

    client = _get_client()

    catalogo_txt = (
        ", ".join(nombres_servicios_disponibles)
        if nombres_servicios_disponibles
        else "(sin catálogo cargado)"
    )

    prompt = f"""
Eres un barbero senior con 15 años de experiencia, especialista en
asesoría de imagen masculina.

Te doy una foto de un cliente y dos datos ya calculados matemáticamente
a partir de su rostro:

- Forma de rostro: {forma_rostro}
- Índice cefálico: {indice_cefalico}

Guía de criterios profesionales por forma de rostro
(úsala para razonar, no la repitas literalmente):

- Ovalado: es la forma más versátil, casi cualquier corte funciona;
  evita ocultarlo con demasiado volumen.

- Redondo: busca dar altura y angularidad (volumen arriba, laterales
  cortos/fade) para alargar visualmente el rostro; evita cortes muy
  redondeados en la parte superior.

- Cuadrado: suaviza los ángulos marcados de la mandíbula con texturas
  y flequillos suaves; evita cortes muy geométricos que refuercen
  la cuadratura.

- Corazón: la frente es más ancha que la mandíbula; evita volumen
  extra en la parte superior/frontal (agrandaría la frente), y en
  cambio da algo de definición hacia los laterales bajos y la barbilla
  para equilibrar.

- Alargado/oblongo: evita mucho volumen vertical arriba (alarga aún
  más el rostro); prioriza cortes con volumen a los lados o flequillo
  horizontal.

- Diamante: pómulos anchos con frente y mandíbula más estrechas;
  suaviza los pómulos con textura a los lados y algo de volumen en
  frente y mentón.

- Triangular: mandíbula más ancha que la frente; da volumen y textura
  en la parte superior para equilibrar, mantén los laterales/mandíbula
  más definidos.

Catálogo de cortes que ofrece esta barbería:
{catalogo_txt}

Tu tarea:

1. Observa la foto y clasifica el tipo de cabello según la escala
   estándar (1a-4c).

2. Piensa en 2 o 3 opciones de corte razonables para esta combinación
   específica de forma de rostro, índice cefálico y tipo de cabello,
   aplicando los criterios de arriba.

3. Luego elige la opción más específica y justificada para esta persona
   en particular, evitando una respuesta genérica que darías para
   cualquier cliente con esa forma de rostro.

4. Si alguno de los cortes del catálogo de arriba es una opción sólida,
   úsalo tal cual y copia el nombre exacto.

5. Si ninguno aplica bien, sugiere uno nuevo con nombre común y específico.
   Ejemplos:
   - "Mohicano bajo"
   - "Corte texturizado con fade medio"
   - "Crop francés con fringe"

6. Escribe una explicación de 3-4 frases, en español, con tono amable
   y profesional de barbero.

7. La explicación debe mencionar explícitamente CÓMO el corte responde
   a la forma de rostro y al índice cefálico de esta persona.

Responde ÚNICAMENTE con un JSON válido.

No agregues texto antes ni después del JSON.
No uses bloques de código.
No uses markdown.

La estructura debe ser exactamente:

{{
    "tipo_cabello": "solo uno de: 1a, 1b, 1c, 2a, 2b, 2c, 3a, 3b, 3c, 4a, 4b o 4c",
    "nombre_corte_sugerido": "...",
    "corte_del_catalogo": "... o null si no aplica ninguno del catálogo",
    "descripcion_ia": "..."
}}
"""

    respuesta = client.models.generate_content(
        model=MODELO_TEXTO,
        contents=[
            types.Part.from_bytes(
                data=imagen_bytes,
                mime_type="image/jpeg",
            ),
            prompt,
        ],
        config=types.GenerateContentConfig(
            temperature=0.4,
        ),
    )

    texto = respuesta.text.strip()

    # Por si Gemini devuelve el JSON dentro de un bloque markdown.
    if texto.startswith("```json"):
        texto = texto[7:]

    if texto.startswith("```"):
        texto = texto[3:]

    if texto.endswith("```"):
        texto = texto[:-3]

    texto = texto.strip()

    resultado = json.loads(texto)
    resultado["tipo_cabello"] = _normalizar_tipo_cabello(
        resultado.get("tipo_cabello")
    )
    return resultado
