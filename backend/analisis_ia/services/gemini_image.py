"""
Genera una imagen de referencia del cliente con el corte nuevo
usando Gemini 2.5 Flash Image.
"""

import os
import logging
import time

from google import genai
from google.genai import types

logger = logging.getLogger(__name__)

MODELO_IMAGEN = "gemini-2.5-flash-image"


class GeneracionImagenError(Exception):
    pass


def _get_client():
    api_key = os.environ.get("GEMINI_API_KEY")

    if not api_key:
        raise RuntimeError(
            "Falta configurar GEMINI_API_KEY en las variables de entorno (.env)"
        )

    return genai.Client(api_key=api_key)


def generar_preview_corte(
    imagen_original_bytes: bytes,
    prompt_corte: str
) -> bytes:

    if not imagen_original_bytes:
        raise GeneracionImagenError(
            "La imagen recibida está vacía."
        )

    logger.info(
        "Imagen recibida para Gemini: %s bytes",
        len(imagen_original_bytes)
    )

    # Evitar enviar imágenes sospechosamente pequeñas
    if len(imagen_original_bytes) < 10_000:
        raise GeneracionImagenError(
            f"La imagen recibida es demasiado pequeña: "
            f"{len(imagen_original_bytes)} bytes."
        )

    client = _get_client()

    instruccion_fade = ""

    if any(
        palabra in prompt_corte.lower()
        for palabra in ["fade", "degradado", "desvanecido"]
    ):
        instruccion_fade = (
            " IMPORTANT: the fade must be clearly visible in every angle. "
            "The hair near the ears and back of the neck should be very "
            "short and gradually blend into longer hair toward the top."
        )

    instruccion = (
        f"Using the provided photo of this person, create a single image "
        f"that works as a professional barbershop haircut reference sheet, "
        f"divided into 4 equal quadrants. Each quadrant must show the SAME "
        f"person with the new haircut applied: {prompt_corte}."
        f"{instruccion_fade}\n\n"

        "Quadrant 1 (top-left): FRONT view. "
        "The person faces directly toward the camera. Both eyes visible.\n"

        "Quadrant 2 (top-right): RIGHT profile view. "
        "Show the person's right ear and cheek in a genuine 90-degree "
        "side profile.\n"

        "Quadrant 3 (bottom-left): LEFT profile view. "
        "Show the person's left ear and cheek in the opposite 90-degree "
        "side profile.\n"

        "Quadrant 4 (bottom-right): BACK view. "
        "Show only the back of the head, hair and neck. "
        "No face visible.\n\n"

        "Keep the person's appearance consistent across all views. "
        "Preserve facial structure, skin tone, facial hair and identity. "
        "Only modify the hairstyle/haircut.\n\n"

        "Use a neutral studio background and consistent lighting. "
        "Create realistic professional photography, not an illustration."
    )

    imagen = types.Part.from_bytes(
        data=imagen_original_bytes,
        mime_type="image/jpeg"
    )

    # Intentamos hasta 3 veces si Gemini devuelve 503
    ultimo_error = None

    for intento in range(3):

        try:

            logger.info(
                "Enviando imagen a Gemini. Intento %s/3",
                intento + 1
            )

            respuesta = client.models.generate_content(
                model=MODELO_IMAGEN,
                contents=[
                    instruccion,
                    imagen,
                ],
                config=types.GenerateContentConfig(
                    response_modalities=["TEXT", "IMAGE"],
                ),
            )

            if not respuesta.candidates:
                raise GeneracionImagenError(
                    "Gemini no devolvió candidatos."
                )

            for candidato in respuesta.candidates:

                if not candidato.content:
                    continue

                for parte in candidato.content.parts:

                    if parte.inline_data is not None:

                        logger.info(
                            "✅ Gemini devolvió una imagen correctamente."
                        )

                        return parte.inline_data.data

            raise GeneracionImagenError(
                "Gemini respondió, pero no devolvió ninguna imagen."
            )

        except Exception as error:

            ultimo_error = error

            logger.exception(
                "Error en Gemini, intento %s/3",
                intento + 1
            )

            # Reintentar solamente si parece un error temporal
            if "503" in str(error) or "UNAVAILABLE" in str(error):

                if intento < 2:
                    time.sleep(2 * (intento + 1))
                    continue

            break

    raise GeneracionImagenError(
        f"Gemini no pudo procesar la imagen después de varios intentos: "
        f"{ultimo_error}"
    )