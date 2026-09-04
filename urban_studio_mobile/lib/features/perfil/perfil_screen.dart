import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';

const _bg = Color(0xFF0A0A0A);
const _surface = Color(0xFF111111);
const _gold = Color(0xFFC9A96E);
const _line = Color(0xFF1D1D1D);
const _muted = Color(0xFFB7B7B7);

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();

  bool _cargando = true;
  bool _guardando = false;
  String? _mensaje;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _cargarPerfil() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final response = await http
          .get(
            Uri.parse(ApiConstants.perfilEndpoint),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _usernameController.text = (data['username'] ?? '').toString();
        _emailController.text = (data['email'] ?? '').toString();
        _telefonoController.text = (data['telefono'] ?? '').toString();
        setState(() => _error = null);
      } else {
        setState(() => _error = 'No se pudo cargar tu perfil.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo cargar tu perfil.');
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _guardando = true;
      _mensaje = null;
      _error = null;
    });

    try {
      final headers = await _headers();
      final body = jsonEncode({
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'telefono': _telefonoController.text.trim(),
      });

      final response = await http
          .patch(
            Uri.parse(ApiConstants.perfilEndpoint),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', _usernameController.text.trim());
        setState(() => _mensaje = 'Perfil actualizado correctamente.');
      } else {
        final data = jsonDecode(response.body);
        final errorMessage = data is Map<String, dynamic>
            ? (data['detail'] ??
                  data['error'] ??
                  'No se pudo actualizar el perfil.')
            : 'No se pudo actualizar el perfil.';
        setState(() => _error = errorMessage.toString());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo actualizar el perfil.');
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Mi perfil', style: TextStyle(letterSpacing: 1.2)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _gold, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'URBAN STUDIO',
                      style: TextStyle(
                        color: _gold,
                        letterSpacing: 4,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: _surface,
                        border: Border.all(color: _gold.withValues(alpha: 0.6)),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, size: 38, color: _gold),
                    ),
                    const SizedBox(height: 24),
                    _campo(
                      'Usuario',
                      _usernameController,
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Escribe tu usuario.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _campo(
                      'Correo electrónico',
                      _emailController,
                      teclado: TextInputType.emailAddress,
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Escribe tu correo.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _campo(
                      'Teléfono',
                      _telefonoController,
                      teclado: TextInputType.phone,
                    ),
                    const SizedBox(height: 26),
                    if (_mensaje != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _mensaje!,
                          style: const TextStyle(color: Colors.greenAccent),
                        ),
                      ),
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _guardando ? null : _guardarPerfil,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _guardando
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black,
                                  ),
                                ),
                              )
                            : const Text(
                                'GUARDAR CAMBIOS',
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _campo(
    String label,
    TextEditingController controller, {
    TextInputType teclado = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: teclado,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _gold),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ),
      ],
    );
  }
}
