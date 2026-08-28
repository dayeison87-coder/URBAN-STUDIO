/// Respuesta del backend Django al analizar una foto (endpoint
/// /api/servicios/analizar-rostro/). Los nombres vienen en snake_case
/// en el JSON (así los define el serializer de Django) y los mapeamos
/// a camelCase aquí para usarlos como .formaRostro, .tipoCabello, etc.
class AnalysisResponse {
  const AnalysisResponse({
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

  factory AnalysisResponse.fromJson(Map<String, dynamic> json) {
    return AnalysisResponse(
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

  final String formaRostro;
  final String indiceCefalico;
  final String tipoCabello;
  final String descripcionIa;
  final String nombreCorteSugerido;
  final String? fotoOriginal;
  final String? imagenResultado;
  final String estado;
  final String errorDetalle;
}

