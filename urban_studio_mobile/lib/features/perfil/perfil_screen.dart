import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/api_constants.dart';
import '../../core/theme/urban_theme.dart';
import '../../core/widgets/urban_ui.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  String? _message;
  String? _error;
  String? _photoUrl;
  XFile? _photoFile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    return {'Authorization': 'Bearer ${prefs.getString('access_token') ?? ''}'};
  }

  String? _absolutePhotoUrl(dynamic value) {
    final path = value?.toString();
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '${Uri.parse(ApiConstants.baseUrl).origin}${path.startsWith('/') ? path : '/$path'}';
  }

  Future<void> _loadProfile() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConstants.perfilClienteEndpoint), headers: await _headers())
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _username.text = '${data['username'] ?? ''}';
        _email.text = '${data['email'] ?? ''}';
        _telefono.text = '${data['telefono'] ?? ''}';
        setState(() => _photoUrl = _absolutePhotoUrl(data['foto']));
      } else {
        setState(() => _error = 'No se pudo cargar tu perfil.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar tu perfil.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file != null && mounted) {
        setState(() {
          _photoFile = file;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo seleccionar la foto.');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _telefono.text.replaceAll(RegExp(r'\D'), '');
    if (phone.isNotEmpty && (phone.length < 7 || phone.length > 15)) {
      setState(() => _error = 'El teléfono debe tener entre 7 y 15 dígitos.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
      _error = null;
    });
    try {
      final request = http.MultipartRequest('PATCH', Uri.parse(ApiConstants.perfilClienteEndpoint));
      request.headers.addAll(await _headers());
      request.fields.addAll({
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'telefono': phone,
      });
      if (_photoFile != null) {
        request.files.add(await http.MultipartFile.fromPath('foto', _photoFile!.path));
      }
      final response = await request.send().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = await response.stream.bytesToString();
        final data = body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', _username.text.trim());
        setState(() {
          _photoUrl = _absolutePhotoUrl(data['foto']) ?? _photoUrl;
          _photoFile = null;
          _message = 'Perfil actualizado correctamente.';
        });
      } else {
        setState(() => _error = 'No se pudo actualizar el perfil.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar el perfil. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new, color: UrbanColors.gold, size: 18)),
        title: const UrbanBrand(fontSize: 16),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: UrbanColors.gold))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const UrbanEyebrow('Cuenta', center: false),
                      const SizedBox(height: 8),
                      const Text('MI PERFIL', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w300, letterSpacing: 3, color: UrbanColors.text)),
                      const SizedBox(height: 8),
                      const Text('Administra tus datos personales y preferencias de contacto.', style: TextStyle(fontSize: 12, color: UrbanColors.muted)),
                      const SizedBox(height: 26),
                      _profileCard(),
                      const SizedBox(height: 16),
                      _formCard(),
                      if (_message != null || _error != null) ...[
                        const SizedBox(height: 16),
                        _feedback(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _profileCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(color: UrbanColors.surface, border: Border.all(color: UrbanColors.line)),
    child: Column(
      children: [
        _avatar(),
        const SizedBox(height: 16),
        Text(_username.text.isEmpty ? 'Cliente' : _username.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400, letterSpacing: 1.5, color: UrbanColors.text)),
        const SizedBox(height: 5),
        const Text('CLIENTE URBAN STUDIO', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: UrbanColors.muted)),
        const SizedBox(height: 20),
        OutlinedButton.icon(onPressed: _pickPhoto, icon: const Icon(Icons.camera_alt_outlined, size: 17), label: const Text('CAMBIAR FOTO'), style: OutlinedButton.styleFrom(foregroundColor: UrbanColors.gold, side: const BorderSide(color: UrbanColors.gold), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero))),
      ],
    ),
  );

  Widget _avatar() => Container(
    width: 128,
    height: 128,
    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: UrbanColors.gold), color: UrbanColors.surfaceElevated),
    clipBehavior: Clip.antiAlias,
    child: _photoFile != null
        ? Image.file(File(_photoFile!.path), fit: BoxFit.cover)
        : _photoUrl != null
            ? Image.network(_photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initial())
            : _initial(),
  );

  Widget _initial() => Center(child: Text(_username.text.isEmpty ? 'C' : _username.text[0].toUpperCase(), style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w300, color: UrbanColors.gold)));

  Widget _formCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: UrbanColors.surface, border: Border.all(color: UrbanColors.line)),
    child: Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('INFORMACIÓN PERSONAL', style: TextStyle(fontSize: 11, letterSpacing: 2, color: UrbanColors.gold)), Icon(Icons.person_outline, color: UrbanColors.gold)]),
        const Divider(height: 28),
        _field('Nombre de usuario', _username, validator: (value) => (value ?? '').trim().isEmpty ? 'Escribe tu usuario.' : null),
        const SizedBox(height: 16),
        _field('Correo electrónico', _email, keyboard: TextInputType.emailAddress, validator: (value) => (value ?? '').contains('@') ? null : 'Escribe un correo válido.'),
        const SizedBox(height: 16),
        _field('Teléfono', _telefono, keyboard: TextInputType.phone, maxLength: 15),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _saveProfile, icon: _saving ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.check), label: Text(_saving ? 'GUARDANDO...' : 'GUARDAR CAMBIOS'), style: FilledButton.styleFrom(backgroundColor: UrbanColors.gold, foregroundColor: UrbanColors.background, minimumSize: const Size.fromHeight(48), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.5)))),
      ]),
    ),
  );

  Widget _field(String label, TextEditingController controller, {TextInputType? keyboard, int? maxLength, String? Function(String?)? validator}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1, color: UrbanColors.muted)),
    const SizedBox(height: 7),
    TextFormField(controller: controller, keyboardType: keyboard, maxLength: maxLength, validator: validator, style: const TextStyle(color: UrbanColors.text), decoration: const InputDecoration(counterText: '', contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 13))),
  ]);

  Widget _feedback() => Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: (_error == null ? Colors.green : UrbanColors.danger).withValues(alpha: .10), border: Border.all(color: (_error == null ? Colors.green : UrbanColors.danger).withValues(alpha: .45))), child: Text(_error ?? _message!, style: TextStyle(color: _error == null ? Colors.greenAccent : UrbanColors.danger)));
}
