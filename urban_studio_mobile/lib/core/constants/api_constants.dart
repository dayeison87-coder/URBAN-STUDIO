class ApiConstants {
  // IP del PC cuando está conectado a los datos compartidos del celular
  static const String baseUrl = 'http://10.237.179.62:8000/api';

  // Se mantiene para que AuthService siga funcionando
  static const List<String> baseUrls = [baseUrl];

  // =========================
  // AUTENTICACIÓN
  // =========================

  static const String loginEndpoint = '$baseUrl/login/';
  static const String registerEndpoint = '$baseUrl/register/';
  static const String perfilEndpoint = '$baseUrl/perfil/';

  // =========================
  // SERVICIOS
  // =========================

  static const String serviciosEndpoint = '$baseUrl/categorias/';

  // =========================
  // CITAS
  // =========================

  static const String citasEndpoint = '$baseUrl/citas/';

  // =========================
  // BARBEROS
  // =========================

  static const String barberosEndpoint = '$baseUrl/usuarios/barberos/';

  static const String disponibilidadEndpoint = '$baseUrl/disponibilidad/';

  // =========================
  // TESTIMONIOS
  // =========================

  static const String testimoniosEndpoint = '$baseUrl/testimonios/ultimos/';

  // =========================
  // IA
  // =========================

  static const String facialAnalysisEndpoint =
      '$baseUrl/servicios/analizar-rostro/';
}
