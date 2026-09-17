"""
Django settings for config project.
"""

from pathlib import Path
from datetime import timedelta
import os
import dj_database_url
from dotenv import load_dotenv
load_dotenv()


BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.getenv('SECRET_KEY', 'django-insecure-clave-temporal-cambiar-en-produccion')

DEBUG = os.getenv('DEBUG', 'False') == 'True'

ALLOWED_HOSTS = [
    '127.0.0.1',
    'localhost',
    '192.168.1.9',
    '10.237.179.62',
    '10.203.146.62',
]

# Render
RENDER_HOST = os.getenv('RENDER_EXTERNAL_HOSTNAME')
if RENDER_HOST:
    ALLOWED_HOSTS.append(RENDER_HOST)

# App Runner (por si acaso)
APP_RUNNER_HOST = os.getenv('APP_RUNNER_HOST')
if APP_RUNNER_HOST:
    ALLOWED_HOSTS.append(APP_RUNNER_HOST)

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'channels',

    # Terceros
    'rest_framework',
    'corsheaders',

    # Propias
    'users',
    'servicios',
    'analisis_ia',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'

# ── Base de datos ─────────────────────────────────────────────
# Por defecto usa las variables individuales (local)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DB_NAME', 'urban_studio'),
        'USER': os.getenv('DB_USER', 'postgres'),
        'PASSWORD': os.getenv('DB_PASSWORD', ''),
        'HOST': os.getenv('DB_HOST', 'localhost'),
        'PORT': os.getenv('DB_PORT', '5432'),
    }
}

# En Render, DATABASE_URL sobreescribe la config anterior
DATABASE_URL = os.getenv('DATABASE_URL')
if DATABASE_URL:
    DATABASES['default'] = dj_database_url.config(
        default=DATABASE_URL,
        conn_max_age=600,
        ssl_require=True
    )

# ── Validación de contraseñas ─────────────────────────────────
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# ── Internacionalización ──────────────────────────────────────
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# ── Usuario personalizado ─────────────────────────────────────
AUTH_USER_MODEL = 'users.Usuario'

# ── Django REST Framework ─────────────────────────────────────
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ),
}

# ── CORS ──────────────────────────────────────────────────────
# ── CORS ──────────────────────────────────────────────────────
CORS_ALLOW_ALL_ORIGINS = True

# ── JWT ───────────────────────────────────────────────────────
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME':  timedelta(hours=8),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=1),
}

# ── Channels ──────────────────────────────────────────────────
ASGI_APPLICATION = 'config.asgi.application'

CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels.layers.InMemoryChannelLayer'
    }
}

# ── Static / Media ────────────────────────────────────────────
STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

STORAGES = {
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}

MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')
os.makedirs(MEDIA_ROOT, exist_ok=True)

# ── Correo ────────────────────────────────────────────────────
BREVO_API_KEY = os.getenv('BREVO_API_KEY')
BREVO_SENDER_EMAIL = os.getenv('BREVO_SENDER_EMAIL')
BREVO_SENDER_NAME = os.getenv('BREVO_SENDER_NAME', 'Urban Studio')
BREVO_TIMEOUT = float(os.getenv('BREVO_TIMEOUT', '10'))

# Legacy SMTP settings kept for the AI security-code flow.
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_TIMEOUT = float(os.getenv('EMAIL_TIMEOUT', '10'))
EMAIL_HOST_USER = os.getenv('EMAIL_HOST_USER')
EMAIL_HOST_PASSWORD = os.getenv('EMAIL_HOST_PASSWORD')
DEFAULT_FROM_EMAIL = EMAIL_HOST_USER

# ── Google ────────────────────────────────────────────────────
GOOGLE_CLIENT_ID = os.getenv('GOOGLE_CLIENT_ID')
GOOGLE_CLIENT_SECRET = os.getenv('GOOGLE_CLIENT_SECRET')
GOOGLE_REDIRECT_URI = os.getenv('GOOGLE_REDIRECT_URI')

# ── Seguridad en producción ───────────────────────────────────
if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
