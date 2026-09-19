"""
Usa la API de Gemini (capa gratuita, modelos Flash) para:

1. Describir el tipo de cabello del cliente a partir de la foto.
2. Redactar una recomendación de corte en lenguaje natural, tomando en
   cuenta la forma de rostro/cabello ya calculada por MediaPipe y el
   catálogo real de servicios de la barbería.
3. Detectar si el cliente tiene barba (para no inventarla en la imagen).
4. Construir un prompt de edición de imagen que conserve el rostro.
"""

import os
import json
import re
import random
import time


MODELO_TEXTO = "gemini-3.6-flash"
TIPOS_CABELLO_VALIDOS = {
    "1a", "1b", "1c", "2a", "2b", "2c",
    "3a", "3b", "3c", "4a", "4b", "4c",
}


def _detectar_mime_type_imagen(imagen_bytes: bytes) -> str:
    if not imagen_bytes:
        raise ValueError("La imagen recibida está vacía.")

    if imagen_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if imagen_bytes.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if imagen_bytes.startswith(b"GIF87a") or imagen_bytes.startswith(b"GIF89a"):
        return "image/gif"
    if imagen_bytes.startswith(b"RIFF") and imagen_bytes[8:12] == b"WEBP":
        return "image/webp"
    return "image/jpeg"

# Cada petición recibe UN enfoque distinto al azar. Esto obliga al modelo
# a salir del "corte clásico" que siempre elige por defecto.
ENFOQUES_ESTILO = [
    "texturizado y desenfadado, con movimiento natural",
    "moderno y atrevido, con contraste marcado entre laterales y parte superior",
    "elegante y pulido, con acabado limpio y definido",
    "de bajo mantenimiento, que se peine fácil en casa",
    "con volumen y flujo, aprovechando la longitud disponible",
    "urbano y contemporáneo, con detalles de diseño en los laterales",
    "retro reinterpretado, con una vuelta actual",
]

NOMBRES_CORTE_COMUNES = (
    "taper fade", "low taper", "mid taper", "high taper", "taper",
    "low fade", "mid fade", "high fade", "skin fade", "drop fade",
    "burst fade", "temple fade", "shadow fade", "buzz cut", "crew cut",
    "crop", "french crop", "caesar", "quiff", "pompadour", "slick back",
    "side part", "comb over", "mullet", "edgar", "two block", "curtains",
    "fringe", "shaggy", "bro flow", "afro", "undercut", "ivy league",
)


def _normalizar_tipo_cabello(valor) -> str:
    coincidencia = re.search(r"\b([1-4][abc])\b", str(valor or "").lower())
    if coincidencia and coincidencia.group(1) in TIPOS_CABELLO_VALIDOS:
        return coincidencia.group(1)
    return ""


def _get_client():
    from google import genai
    from google.genai import types
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("Falta configurar GEMINI_API_KEY en las variables de entorno")
    return genai.Client(
        api_key=api_key,
        http_options=types.HttpOptions(
            timeout=90_000,
            retry_options=types.HttpRetryOptions(attempts=1),
        ),
    )


def _limpiar_json(texto: str) -> str:
    texto = (texto or "").strip()
    if texto.startswith("```json"):
        texto = texto[7:]
    if texto.startswith("```"):
        texto = texto[3:]
    if texto.endswith("```"):
        texto = texto[:-3]
    return texto.strip()


def _normalizar_lista_texto(valores, max_items: int = 15) -> str:
    if not valores:
        return "(ninguno)"

    lista = []
    vistos = set()
    for valor in valores:
        texto = str(valor).strip()
        clave = texto.casefold()
        if texto and clave not in vistos:
            lista.append(texto)
            vistos.add(clave)

    if not lista:
        return "(ninguno)"

    return "; ".join(lista[-max_items:])


