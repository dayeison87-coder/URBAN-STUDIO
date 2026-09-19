"""
Genera una imagen de referencia del cliente con el corte nuevo
usando Gemini 2.5 Flash Image.
"""

import os
import logging
import time

logger = logging.getLogger(__name__)

MODELO_IMAGEN = "gemini-2.5-flash-image"


class GeneracionImagenError(Exception):
    pass


def _get_client():
    # Carga Gemini solamente cuando se necesita.
    from google import genai
    from google.genai import types

    api_key = os.environ.get("GEMINI_API_KEY")

    if not api_key:
        raise RuntimeError(
            "Falta configurar GEMINI_API_KEY en las variables de entorno (.env)"
        )

    return genai.Client(
        api_key=api_key,
        http_options=types.HttpOptions(
            timeout=90_000,
            retry_options=types.HttpRetryOptions(attempts=1),
        ),
    )


def generar_preview_corte(
    imagen_original_bytes: bytes,
    prompt_corte: str
) -> bytes:

    # Importar types solamente cuando se va a generar la imagen.
    from google.genai import types

    if not imagen_original_bytes:
        raise GeneracionImagenError(
            "La imagen recibida está vacía."
        )

    logger.info(
        "Imagen recibida para Gemini: %s bytes",
        len(imagen_original_bytes)
    )

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
        f"that works as a professional haircut reference sheet showing the "
        f"SAME person with the new haircut applied: {prompt_corte}."
        f"{instruccion_fade}\n\n"
        "Create exactly four equal quadrants in this one image, with no "
        "large unused spaces. The TOP-LEFT quadrant is the primary view and "
        "MUST be a clear, centered, straight FRONT portrait: both eyes, "
        "nose and mouth facing directly toward the camera, full face visible, "
        "not a three-quarter view and not a profile. "
        "Quadrant 2 (top-right): genuine right 90-degree profile. "
        "Quadrant 3 (bottom-left): genuine left 90-degree profile. "
        "Quadrant 4 (bottom-right): back of the head, hair and neck only. "
        "Do not create extra panels, extra people or a different hairstyle "
        "between quadrants.\n\n"
        "Keep the person's appearance extremely consistent across all four views. "
        "Preserve the exact facial structure, face proportions, hairline, "
        "eyes, eyebrows, nose, lips, ears, jaw, skin tone, facial hair, "
        "expression and identity from the source photo. Do not beautify or "
        "redesign the person. Only modify the hairstyle/haircut and any "
        "explicitly requested subtle hair design line.\n"
        "CRITICAL HAIR LENGTH RULE: do not add hair length, extensions or "
        "volume that is not present in the source photo. Do not create a "
        "mullet, long back, rat tail, flow, ponytail or hair below the "
        "original neckline unless the source photo already has that length. "
        "The back and sides must remain within the original hair silhouette. "
        "If the requested cut cannot be achieved with the existing length, "
        "choose the closest shorter, realistic version instead.\n\n"

        "Use a neutral studio background and consistent lighting. "
        "Create realistic professional photography, not an illustration."
    )

    imagen = types.Part.from_bytes(
        data=imagen_original_bytes,
        mime_type="image/jpeg"
    )

    ultimo_error = None

    for intento in range(1):

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
                    response_modalities=["IMAGE"],
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
                            "Gemini devolvió una imagen correctamente."
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

            if "503" in str(error) or "UNAVAILABLE" in str(error):

                if intento < 2:
                    time.sleep(2 * (intento + 1))
                    continue

            break

    raise GeneracionImagenError(
        f"Gemini no pudo procesar la imagen después de varios intentos: "
        f"{ultimo_error}"
    )