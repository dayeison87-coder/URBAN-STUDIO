from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    # Chat individual: barbero + cliente
    re_path(
        r'ws/chat/(?P<barbero_id>\w+)/(?P<cliente_id>\w+)/$',
        consumers.ChatConsumer.as_asgi()
    ),
    # Canal de notificaciones del barbero
    re_path(
        r'ws/barbero/(?P<barbero_id>\w+)/$',
        consumers.BarberoNotificacionConsumer.as_asgi()
    ),
]