def _elegir_nombre_comun(nombre: str, recientes: list[str] | None) -> str:
    nombre_limpio = " ".join(str(nombre or "").split()).strip()
    recientes_normalizados = {
        " ".join(str(valor).casefold().split())
        for valor in (recientes or [])
        if str(valor).strip()
    }

    if (
        nombre_limpio
        and nombre_limpio.casefold() not in recientes_normalizados
        and len(nombre_limpio.split()) <= 5
        and any(
            palabra in nombre_limpio.casefold()
            for palabra in NOMBRES_CORTE_COMUNES
        )
    ):
        return nombre_limpio

    disponibles = [
        nombre_comun.title()
        for nombre_comun in NOMBRES_CORTE_COMUNES
        if nombre_comun not in recientes_normalizados
    ]
    return random.choice(disponibles or ["Taper Fade"])


def _parsear_respuesta_json(respuesta) -> dict:
    texto = getattr(respuesta, "text", None) or ""
    contenido_limpio = _limpiar_json(texto)

    if not contenido_limpio:
        raise ValueError("Gemini devolvió una respuesta vacía.")

    try:
        datos = json.loads(contenido_limpio)
    except json.JSONDecodeError as exc:
        raise ValueError(f"Gemini devolvió JSON inválido: {exc}") from exc

    if not isinstance(datos, dict):
        raise ValueError("Gemini no devolvió un objeto JSON válido.")

    return datos


