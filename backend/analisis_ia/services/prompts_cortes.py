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
    "taper": (
        "taper clásico: solo patillas y nuca rebajadas de forma gradual, "
        "sin rapar todo el lateral, sin fade alto, parte superior casi igual "
        "de larga y peinada de forma natural"
    ),
    "taper fade": (
        "taper fade: degradado suave y bajo únicamente en patillas y nuca, "
        "laterales conservando peso y longitud, transición sutil, parte "
        "superior natural; no convertirlo en low fade, mid fade ni high fade"
    ),
    "low taper": (
        "low taper: taper muy bajo en patillas y borde de la nuca, laterales "
        "largos y llenos, sin degradar toda la zona sobre la oreja, parte "
        "superior con su longitud actual"
    ),
    "mid taper": (
        "mid taper: taper gradual a media altura en patillas y nuca, sin "
        "rapar completamente los laterales, parte superior separada y natural"
    ),
    "high taper": (
        "high taper: taper marcado solo en patillas y nuca alta, laterales "
        "limpios pero no completamente rapados, parte superior claramente "
        "conservada"
    ),
    "low fade": (
        "low fade: degradado completo bajo desde la piel junto a las patillas "
        "hasta los laterales bajos, transición visible y parte superior con "
        "textura; no hacer taper ni mid fade"
    ),
    "mid fade": (
        "mid fade: degradado completo a media altura alrededor de toda la "
        "cabeza, laterales notablemente cortos desde la mitad, transición "
        "visible y parte superior separada; no hacer taper"
    ),
    "high fade": (
        "high fade: degradado completo alto que sube cerca de las sienes, "
        "laterales muy cortos y contraste fuerte con la parte superior; no "
        "hacer taper ni low fade"
    ),
    "skin fade": (
        "skin fade: laterales y nuca empiezan al ras de la piel y suben en "
        "una transición limpia hasta la parte superior, contraste marcado, "
        "sin conservar peso bajo en los laterales"
    ),
    "drop fade": (
        "drop fade: degradado a piel que cae en curva detrás de las orejas y "
        "sigue la forma de la nuca, laterales cortos y parte superior intacta"
    ),
    "burst fade": (
        "burst fade: degradado radial alrededor de cada oreja, dejando más "
        "longitud en la nuca y el centro posterior, sin hacer un fade completo "
        "recto en toda la cabeza"
    ),
    "bald fade": (
        "bald fade: laterales y nuca afeitados al ras de la piel, con una "
        "transición muy limpia hacia una parte superior claramente más larga"
    ),
    "low skin fade": (
        "low skin fade: degradado a piel muy bajo, solo en la zona inferior "
        "de patillas y nuca, conservando peso visible sobre las orejas"
    ),
    "mid skin fade": (
        "mid skin fade: degradado a piel que comienza a media altura de los "
        "laterales, con contraste claro entre piel, transición y parte superior"
    ),
    "high skin fade": (
        "high skin fade: laterales afeitados a piel hasta cerca de las sienes, "
        "contraste alto y parte superior separada y visible"
    ),
    "low drop fade": (
        "low drop fade: degradado bajo a piel que cae suavemente detrás de "
        "las orejas siguiendo la curva de la nuca"
    ),
    "mid drop fade": (
        "mid drop fade: degradado a media altura que forma una caída curva "
        "detrás de las orejas, con laterales más cortos y nuca definida"
    ),
    "burst fade mullet": (
        "burst fade mullet: degradado circular alrededor de las orejas, "
        "laterales cortos y nuca visiblemente más larga; solo con longitud real"
    ),
    "burst fade crop": (
        "burst fade crop: burst fade alrededor de las orejas combinado con "
        "parte superior corta texturizada y flequillo hacia adelante"
    ),
    "razor fade": (
        "razor fade: degradado muy limpio afeitado con navaja en la base, "
        "transición marcada y parte superior conservando su textura natural"
    ),
    "scissor fade": (
        "scissor fade: laterales y nuca trabajados principalmente con tijera, "
        "transición suave sin dejar el lateral completamente al ras"
    ),
    "taper fade with line": (
        "taper fade con una sola línea lateral fina y limpia, taper bajo en "
        "patillas y nuca, sin convertir todo el lateral en un fade"
    ),
    "low fade with line": (
        "low fade con una sola línea lateral, degradado completo bajo desde "
        "la piel y diseño separado claramente visible"
    ),
    "mid fade with line": (
        "mid fade con una sola línea lateral, degradado completo a media "
        "altura y diseño marcado sin añadir otros dibujos"
    ),
    "high fade with line": (
        "high fade con una sola línea lateral, degradado alto y contraste "
        "fuerte entre laterales y parte superior"
    ),
    "buzz cut": (
        "buzz cut: cabello corto y uniforme con máquina en toda la cabeza, "
        "sin volumen superior, sin flequillo y sin textura larga"
    ),
    "crew cut": (
        "crew cut: laterales cortos y parte superior corta ligeramente más "
        "larga hacia la frente, forma limpia y práctica, sin flequillo largo"
    ),
    "crop": (
        "crop: laterales cortos y parte superior corta texturizada, flequillo "
        "corto hacia adelante sobre la frente, acabado mate y definido"
    ),
    "french crop": (
        "french crop: laterales cortos, parte superior corta con textura "
        "marcada y flequillo recto corto hacia adelante, sin peinar hacia atrás"
    ),
    "caesar": (
        "caesar: cabello corto de longitud uniforme, flequillo horizontal "
        "corto hacia adelante y laterales limpios, sin volumen alto"
    ),
    "quiff": (
        "quiff: laterales más cortos y parte superior con volumen frontal "
        "peinada hacia arriba y ligeramente hacia atrás, sin alargar la nuca"
    ),
    "side part": (
        "side part: parte superior peinada claramente hacia un lado con raya "
        "lateral visible, laterales prolijos y sin volumen exagerado"
    ),
    "slick back": (
        "slick back: parte superior peinada completamente hacia atrás con la "
        "longitud existente, laterales ordenados, sin inventar longitud extra"
    ),
    "mullet": (
        "mullet: laterales cortos, parte superior texturizada y nuca "
        "visiblemente más larga que los laterales, solo si la foto ya tiene "
        "longitud suficiente en la nuca"
    ),
    "edgar": (
        "edgar: laterales con degradado corto, parte superior recta y "
        "texturizada, línea frontal corta y definida hacia adelante"
    ),
    "two block": (
        "two block: laterales y nuca recortados en una sección separada, "
        "parte superior notablemente más larga y pesada, sin mezclarlo con fade"
    ),
    "curtains": (
        "curtains: parte superior media dividida al centro, mechones cayendo "
        "a ambos lados de la frente, laterales conservando longitud"
    ),
    "fringe": (
        "fringe: parte superior peinada hacia adelante con flequillo visible "
        "sobre la frente, laterales equilibrados y sin peinar hacia atrás"
    ),
    "bro flow": (
        "bro flow: cabello medio o largo peinado hacia atrás y hacia los lados "
        "con caída natural, capas suaves y movimiento, sin fade corto"
    ),
    "afro": (
        "afro: cabello rizado o afro conservando volumen redondeado natural, "
        "contorno limpio y sin alisar ni convertirlo en fade común"
    ),
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
    (r"\bhigh\s*temp\s*fade\b|\btemp\s*fade\b", "degradado alto alrededor de las sienes (temple fade), nuca y laterales con diseño específico"),
    (r"\btaper\s*fade\b", "taper fade suave y bajo en patillas y nuca, no fade completo"),
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