import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../auth/login_screen.dart';

const _bg = Color(0xFF0A0A0A);
const _surface = Color(0xFF111111);
const _gold = Color(0xFFC9A96E);
const _line = Color(0xFF1D1D1D);
const _muted = Color(0xFFB7B7B7);

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _actualController = TextEditingController();
  final _nuevaController = TextEditingController();
  final _confirmacionController = TextEditingController();

  bool _notificaciones = true;
  bool _recordatorios = true;
  bool _perfilVisible = true;
  bool _guardando = false;
  String? _mensaje;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  @override
  void dispose() {
    _actualController.dispose();
    _nuevaController.dispose();
    _confirmacionController.dispose();
    super.dispose();
  }

  Future<void> _cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificaciones = prefs.getBool('preferencias_notificaciones') ?? true;
      _recordatorios = prefs.getBool('preferencias_recordatorios') ?? true;
      _perfilVisible = prefs.getBool('preferencias_perfil_visible') ?? true;
    });
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _guardarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('preferencias_notificaciones', _notificaciones);
    await prefs.setBool('preferencias_recordatorios', _recordatorios);
    await prefs.setBool('preferencias_perfil_visible', _perfilVisible);

    if (mounted) {
      setState(() => _mensaje = 'Preferencias guardadas correctamente.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferencias guardadas correctamente.')),
      );
    }
  }

  Future<void> _cambiarPassword() async {
    if (_actualController.text.trim().isEmpty ||
        _nuevaController.text.trim().isEmpty ||
        _confirmacionController.text.trim().isEmpty) {
      setState(() => _error = 'Completa los tres campos de contraseña.');
      return;
    }

    if (_nuevaController.text.trim() != _confirmacionController.text.trim()) {
      setState(
        () => _error = 'La nueva contraseña y su confirmación no coinciden.',
      );
      return;
    }

    if (_nuevaController.text.trim().length < 8) {
      setState(
        () => _error = 'La nueva contraseña debe tener mínimo 8 caracteres.',
      );
      return;
    }

    setState(() {
      _guardando = true;
      _mensaje = null;
      _error = null;
    });

    try {
      final headers = await _headers();
      final response = await http
          .patch(
            Uri.parse('${ApiConstants.baseUrl}/configuracion/cuenta/'),
            headers: headers,
            body: jsonEncode({
              'password_actual': _actualController.text.trim(),
              'password_nueva': _nuevaController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _actualController.clear();
        _nuevaController.clear();
        _confirmacionController.clear();
        setState(() => _mensaje = 'Contraseña actualizada correctamente.');
      } else {
        final data = jsonDecode(response.body);
        final msg = data is Map<String, dynamic>
            ? (data['password_actual'] ??
                  data['error'] ??
                  'No se pudo actualizar la contraseña.')
            : 'No se pudo actualizar la contraseña.';
        setState(() => _error = msg.toString());
      }
    } catch (_) {
      setState(() => _error = 'No se pudo actualizar la contraseña.');
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Configuración',
          style: TextStyle(letterSpacing: 1.2),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _gold, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PREFERENCIAS',
              style: TextStyle(
                color: _gold,
                letterSpacing: 3,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            _switchTile('Notificaciones', _notificaciones, (value) {
              setState(() => _notificaciones = value);
              _guardarPreferencias();
            }),
            _switchTile('Recordatorios', _recordatorios, (value) {
              setState(() => _recordatorios = value);
              _guardarPreferencias();
            }),
            _switchTile('Perfil visible', _perfilVisible, (value) {
              setState(() => _perfilVisible = value);
              _guardarPreferencias();
            }),
            const SizedBox(height: 28),
            const Text(
              'SEGURIDAD',
              style: TextStyle(
                color: _gold,
                letterSpacing: 3,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            _passwordField('Contraseña actual', _actualController),
            const SizedBox(height: 12),
            _passwordField('Nueva contraseña', _nuevaController),
            const SizedBox(height: 12),
            _passwordField(
              'Confirmar nueva contraseña',
              _confirmacionController,
            ),
            const SizedBox(height: 20),
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
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
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
                onPressed: _guardando ? null : _cambiarPassword,
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
                        'ACTUALIZAR CONTRASEÑA',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _cerrarSesion,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'CERRAR SESIÓN',
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
    );
  }

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          value ? 'Activado' : 'Desactivado',
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
        value: value,
        activeThumbColor: _gold,
        onChanged: onChanged,
      ),
    );
  }

  Widget _passwordField(String label, TextEditingController controller) {
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
        TextField(
          controller: controller,
          obscureText: true,
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
          ),
        ),
      ],
    );
  }
}