def analizar_cabello_y_recomendar(
    imagen_bytes: bytes,
    forma_rostro: str,
    indice_cefalico: str,
    nombres_servicios_disponibles: list[str],
    cortes_recientes: list[str] | None = None,
) -> dict:
    """
    cortes_recientes: nombres de cortes ya recomendados a otros clientes
    (por ejemplo, los últimos 15 de tu base de datos). Se le pide al modelo
    que NO los repita.
    """

    from google.genai import types

    client = _get_client()

    catalogo_txt = (
        ", ".join(str(nombre).strip() for nombre in nombres_servicios_disponibles if str(nombre).strip())
        if nombres_servicios_disponibles
        else "(sin catálogo cargado)"
    )

    recientes_txt = _normalizar_lista_texto(cortes_recientes, max_items=15)
    enfoque = random.choice(ENFOQUES_ESTILO)

    mime_type = _detectar_mime_type_imagen(imagen_bytes)

    prompt = f"""
Eres un barbero senior con 15 años de experiencia, especialista en
asesoría de imagen masculina. Eres conocido porque NUNCA repites el
mismo corte: cada cliente sale con una propuesta hecha a su medida.

Te doy una foto de un cliente y dos datos ya calculados matemáticamente
a partir de su rostro:

- Forma de rostro: {forma_rostro}
- Índice cefálico: {indice_cefalico}

Criterios por forma de rostro (son una brújula, no una receta única;
dentro de cada uno hay MUCHOS cortes posibles):

- Ovalado: versátil, casi cualquier corte funciona; evita taparlo con
  demasiado volumen.
- Redondo: da altura y angularidad (volumen arriba, laterales cortos).
- Cuadrado: suaviza la mandíbula con texturas y flequillos suaves.
- Corazón: evita volumen extra arriba/frontal; define laterales bajos.
- Alargado/oblongo: evita mucho volumen vertical; volumen a los lados
  o flequillo horizontal.
- Diamante: suaviza pómulos con textura lateral y algo de volumen
  en frente y mentón.
- Triangular: volumen y textura arriba para equilibrar.

Catálogo de cortes que ofrece esta barbería:
{catalogo_txt}

Cortes que YA recomendaste a otros clientes (NO los repitas ni
recomiendes variantes casi idénticas):
{recientes_txt}

Si la lista anterior no está vacía, el nombre de tu propuesta principal
NO puede coincidir con ninguno de esos cortes, aunque parezca adecuado.
Antes de responder compara la propuesta principal y las alternativas con
esa lista; si se parecen demasiado, descártalas y elige otra familia de
corte. La variedad entre clientes es obligatoria, pero nunca debe estar
por encima de que el corte sea realizable y favorezca a esta persona.

Enfoque de estilo para ESTA consulta: {enfoque}.
Úsalo como punto de partida, siempre que sea coherente con el rostro y
con el cabello real del cliente.

Tu tarea:

1. Observa la foto con cuidado y responde con lo que VES, no con lo que
   supones:
   - tipo de cabello según la escala 1a-4c;
   - densidad, textura, dirección de crecimiento, remolinos,
     línea de nacimiento (entradas), altura de la frente, orejas,
     grosor del cuello, longitud ACTUAL del cabello;
   - si el cliente tiene barba, bigote o está afeitado.
   - longitud actual del cabello: "muy corto" (0-2 cm), "corto"
     (2-5 cm), "medio" (5-10 cm) o "largo" (más de 10 cm).

2. Piensa la propuesta combinando estas piezas de forma libre. No estás
   limitado a una lista; mezcla lo que mejor le quede a ESTA persona:
   - Laterales y nuca: skin fade, low/mid/high fade, taper, drop fade,
     burst fade, temp fade, degradado con tijera, sin degradado, tapered
     natural, laterales largos, etc.
   - Parte superior: crop, quiff, pompadour, textured fringe, flow,
     rizos definidos, twists, afro moldeado, slick back, side part,
     ivy league, caesar, buzz, capas, mullet moderno, etc.
   - Detalles: design line, raya marcada, flequillo, acabado mate/brillo,
     textura, línea frontal, etc.

3. Reglas para elegir la mejor opción:
   - Evalúa internamente muchas combinaciones: taper fade, low/mid/high
     fade, skin fade, drop fade, burst fade, crop, fringe, quiff,
     slick back, side part, pompadour, caesar, edgar, mullet, two block,
     buzz, crew cut, bro flow y opciones para cabello ondulado, rizado o
     afro.
   - Para cada familia considera si conviene peinar hacia adelante,
     hacia atrás, a un lado, con raya, con textura o natural.
   - Después de comparar esas opciones, devuelve SOLO la mejor. No
     devuelvas una lista de alternativas ni varias imágenes.
   - La opción elegida debe ser específica, realizable con la longitud
     actual y claramente distinta de las recomendaciones recientes.
   - No puedes añadir longitud que no aparece en la foto. Si el cabello
     es muy corto o corto, descarta slick back largo, pompadour alto,
     mullet, wolf cut, flow, man bun, cola o cualquier estilo que necesite
     cabello medio/largo. No inventes cabello en la nuca.
   - Evita por defecto los nombres genéricos ("fade medio", "corte
     clásico", "degradado clásico") y evita caer siempre en el mismo
     combo de fade + textura arriba. Explora otras familias de cortes.
     Usa nombres de barbería conocidos y fáciles de entender, como "taper",
     "taper fade", "low fade", "mid fade", "high fade", "skin fade", "mullet",
     "crop", "quiff", "side part", "slick back", "pompadour", "buzz cut",
     "crew cut", "edgar", "two block", "curtains", "fringe" o "undercut".
     No inventes nombres largos, poéticos, retro, ni combinaciones de más de
     tres elementos. El nombre debe ser corto y común.
   - Debe ser REALIZABLE hoy con el cabello que tiene: si el cabello es
     muy corto, no propongas algo que requiera 10 cm de largo.
   - Respeta el tipo de cabello: no propongas un slick back liso a un
     cabello 4c, ni rizos definidos a un cabello 1a, sin adaptarlo.

4. Si alguno del catálogo encaja de verdad, indícalo en
   "corte_del_catalogo". Si no, usa null (no fuerces el catálogo).

5. Escribe una explicación de 3-4 frases en español, tono amable y
   profesional, mencionando EXPLÍCITAMENTE cómo el corte responde a las
   características de ESTE cliente (forma de rostro, tipo de cabello,
   índice cefálico y algún detalle visible de la foto).

Responde ÚNICAMENTE con un JSON válido, sin texto antes ni después,
sin bloques de código, sin markdown.

Estructura exacta:

{{
    "tipo_cabello": "solo uno de: 1a, 1b, 1c, 2a, 2b, 2c, 3a, 3b, 3c, 4a, 4b o 4c",
    "tiene_barba": true o false (true solo si hay barba o bigote visibles),
    "descripcion_barba": "ej: 'afeitado', 'barba corta de 3 días', 'barba completa', 'solo bigote'",
    "detalles_corte": {{
        "longitud_actual": "muy corto, corto, medio o largo",
        "peinado": "cómo se peina la parte superior sin superar la longitud actual",
        "restricciones": "qué NO debe cambiarse o inventarse en la imagen"
    }},
    "nombre_corte_sugerido": "nombre técnico específico y detallado",
    "corte_del_catalogo": "nombre exacto del catálogo o null",
    "descripcion_ia": "explicación personalizada de 3-4 frases"
}}
"""

    ultimo_error = None

    for intento in range(3):
        try:
            respuesta = client.models.generate_content(
                model=MODELO_TEXTO,
                contents=[
                    types.Part.from_bytes(
                        data=imagen_bytes,
                        mime_type=mime_type,
                    ),
                    prompt,
                ],
                config=types.GenerateContentConfig(
                    temperature=1.0,
                    top_p=0.95,
                    response_mime_type="application/json",
                ),
            )

            resultado = _parsear_respuesta_json(respuesta)
            break
        except Exception as error:
            ultimo_error = error
            if intento < 2 and (
                "503" in str(error)
                or "UNAVAILABLE" in str(error)
                or "429" in str(error)
                or "RESOURCE_EXHAUSTED" in str(error)
            ):
                time.sleep(2 * (intento + 1))
                continue
            raise

    if not isinstance(resultado, dict):
        raise ValueError("La respuesta de Gemini no tiene el formato esperado.")

    resultado["tipo_cabello"] = _normalizar_tipo_cabello(
        resultado.get("tipo_cabello")
    )
    resultado["tiene_barba"] = bool(resultado.get("tiene_barba", False))

    resultado["descripcion_barba"] = str(
        resultado.get("descripcion_barba", "")
    ).strip() or "afeitado"
    resultado["descripcion_ia"] = str(
        resultado.get("descripcion_ia", "")
    ).strip() or "Recomendación generada por IA."

    if not resultado.get("nombre_corte_sugerido"):
        resultado["nombre_corte_sugerido"] = "corte personalizado"

    resultado["nombre_corte_sugerido"] = _elegir_nombre_comun(
        resultado["nombre_corte_sugerido"],
        cortes_recientes,
    )

    detalles_corte = resultado.get("detalles_corte")
    if not isinstance(detalles_corte, dict):
        detalles_corte = {}
    resultado["detalles_corte"] = {
        "longitud_actual": str(
            detalles_corte.get("longitud_actual", "")
        ).strip(),
        "peinado": str(
            detalles_corte.get("peinado", "")
        ).strip(),
        "restricciones": str(
            detalles_corte.get("restricciones", "")
        ).strip(),
    }

    if resultado.get("tipo_cabello") not in TIPOS_CABELLO_VALIDOS:
        resultado["tipo_cabello"] = ""

    return resultado


