import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

/// Maneja login, registro y sesión del usuario.
class AuthService {
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUsername = 'username';

  /// URL que actualmente está funcionando.
  String? _activeBaseUrl;

  /// Obtiene una URL funcional del backend.
  Future<String?> _getWorkingBaseUrl() async {
    // Si ya encontramos una URL que funciona,
    // intentamos utilizarla primero.
    if (_activeBaseUrl != null) {
      try {
        final response = await http
            .get(Uri.parse('$_activeBaseUrl/'))
            .timeout(const Duration(seconds: 3));

        if (response.statusCode < 500) {
          return _activeBaseUrl;
        }
      } catch (_) {
        _activeBaseUrl = null;
      }
    }

    // Probamos las diferentes IP.
    for (final baseUrl in ApiConstants.baseUrls) {
      try {
        print('Probando servidor: $baseUrl');

        final response = await http
            .get(Uri.parse('$baseUrl/'))
            .timeout(const Duration(seconds: 3));

        if (response.statusCode < 500) {
          print('Servidor encontrado: $baseUrl');

          _activeBaseUrl = baseUrl;
          return baseUrl;
        }
      } catch (e) {
        print('No responde $baseUrl');
      }
    }

    print('No se encontró ningún servidor disponible.');
    return null;
  }

  // ============================================================
  // REGISTRO
  // ============================================================

  Future<bool> register(
    String username,
    String email,
    String password,
  ) async {
    final baseUrl = await _getWorkingBaseUrl();

    if (baseUrl == null) {
      print('No hay conexión con Django.');
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register/'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'username': username,
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      print(
        'Respuesta Django Registro: '
        '${response.statusCode} - ${response.body}',
      );

      return response.statusCode == 201;
    } catch (e) {
      print('Error registrando usuario: $e');
      return false;
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<bool> login(
    String username,
    String password,
  ) async {
    final baseUrl = await _getWorkingBaseUrl();

    if (baseUrl == null) {
      print('No hay conexión con Django.');
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login/'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      print(
        'Respuesta Django Login: '
        '${response.statusCode} - ${response.body}',
      );

      if (response.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(response.body);

      final accessToken = data['access'] as String?;
      final refreshToken = data['refresh'] as String?;

      if (accessToken == null) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _keyAccessToken,
        accessToken,
      );

      if (refreshToken != null) {
        await prefs.setString(
          _keyRefreshToken,
          refreshToken,
        );
      }

      // Guardar perfil
      await _guardarPerfil(
        accessToken,
        baseUrl,
        fallbackUsername: username,
      );

      return true;
    } catch (e) {
      print('Error realizando login: $e');
      return false;
    }
  }

  // ============================================================
  // PERFIL
  // ============================================================

  Future<void> _guardarPerfil(
    String accessToken,
    String baseUrl, {
    required String fallbackUsername,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/perfil/'),
            headers: {
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final nombre =
            data['username'] ??
            data['nombre'] ??
            fallbackUsername;

        await prefs.setString(
          _keyUsername,
          nombre.toString(),
        );

        return;
      }
    } catch (e) {
      print('No se pudo obtener el perfil: $e');
    }

    // Si falla el perfil, guardamos al menos el username.
    await prefs.setString(
      _keyUsername,
      fallbackUsername,
    );
  }

  // ============================================================
  // SESIÓN
  // ============================================================

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_keyAccessToken);
  }

  Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_keyUsername) ?? 'Usuario';
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();

    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUsername);
  }
}