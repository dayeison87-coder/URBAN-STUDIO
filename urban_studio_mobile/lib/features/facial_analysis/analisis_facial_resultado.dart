/// Representa la respuesta del backend Django al analizar una foto.
/// Los nombres de campo del JSON vienen en snake_case (así los definimos
/// en el serializer de Django); aquí los mapeamos a camelCase para Dart.
class AnalisisFacialResultado {
  final int id;
  final String formaRostro;
  final String indiceCefalico;
  final String tipoCabello;
  final String descripcionIa;
  final String nombreCorteSugerido;
  final String? fotoOriginal;
  final String? imagenResultado;
  final String estado;
  final String errorDetalle;

  AnalisisFacialResultado({
    required this.id,
    required this.formaRostro,
    required this.indiceCefalico,
    required this.tipoCabello,
    required this.descripcionIa,
    required this.nombreCorteSugerido,
    this.fotoOriginal,
    this.imagenResultado,
    required this.estado,
    required this.errorDetalle,
  });

  factory AnalisisFacialResultado.fromJson(Map<String, dynamic> json) {
    return AnalisisFacialResultado(
      id: json['id'] ?? 0,
      formaRostro: json['forma_rostro'] ?? '',
      indiceCefalico: json['indice_cefalico'] ?? '',
      tipoCabello: json['tipo_cabello'] ?? '',
      descripcionIa: json['descripcion_ia'] ?? '',
      nombreCorteSugerido: json['nombre_corte_sugerido'] ?? '',
      fotoOriginal: json['foto_original'],
      imagenResultado: json['imagen_resultado'],
      estado: json['estado'] ?? '',
      errorDetalle: json['error_detalle'] ?? '',
    );
  }
}