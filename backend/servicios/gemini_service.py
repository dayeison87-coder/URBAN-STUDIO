import os
import json
from google import genai
from google.genai import types
from dotenv import load_dotenv

load_dotenv()

# Se obtiene la API key o se asigna un valor por defecto para evitar que falle al importar el modulo
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")

# Inicialización segura del cliente
client = genai.Client(api_key=GEMINI_API_KEY) if GEMINI_API_KEY else None


def analizar_rostro_con_ia(image_file):
    if not client:
        raise Exception("No se ha configurado la variable GEMINI_API_KEY en el entorno (.env).")

    try:
        image_bytes = image_file.read()
        
        # Determinar el tipo de imagen (por defecto image/jpeg)
        mime_type = getattr(image_file, 'content_type', 'image/jpeg') or 'image/jpeg'

        prompt = """
        Eres un barbero experto y especialista en morfología facial y capilar.
        Analiza la foto proporcionada y devuelve un objeto JSON válido con la siguiente estructura:
        {
          "forma_rostro": "...",
          "tipo_craneo": "...",
          "tipo_cabello": "...",
          "corte_recomendado": "...",
          "razon": "..."
        }
        """

        # Crear la parte de la imagen a partir de los bytes
        image_part = types.Part.from_bytes(
            data=image_bytes,
            mime_type=mime_type,
        )

        # Configurar la solicitud para forzar respuesta en formato JSON estructurado
        response = client.models.generate_content(
            model='gemini-2.0-flash',
            contents=[image_part, prompt],
            config=types.GenerateContentConfig(
                response_mime_type='application/json'
            )
        )

        texto_respuesta = response.text.strip()
        texto_respuesta = texto_respuesta.replace("```json", "").replace("```", "").strip()

        return json.loads(texto_respuesta)

    except Exception as e:
        print(f"Error en el servicio de Gemini: {e}")
        raise Exception("No se pudo procesar el análisis facial con la IA.")