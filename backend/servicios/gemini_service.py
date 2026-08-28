import os
import base64
from google import genai
from dotenv import load_dotenv

load_dotenv()

client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

def analizar_rostro_con_ia(image_file):
    try:
        image_bytes = image_file.read()
        base64_image = base64.b64encode(image_bytes).decode('utf-8')

        prompt = """
          Eres un barbero experto y especialista en morfología facial y capilar.
          Analiza la foto proporcionada y devuelve estrictamente un objeto JSON válido con la siguiente estructura (sin texto adicional, sin bloques de código markdown como ```json, solo el texto plano del JSON):
          {
            "forma_rostro": "...",
            "tipo_craneo": "...",
            "tipo_cabello": "...",
            "corte_recomendado": "...",
            "razon": "..."
          }
        """

        response = client.models.generate_content(
            model='gemini-2.0-flash',
            contents=[
                {
                    'inline_data': {
                        'data': base64_image,
                        'mime_type': 'image/jpeg'
                    }
                },
                prompt
            ]
        )

        texto_respuesta = response.text.strip()
        texto_respuesta = texto_respuesta.replace("```json", "").replace("```", "").strip()

        import json
        return json.loads(texto_respuesta)

    except Exception as e:
        print(f"Error en el servicio de Gemini: {e}")
        raise Exception("No se pudo procesar el análisis facial con la IA.")