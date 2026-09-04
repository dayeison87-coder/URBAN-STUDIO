/// Modelo de un testimonio/reseña que devuelve el backend.
/// Coincide con lo que consume el frontend Angular:
///   cliente_username, comentario, estrellas
class Testimonio {
  final String clienteUsername;
  final String comentario;
  final int estrellas;

  const Testimonio({
    required this.clienteUsername,
    required this.comentario,
    required this.estrellas,
  });

  /// Inicial para el avatar (primera letra del usuario, en mayúscula).
  String get inicial =>
      clienteUsername.isNotEmpty ? clienteUsername[0].toUpperCase() : 'U';

  factory Testimonio.fromJson(Map<String, dynamic> json) {
    final rawEstrellas = json['estrellas'];
    int estrellas = 5;
    if (rawEstrellas is int) {
      estrellas = rawEstrellas;
    } else if (rawEstrellas is String) {
      estrellas = int.tryParse(rawEstrellas) ?? 5;
    } else if (rawEstrellas is double) {
      estrellas = rawEstrellas.round();
    }
    estrellas = estrellas.clamp(0, 5);

    return Testimonio(
      clienteUsername: (json['cliente_username'] ?? 'Usuario').toString(),
      comentario: (json['comentario'] ?? '').toString(),
      estrellas: estrellas,
    );
  }
}