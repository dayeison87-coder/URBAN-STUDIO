import os
import base64
import json

from dotenv import load_dotenv

load_dotenv()


def _get_client():
    # Gemini se carga solamente cuando realmente se necesita.
    from google import genai

    api_key = os.getenv("GEMINI_API_KEY")

    if not api_key:
        raise RuntimeError(
            "Falta configurar GEMINI_API_KEY en las variables de entorno."
        )

    return genai.Client(api_key=api_key)


def analizar_rostro_con_ia(image_file):
    try:
        image_bytes = image_file.read()

        if not image_bytes:
            raise ValueError("La imagen recibida está vacía.")

        base64_image = base64.b64encode(image_bytes).decode("utf-8")

        prompt = """
Eres un barbero experto y especialista en morfología facial y capilar.

Analiza la foto proporcionada y devuelve estrictamente un objeto JSON
válido con la siguiente estructura.

No agregues texto adicional.
No uses bloques de código markdown.
Devuelve únicamente el JSON.

{
  "forma_rostro": "...",
  "tipo_craneo": "...",
  "tipo_cabello": "...",
  "corte_recomendado": "...",
  "razon": "..."
}
"""

        client = _get_client()

        # types también se carga solamente cuando se necesita.
        from google.genai import types

        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=[
                types.Part.from_bytes(
                    data=image_bytes,
                    mime_type="image/jpeg",
                ),
                prompt,
            ],
        )

        texto_respuesta = response.text.strip()

        if texto_respuesta.startswith("```json"):
            texto_respuesta = texto_respuesta[7:]

        if texto_respuesta.startswith("```"):
            texto_respuesta = texto_respuesta[3:]

        if texto_respuesta.endswith("```"):
            texto_respuesta = texto_respuesta[:-3]

        texto_respuesta = texto_respuesta.strip()

        return json.loads(texto_respuesta)

    except Exception as e:
        print(f"Error en el servicio de Gemini: {e}")
        raise Exception(
            "No se pudo procesar el análisis facial con la IA."
        )