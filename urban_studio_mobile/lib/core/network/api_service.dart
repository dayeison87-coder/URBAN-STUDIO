import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../models/analysis_model.dart';
import '../constants/api_constants.dart';
import 'auth_service.dart';

class ApiService {
  final AuthService _authService = AuthService();

  Future<AnalysisResponse> analyzeFace(
    Uint8List imageBytes, {
    String filename = 'foto.jpg',
  }) async {
    final token = await _authService.getAccessToken();
    if (token == null) {
      throw Exception('No hay sesión activa. Vuelve a iniciar sesión.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConstants.facialAnalysisEndpoint),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('foto', imageBytes, filename: filename),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print(
      'Respuesta analizar-rostro: ${response.statusCode} - ${response.body}',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return AnalysisResponse.fromJson(data);
    } else {
      final data = _intentarDecodificar(response.body);
      final mensaje =
          data?['error'] ??
          'Error al procesar el análisis facial (código ${response.statusCode}).';
      throw Exception(mensaje);
    }
  }

  Future<List<dynamic>> obtenerBarberos() async {
    final token = await _authService.getAccessToken();
    if (token == null) throw Exception('No hay sesión activa.');

    final response = await http.get(
      Uri.parse(ApiConstants.barberosEndpoint),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('No se pudo cargar la lista de barberos.');
    }

    final data = jsonDecode(response.body);
    if (data is! List) throw Exception('La lista de barberos no es válida.');
    return data;
  }

  Future<void> solicitarCodigoIA(int barberoId) async {
    final token = await _authService.getAccessToken();
    if (token == null) throw Exception('No hay sesión activa.');

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/solicitar-codigo-ia/'), // ✅
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'barbero_id': barberoId}),
    );

    if (response.statusCode != 200) {
      final data = _intentarDecodificar(response.body);
      throw Exception(data?['error'] ?? 'No se pudo enviar el código.');
    }
  }

  Future<void> validarCodigoIA(String codigo, int barberoId) async {
    final token = await _authService.getAccessToken();
    if (token == null) throw Exception('No hay sesión activa.');

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/validar-codigo-ia/'), // 👈 correcto
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'codigo': codigo, 'barbero_id': barberoId}),
    );

    if (response.statusCode != 200) {
      final data = _intentarDecodificar(response.body);
      throw Exception(data?['error'] ?? 'Código inválido.');
    }
  }

  Map<String, dynamic>? _intentarDecodificar(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}