def construir_prompt_imagen(resultado: dict) -> str:
    """
    Prompt para el modelo de EDICIÓN de imagen (se le manda la foto
    original junto con este texto). Está redactado como "edita esta foto",
    no como "genera una persona", para que conserve la identidad.
    """
    corte = resultado.get("nombre_corte_sugerido", "")
    tiene_barba = resultado.get("tiene_barba", False)
    desc_barba = resultado.get("descripcion_barba", "")

    if tiene_barba:
        regla_barba = (
            f"The person has facial hair ({desc_barba}). Keep the beard/"
            "mustache EXACTLY as it is in the original photo: same shape, "
            "length, density and color. Do not trim, extend or restyle it."
        )
    else:
        regla_barba = (
            "The person is clean-shaven. Do NOT add a beard, mustache, "
            "stubble or any facial hair. The lower face must stay smooth "
            "exactly as in the original photo."
        )

    return f"""
Edit this photo. Change ONLY the hairstyle of the person to: {corte}.

Everything else must remain pixel-identical to the original photo:
- Same person: identical face, facial features, face shape, eyes, eyebrows,
  nose, mouth, ears, skin tone, skin texture, age and expression.
- Same head size, head angle, pose, framing, camera distance and crop.
- Same clothing, background and lighting.
- Same hair color (unless the cut requires otherwise) and natural hair
  texture/type.

{regla_barba}

Do not beautify, smooth, slim, age or rejuvenate the face. Do not change
the identity. Only the hair changes. The result must look like a real
photo of the same person right after leaving the barbershop.
""".strip()