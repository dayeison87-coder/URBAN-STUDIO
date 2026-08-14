"""
Detección de forma de rostro y proporción cefálica usando MediaPipe Face Mesh.

MediaPipe ya viene con un modelo entrenado por Google que detecta 468 puntos
(landmarks) de la cara. Nosotros NO entrenamos nada aquí: solo usamos esos
puntos para calcular proporciones geométricas (ancho de pómulos, ancho de
mandíbula, ancho de frente, largo de la cara) y con reglas simples
clasificamos la forma. Es el mismo enfoque que usan la mayoría de apps
comerciales de "face shape detector".

Índices de landmarks usados (de los 468 de MediaPipe Face Mesh):
- 10   -> punto superior de la frente (nacimiento del cabello aprox.)
- 152  -> punta del mentón
- 234  -> pómulo izquierdo (borde de la cara, lado derecho de la imagen)
- 454  -> pómulo derecho (borde de la cara, lado izquierdo de la imagen)
- 172  -> borde de la mandíbula izquierdo
- 397  -> borde de la mandíbula derecho
- 21   -> borde de la frente izquierdo
- 251  -> borde de la frente derecho
"""

import os

import numpy as np
import mediapipe as mp
import cv2
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.core.base_options import BaseOptions

# Ruta al modelo pre-entrenado de Google (archivo .task).
# Se descarga UNA sola vez con el comando de gestión `python manage.py descargar_modelo_ia`
# (o manualmente, ver instrucciones en el README de esta app).
MODELO_PATH = os.path.join(os.path.dirname(__file__), "..", "modelos", "face_landmarker.task")

_landmarker = None


def _get_landmarker():
    """Carga el modelo una sola vez (perezoso) y lo reutiliza entre requests."""
    global _landmarker
    if _landmarker is None:
        if not os.path.exists(MODELO_PATH):
            raise RostroNoDetectadoError(
                f"No se encontró el modelo de detección facial en {MODELO_PATH}. "
                "Ejecuta: python manage.py descargar_modelo_ia"
            )
        options = vision.FaceLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=MODELO_PATH),
            running_mode=vision.RunningMode.IMAGE,
            num_faces=1,
            min_face_detection_confidence=0.5,
        )
        _landmarker = vision.FaceLandmarker.create_from_options(options)
    return _landmarker


LANDMARKS = {
    "frente_top": 10,
    "menton": 152,
    "pomulo_izq": 234,
    "pomulo_der": 454,
    "mandibula_izq": 172,
    "mandibula_der": 397,
    "frente_izq": 21,
    "frente_der": 251,
}


class RostroNoDetectadoError(Exception):
    pass


def _distancia(p1, p2):
    return float(np.linalg.norm(np.array(p1) - np.array(p2)))


def analizar_rostro(imagen_bytes: bytes) -> dict:
    """
    Recibe los bytes de una imagen (foto subida por el cliente) y devuelve:
    {
        "forma_rostro": "ovalado" | "redondo" | "cuadrado" | "corazon" | "alargado" | "diamante" | "triangular",
        "indice_cefalico": "dolicocefalo" | "mesocefalo" | "braquicefalo",
        "medidas": {...}  # crudo, útil para depurar o mejorar las reglas más adelante
    }
    Lanza RostroNoDetectadoError si no se encontró una cara clara en la foto.
    """
    nparr = np.frombuffer(imagen_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise RostroNoDetectadoError("No se pudo leer la imagen. Verifica el formato (jpg/png).")

    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    h, w, _ = img_rgb.shape

    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=img_rgb)
    landmarker = _get_landmarker()
    resultado = landmarker.detect(mp_image)

    if not resultado.face_landmarks:
        raise RostroNoDetectadoError(
            "No se detectó ningún rostro en la foto. Pide al cliente una foto de frente, con buena luz."
        )

    landmarks = resultado.face_landmarks[0]

    puntos = {}
    for nombre, idx in LANDMARKS.items():
        lm = landmarks[idx]
        puntos[nombre] = (lm.x * w, lm.y * h)

    ancho_pomulos = _distancia(puntos["pomulo_izq"], puntos["pomulo_der"])
    ancho_mandibula = _distancia(puntos["mandibula_izq"], puntos["mandibula_der"])
    ancho_frente = _distancia(puntos["frente_izq"], puntos["frente_der"])
    largo_cara = _distancia(puntos["frente_top"], puntos["menton"])

    medidas = {
        "ancho_pomulos": round(ancho_pomulos, 2),
        "ancho_mandibula": round(ancho_mandibula, 2),
        "ancho_frente": round(ancho_frente, 2),
        "largo_cara": round(largo_cara, 2),
    }

    forma_rostro = _clasificar_forma(ancho_pomulos, ancho_mandibula, ancho_frente, largo_cara)
    indice_cefalico = _clasificar_indice_cefalico(ancho_pomulos, largo_cara)

    return {
        "forma_rostro": forma_rostro,
        "indice_cefalico": indice_cefalico,
        "medidas": medidas,
    }


def _clasificar_forma(ancho_pomulos, ancho_mandibula, ancho_frente, largo_cara):
    """
    Reglas heurísticas estándar (usadas en la mayoría de detectores de forma
    de rostro de código abierto). No son un diagnóstico exacto, son una
    aproximación razonable a partir de proporciones.
    """
    ratio_largo_ancho = largo_cara / ancho_pomulos
    ratio_mandibula_pomulos = ancho_mandibula / ancho_pomulos
    ratio_frente_pomulos = ancho_frente / ancho_pomulos
    ratio_frente_mandibula = ancho_frente / ancho_mandibula

    if ratio_largo_ancho > 1.55:
        return "alargado"

    if ratio_mandibula_pomulos > 0.98 and ratio_frente_pomulos > 0.98 and ratio_largo_ancho < 1.3:
        return "cuadrado"

    if ratio_largo_ancho < 1.25 and ratio_mandibula_pomulos > 0.9:
        return "redondo"

    if ratio_frente_mandibula > 1.15:
        return "corazon"

    if ratio_frente_pomulos < 0.85 and ratio_mandibula_pomulos < 0.85:
        return "diamante"

    if ratio_frente_mandibula < 0.85:
        return "triangular"

    return "ovalado"


def _clasificar_indice_cefalico(ancho_pomulos, largo_cara):
    ratio = ancho_pomulos / largo_cara
    if ratio < 0.72:
        return "dolicocefalo"
    if ratio > 0.82:
        return "braquicefalo"
    return "mesocefalo"
