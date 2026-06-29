import json
from channels.generic.websocket import AsyncWebsocketConsumer

class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        # La sala ahora es: chat_barberoId_clienteId
        self.barbero_id = self.scope['url_route']['kwargs']['barbero_id']
        self.cliente_id = self.scope['url_route']['kwargs']['cliente_id']
        self.room_group_name = f'chat_{self.barbero_id}_{self.cliente_id}'

        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        await self.accept()

        # Notifica al barbero que un cliente se conectó
        await self.channel_layer.group_send(
            f'barbero_{self.barbero_id}',
            {
                'type': 'cliente_conectado',
                'cliente_id': self.cliente_id,
            }
        )

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )

    async def receive(self, text_data):
        data = json.loads(text_data)
        mensaje  = data['mensaje']
        usuario  = data['usuario']
        usuario_id = data.get('usuario_id', '')

        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type':      'chat_message',
                'mensaje':   mensaje,
                'usuario':   usuario,
                'usuario_id': usuario_id,
            }
        )

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({
            'mensaje':    event['mensaje'],
            'usuario':    event['usuario'],
            'usuario_id': event.get('usuario_id', ''),
        }))


class BarberoNotificacionConsumer(AsyncWebsocketConsumer):
    """
    Canal exclusivo del barbero para recibir notificaciones
    de nuevos clientes que inician chat.
    """
    async def connect(self):
        self.barbero_id = self.scope['url_route']['kwargs']['barbero_id']
        self.group_name = f'barbero_{self.barbero_id}'

        await self.channel_layer.group_add(
            self.group_name,
            self.channel_name
        )
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.group_name,
            self.channel_name
        )

    async def cliente_conectado(self, event):
        await self.send(text_data=json.dumps({
            'type':       'nuevo_cliente',
            'cliente_id': event['cliente_id'],
        }))