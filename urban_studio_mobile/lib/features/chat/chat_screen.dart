import 'package:flutter/material.dart';

const _bg = Color(0xFF0A0A0A);
const _surface = Color(0xFF111111);
const _gold = Color(0xFFC9A96E);
const _line = Color(0xFF1D1D1D);
const _muted = Color(0xFFB7B7B7);

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final List<_Mensaje> _mensajes = [
    _Mensaje(
      texto: 'Hola, ¿en qué puedo ayudarte con tu cita o tu estilo?',
      esUsuario: false,
    ),
    _Mensaje(
      texto: 'Quiero una recomendación para un corte moderno.',
      esUsuario: true,
    ),
    _Mensaje(
      texto:
          'Perfecto. Te recomiendo un fade con textura y una línea suave en la barba.',
      esUsuario: false,
    ),
  ];

  void _enviarMensaje() {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      _mensajes.add(_Mensaje(texto: texto, esUsuario: true));
      _mensajes.add(
        _Mensaje(
          texto:
              'Gracias. Podemos ayudarte a coordinarlo para tu próxima cita.',
          esUsuario: false,
        ),
      );
    });

    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Chat', style: TextStyle(letterSpacing: 1.2)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _gold, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _mensajes.length,
              itemBuilder: (_, index) {
                final mensaje = _mensajes[index];
                return Align(
                  alignment: mensaje.esUsuario
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: mensaje.esUsuario ? _gold : _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: mensaje.esUsuario ? _gold : _line,
                      ),
                    ),
                    child: Text(
                      mensaje.texto,
                      style: TextStyle(
                        color: mensaje.esUsuario ? Colors.black : Colors.white,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu mensaje...',
                      hintStyle: TextStyle(color: _muted),
                      filled: true,
                      fillColor: _surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: _line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: _line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: _gold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _enviarMensaje,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Mensaje {
  final String texto;
  final bool esUsuario;

  _Mensaje({required this.texto, required this.esUsuario});
}
