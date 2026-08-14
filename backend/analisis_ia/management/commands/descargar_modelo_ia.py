import os
import urllib.request

from django.core.management.base import BaseCommand

MODELOS = {
    "face_landmarker.task": (
        "https://storage.googleapis.com/mediapipe-models/"
        "face_landmarker/face_landmarker/float16/1/face_landmarker.task"
    ),
    "selfie_multiclass_256x256.tflite": (
        "https://storage.googleapis.com/mediapipe-models/"
        "image_segmenter/selfie_multiclass_256x256/float32/1/"
        "selfie_multiclass_256x256.tflite"
    ),
}


class Command(BaseCommand):
    help = "Descarga los modelos pre-entrenados de Google (MediaPipe) usados por el análisis facial."

    def handle(self, *args, **options):
        destino_dir = os.path.join(os.path.dirname(__file__), "..", "..", "modelos")
        os.makedirs(destino_dir, exist_ok=True)

        for nombre_archivo, url in MODELOS.items():
            destino = os.path.join(destino_dir, nombre_archivo)

            if os.path.exists(destino) and os.path.getsize(destino) > 100_000:
                self.stdout.write(self.style.SUCCESS(f"{nombre_archivo} ya existe en {destino}"))
                continue

            self.stdout.write(f"Descargando {nombre_archivo} desde Google: {url}")
            urllib.request.urlretrieve(url, destino)

            tamano_mb = os.path.getsize(destino) / (1024 * 1024)
            self.stdout.write(
                self.style.SUCCESS(f"{nombre_archivo} descargado correctamente ({tamano_mb:.1f} MB)")
            )
