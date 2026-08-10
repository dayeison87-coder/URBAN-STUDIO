"""
Traduce nombres de cortes (en español, texto libre de Gemini o del catálogo)
a descripciones técnicas y detalladas, usadas como instrucción para la
edición de imagen con Gemini.

Si el nombre del corte no está en el diccionario exacto, se intenta un
match por palabras clave (fade, undercut, número de máquina, etc.) antes
de caer en un prompt genérico.
"""

import re
import unicodedata


def _normalizar(texto: str) -> str:
    """Minúsculas y sin tildes, para comparar sin importar acentos."""
    texto = texto.lower().strip()
    texto = unicodedata.normalize("NFD", texto)
    texto = "".join(c for c in texto if unicodedata.category(c) != "Mn")
    return texto


# Cortes con nombre exacto conocido → descripción técnica detallada.
PROMPTS_POR_CORTE = {
    "corte clasico": (
        "corte clásico de caballero, raya lateral marcada, lados cortos y "
        "prolijos, un poco más largo arriba, peinado con brillo natural"
    ),
    "corte texturizado con fade medio": (
        "corte texturizado con degradado (fade) medio en los lados, textura "
        "despeinada en la parte superior con movimiento natural, transición "
        "de fade nítida, acabado mate"
    ),
    "mohicano bajo": (
        "mohicano bajo (low mohawk fade), lados con degradado corto, franja "
        "de cabello un poco más larga en el centro peinada hacia arriba, "
        "degradado limpio"
    ),
    "undercut": (
        "undercut, lados y nuca rapados muy cortos, cabello notablemente más "
        "largo arriba peinado hacia atrás o de lado"
    ),
    "buzz cut": (
        "buzz cut, largo uniforme muy corto en toda la cabeza, parejo y "
        "limpio, sin degradado"
    ),
    "pompadour": (
        "pompadour, lados con degradado corto, volumen en la parte superior "
        "peinado hacia arriba y atrás, con brillo definido"
    ),
    "corte afro": (
        "corte afro natural, forma redondeada y pareja, rizos bien "
        "definidos, con buen volumen"
    ),
}

# Palabras clave que, si aparecen en el nombre del corte, agregan una
# descripción técnica aunque el nombre exacto no esté en el diccionario.
PALABRAS_CLAVE = [
    (r"\bfade\s*alto\b|\bhigh\s*fade\b", "degradado (fade) alto en los lados"),
    (r"\bfade\s*medio\b|\bmid\s*fade\b", "degradado (fade) medio en los lados"),
    (r"\bfade\s*bajo\b|\blow\s*fade\b", "degradado (fade) bajo en los lados"),
    (r"\bundercut\b", "undercut en los lados, cabello más largo arriba"),
    (r"\btexturizado\b", "textura despeinada con movimiento natural arriba"),
    (r"\bdesvanecido\b", "degradado suave en los lados"),
]

# Números de máquina de barbero (guard number) → longitud aproximada.
GUARD_LENGTHS_MM = {
    "0": "0.5mm (casi al ras)",
    "1": "3mm",
    "2": "6mm",
    "3": "10mm",
    "4": "13mm",
    "5": "16mm",
    "6": "19mm",
    "7": "22mm",
    "8": "25mm",
}


def _detectar_numero_maquina(texto_normalizado: str) -> str | None:
    """
    Busca patrones tipo "corte 7", "numero 7", "clipper 4", "#3", etc.
    Devuelve la descripción técnica correspondiente si encuentra un número válido.
    """
    match = re.search(
        r"(?:corte|numero|número|clipper|maquina|máquina|guard|#)\s*n?\.?\s*(\d)\b",
        texto_normalizado,
    )
    if not match:
        match = re.fullmatch(r"\s*(\d)\s*", texto_normalizado)

    if match:
        numero = match.group(1)
        largo = GUARD_LENGTHS_MM.get(numero)
        if largo:
            return (
                f"corte al ras con máquina, número {numero} de cuchilla "
                f"(aproximadamente {largo} de largo), longitud uniforme en "
                "toda la cabeza, parejo y limpio, sin degradado, sin diseño"
            )
    return None


def obtener_prompt_corte(nombre_corte: str) -> str:
    """
    Punto de entrada principal: recibe el nombre del corte (texto libre,
    normalmente generado por Gemini o tomado del catálogo) y devuelve una
    descripción detallada lista para usar como instrucción de edición de imagen.
    """
    if not nombre_corte:
        return "un corte de cabello moderno y prolijo"

    normalizado = _normalizar(nombre_corte)

    # 1. Match exacto en el diccionario
    if normalizado in PROMPTS_POR_CORTE:
        return PROMPTS_POR_CORTE[normalizado]

    # 2. Número de máquina de barbero (ej: "corte 7", "número 3")
    prompt_numero = _detectar_numero_maquina(normalizado)
    if prompt_numero:
        return prompt_numero

    # 3. Palabras clave sueltas (fade alto, undercut, texturizado, etc.)
    descripciones = [
        desc for patron, desc in PALABRAS_CLAVE if re.search(patron, normalizado)
    ]
    if descripciones:
        return f"{nombre_corte}, " + ", ".join(descripciones)

    # 4. Fallback: usa el nombre tal cual, mejor que nada.
    return f"{nombre_corte}, corte prolijo y bien definido, estilo de barbería profesional"