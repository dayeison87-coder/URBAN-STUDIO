import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../core/network/auth_service.dart';
import '../../core/theme/urban_theme.dart';
import '../../core/widgets/urban_ui.dart';
import '../barbero/barbero_dashboard_screen.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _submitting = false;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    final links = AppLinks();
    links.getInitialLink().then(_handleGoogleLink);
    _linkSubscription = links.uriLinkStream.listen(_handleGoogleLink);
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleLink(Uri? uri) async {
    if (uri == null || uri.scheme != 'urbanstudio' || uri.host != 'auth') return;
    try {
      if (await _authService.handleGoogleCallback(uri) && mounted) await _goToHome();
    } catch (_) {
      _showFeedback('No se pudo completar el acceso con Google.', isError: true);
    }
  }

  Future<void> _goToHome() async {
    final role = await _authService.getRole();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => role?.toLowerCase() == 'barbero'
            ? const BarberoDashboardScreen()
            : const HomeScreen(),
      ),
    );
  }

  Future<void> _handleGoogleLogin() async {
    try {
      await _authService.loginWithGoogle();
      if (mounted) await _goToHome();
    } catch (e) {
      _showFeedback(e.toString().replaceFirst('Bad state: ', ''), isError: true);
    }
  }

  Future<void> _handleSubmit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final email = _emailController.text.trim();
    if (username.isEmpty || password.isEmpty || (!_isLogin && email.isEmpty)) {
      _showFeedback('Por favor completa todos los campos.', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final success = _isLogin
          ? await _authService.login(username, password)
          : await _authService.register(username, email, password);
      if (!mounted) return;
      if (!success) {
        _showFeedback(
          _isLogin
              ? 'No se pudo iniciar sesión. Verifica tus credenciales.'
              : 'No se pudo crear la cuenta. Inténtalo de nuevo.',
          isError: true,
        );
      } else if (_isLogin) {
        await _goToHome();
      } else {
        _emailController.clear();
        _passwordController.clear();
        setState(() => _isLogin = true);
        _showFeedback('Cuenta creada. Ya puedes iniciar sesión.');
      }
    } catch (e) {
      _showFeedback(e.toString().replaceFirst('Bad state: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? UrbanColors.danger : const Color(0xFF2ECC71),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?q=80&w=2074&auto=format&fit=crop',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: UrbanColors.background),
          ),
          const ColoredBox(color: Color(0x35000000)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 42, 28, 32),
                  decoration: BoxDecoration(
                    color: const Color(0xC7343332),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: UrbanColors.gold.withValues(alpha: .35)),
                    boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 10))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: UrbanBrand(fontSize: 20, showName: false)),
                      const SizedBox(height: 18),
                      Text(_isLogin ? 'Iniciar sesión' : 'Nuevo registro', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(_isLogin ? 'Gestión inteligente para barberías' : 'Únete a Urban Studio', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 34),
                      _field(label: 'Usuario', controller: _usernameController, icon: Icons.person_outline, hint: _isLogin ? 'Ingresa tu usuario' : 'Elige un nombre de usuario', textInputAction: TextInputAction.next),
                      if (!_isLogin) ...[
                        const SizedBox(height: 20),
                        _field(label: 'Correo electrónico', controller: _emailController, icon: Icons.mail_outline, hint: 'tucorreo@email.com', keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next),
                      ],
                      const SizedBox(height: 20),
                      _field(
                        label: 'Contraseña', controller: _passwordController, icon: Icons.lock_outline, hint: '••••••••', obscureText: _obscurePassword,
                        suffix: IconButton(onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined), color: Colors.white70, tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña'),
                        onSubmitted: (_) => _handleSubmit(),
                      ),
                      const SizedBox(height: 28),
                      _primaryButton(),
                      const SizedBox(height: 14),
                      if (_isLogin) ...[
                        _outlinedButton('Continuar con Google', Icons.account_circle_outlined, _handleGoogleLogin),
                        const SizedBox(height: 14),
                      ],
                      _outlinedButton(_isLogin ? 'Crear cuenta' : '¿Ya tienes cuenta? Inicia sesión', null, () => setState(() => _isLogin = !_isLogin)),
                      const SizedBox(height: 28),
                      const Row(children: [Expanded(child: Divider(color: Color(0x44FFFFFF))), Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Text('ACCESO SEGURO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1))), Expanded(child: Divider(color: Color(0x44FFFFFF)))]),
                      const SizedBox(height: 14),
                      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield_outlined, size: 14, color: Colors.white), SizedBox(width: 8), Flexible(child: Text('Conexión segura • Tus datos están protegidos', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11)))]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({required String label, required TextEditingController controller, required IconData icon, required String hint, TextInputType? keyboardType, TextInputAction? textInputAction, bool obscureText = false, Widget? suffix, ValueChanged<String>? onSubmitted}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 10), Text(label.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .5))]),
      const SizedBox(height: 8),
      TextField(controller: controller, keyboardType: keyboardType, textInputAction: textInputAction, obscureText: obscureText, onSubmitted: onSubmitted, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: hint, suffixIcon: suffix, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0x22FFFFFF))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: UrbanColors.gold, width: 1.3)), fillColor: const Color(0x0DFFFFFF))),
    ],
  );

  Widget _primaryButton() => FilledButton.icon(
    onPressed: _submitting ? null : _handleSubmit,
    icon: _submitting ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_forward, size: 20),
    label: Text(_isLogin ? 'INICIAR SESIÓN' : 'CREAR CUENTA'),
    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE6BB3F), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(54), shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
  );

  Widget _outlinedButton(String label, IconData? icon, VoidCallback onPressed) => OutlinedButton.icon(
    onPressed: _submitting ? null : onPressed,
    icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20), label: Text(label),
    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52), side: const BorderSide(color: Color(0x22FFFFFF)), shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
  );
}
