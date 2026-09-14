# ============================================================
# Dockerfile para el backend Django (Urban Studio)
# Usa Daphne porque el proyecto usa Django Channels (websockets)
# ============================================================

FROM python:3.12-slim

# Evita archivos .pyc y buffers de salida (logs en tiempo real)
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Dependencias del sistema necesarias para psycopg2-binary, pillow, etc.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Instalar dependencias de Python primero (aprovecha cache de Docker)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copiar el resto del código
COPY . .

# Recolectar archivos estáticos (whitenoise los va a servir)
RUN python manage.py collectstatic --noinput

# App Runner espera que el contenedor escuche en el puerto 8080
EXPOSE 8080

# Daphne sirve tanto HTTP como WebSockets (necesario por Channels)
CMD ["daphne", "-b", "0.0.0.0", "-p", "8080", "config.asgi:application"]