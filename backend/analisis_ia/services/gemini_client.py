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

from google import genai
from google.genai import types

MODELO_TEXTO = "gemini-3.6-flash"

def _get_client():
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("Falta configurar GEMINI_API_KEY en las variables de entorno (.env)")
    return genai.Client(api_key=api_key)


def analizar_cabello_y_recomendar(
    imagen_bytes: bytes,
    forma_rostro: str,
    indice_cefalico: str,
    nombres_servicios_disponibles: list[str],
) -> dict:
    """
    Devuelve:
    {
        "tipo_cabello": "1a" | "1b" | ... | "4c",
        "nombre_corte_sugerido": "texto libre, ej: Mohicano bajo",
        "corte_del_catalogo": "nombre EXACTO de servicios_disponibles si aplica, o null",
        "descripcion_ia": "explicación en español para mostrarle al cliente"
    }
    """
    client = _get_client()

    catalogo_txt = ", ".join(nombres_servicios_disponibles) if nombres_servicios_disponibles else "(sin catálogo cargado)"

    prompt = f"""
Eres un barbero senior con 15 años de experiencia, especialista en asesoría de imagen masculina.
Te doy una foto de un cliente y dos datos ya calculados matemáticamente a partir de su rostro:
- Forma de rostro: {forma_rostro}
- Índice cefálico: {indice_cefalico}

Guía de criterios profesionales por forma de rostro (úsala para razonar, no la repitas literalmente):
- Ovalado: es la forma más versátil, casi cualquier corte funciona; evita ocultarlo con demasiado volumen.
- Redondo: busca dar altura y angularidad (volumen arriba, laterales cortos/fade) para alargar visualmente el rostro; evita cortes muy redondeados en la parte superior.
- Cuadrado: suaviza los ángulos marcados de la mandíbula con texturas y flequillos suaves; evita cortes muy geométricos que refuercen la cuadratura.
- Corazón: la frente es más ancha que la mandíbula; evita volumen extra en la parte superior/frontal (agrandaría la frente), y en cambio da algo de definición hacia los laterales bajos y la barbilla para equilibrar.
- Alargado/oblongo: evita mucho volumen vertical arriba (alarga aún más el rostro); prioriza cortes con volumen a los lados o flequillo horizontal.
- Diamante: pómulos anchos con frente y mandíbula más estrechas; suaviza los pómulos con textura a los lados y algo de volumen en frente y mentón.
- Triangular: mandíbula más ancha que la frente; da volumen y textura en la parte superior para equilibrar, mantén los laterales/mandíbula más definidos.

Catálogo de cortes que ofrece esta barbería: {catalogo_txt}

Tu tarea:
1. Observa la foto y clasifica el tipo de cabello según la escala estándar (1a-4c).
2. Piensa en 2 o 3 opciones de corte razonables para esta combinación específica de forma de
   rostro, índice cefálico y tipo de cabello, aplicando los criterios de arriba. Luego elige la
   MEJOR de esas opciones — la más específica y justificada para esta persona en particular, no
   una respuesta genérica que darías para cualquier cliente con esa forma de rostro.
3. Si alguno de los cortes del catálogo de arriba es una opción sólida, úsalo tal cual (copia el
   nombre exacto). Si ninguno aplica bien, sugiere uno nuevo con nombre común y específico (ej.
   "Mohicano bajo", "Corte texturizado con fade medio", "Crop francés con fringe").
4. Escribe una explicación de 3-4 frases, en español, tono amable y profesional de barbero,
   mencionando explícitamente CÓMO el corte responde a la forma de rostro y el índice cefálico de
   esta persona (no una descripción genérica del corte).

Responde ÚNICAMENTE con un JSON válido, sin texto adicional, sin backticks, con esta forma exacta:
{{
  "tipo_cabello": "...",
  "nombre_corte_sugerido": "...",
  "corte_del_catalogo": "... o null si no aplica ninguno del catálogo",
  "descripcion_ia": "..."
}}
"""

    respuesta = client.models.generate_content(
        model=MODELO_TEXTO,
        contents=[
            types.Part.from_bytes(data=imagen_bytes, mime_type="image/jpeg"),
            prompt,
        ],
        config=types.GenerateContentConfig(
            temperature=0.4,
        ),
    )

    texto = respuesta.text.strip()
    # Por si el modelo agrega backticks de markdown a pesar de la instrucción:
    texto = texto.removeprefix("```json").removeprefix("```").removesuffix("```").strip()

    return json.loads(texto)
