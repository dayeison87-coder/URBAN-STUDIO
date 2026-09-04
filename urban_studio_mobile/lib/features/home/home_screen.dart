import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../models/testimonio.dart';
import '../../core/network/auth_service.dart';
import '../auth/login_screen.dart';
import '../servicios/servicios_screen.dart';
import '../citas/citas_screen.dart';
import '../barberos/barberos_screen.dart';
import '../facial_analysis/analysis_screen.dart';
import '../perfil/perfil_screen.dart';
import '../configuracion/configuracion_screen.dart';
import '../barbero/barbero_dashboard_screen.dart';

const _colorFondo = Color(0xFF0A0A0A);
const _colorSuperficie = Color(0xFF0F0F0F);
const _colorLinea = Color(0xFF1A1A1A);
const _colorDorado = Color(0xFFD4AF37);
const _colorDoradoClaro = Color(0xFFC9A96E);
const _colorTextoMuted = Color(0xFF7A7A7A);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  String _nombreUsuario = 'Usuario';
  String? _rol;
  List<Testimonio> _testimonios = [];
  bool _cargandoTestimonios = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
    _cargarTestimonios();
  }

  Future<void> _cargarTestimonios() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.testimoniosEndpoint),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _testimonios = data.map((j) => Testimonio.fromJson(j)).toList();
          _cargandoTestimonios = false;
        });
      } else {
        setState(() => _cargandoTestimonios = false);
      }
    } catch (e) {
      print('Error cargando testimonios en Home: $e');
      setState(() => _cargandoTestimonios = false);
    }
  }

  Future<void> _cargarUsuario() async {
    final nombre = await _authService.getUsername();
    final rol = await _authService.getRole();
    if (mounted) setState(() {
      _nombreUsuario = nombre;
      _rol = rol;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _irServicios() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ServiciosScreen()),
    );
  }

  // 👈 Método para redirigir a la pantalla de citas
  void _irCitas() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CitasScreen()),
    );
  }

  void _proximamente(String funcion) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$funcion — próximamente')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorFondo,
      appBar: _construirAppBar(),
      drawer: _construirDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _construirHero(context),
            _construirServicios(),
            _construirPorQue(),
            _construirTestimonios(),
            _construirCtaFinal(),
            _construirFooter(),
          ],
        ),
      ),
    );
  }

  // ══════════════ APP BAR ══════════════
  PreferredSizeWidget _construirAppBar() {
    return AppBar(
      backgroundColor: Colors.black.withOpacity(0.92),
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.content_cut, color: _colorDorado, size: 18),
          SizedBox(width: 8),
          Text(
            'urban studio',
            style: TextStyle(
              color: _colorDorado,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnalysisScreen()),
          ),
          icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.black),
          label: const Text(
            'IA Estilo',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          style: TextButton.styleFrom(
            backgroundColor: _colorDorado,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ══════════════ DRAWER ══════════════
  Widget _construirDrawer() {
    return Drawer(
      backgroundColor: _colorSuperficie,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.content_cut, color: _colorDorado, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'urban studio',
                        style: TextStyle(
                          color: _colorDorado,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hola, $_nombreUsuario',
                    style: const TextStyle(
                      color: _colorTextoMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: _colorLinea, height: 1),
            _itemDrawer(
              Icons.home_outlined,
              'Inicio',
              () => Navigator.pop(context),
            ),
            _itemDrawer(Icons.content_cut, 'Servicios', () {
              Navigator.pop(context);
              _irServicios();
            }),
            _itemDrawer(Icons.calendar_month_outlined, 'Citas', () {
              Navigator.pop(context);
              _irCitas();
            }),
            _itemDrawer(Icons.people_outline, 'Barberos', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BarberosScreen()),
              );
            }),
            if (_rol?.toLowerCase() == 'barbero')
              _itemDrawer(Icons.dashboard_outlined, 'Panel de barbero', () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BarberoDashboardScreen(),
                  ),
                );
              }),
            _itemDrawer(Icons.auto_awesome, 'IA Estilo', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalysisScreen()),
              );
            }),
            _itemDrawer(Icons.person_outline, 'Mi perfil', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PerfilScreen()),
              );
            }),
            _itemDrawer(Icons.settings_outlined, 'Configuración', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConfiguracionScreen()),
              );
            }),
            const Spacer(),
            const Divider(color: _colorLinea, height: 1),
            _itemDrawer(
              Icons.logout,
              'Cerrar sesión',
              _logout,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _itemDrawer(
    IconData icon,
    String texto,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? _colorTextoMuted, size: 20),
      title: Text(
        texto,
        style: TextStyle(color: color ?? Colors.white70, fontSize: 14),
      ),
      onTap: onTap,
    );
  }

  // ══════════════ HERO ══════════════
  Widget _construirHero(BuildContext context) {
    final alturaPantalla = MediaQuery.of(context).size.height;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: alturaPantalla * 0.85),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(
            'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=1200',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.black.withOpacity(0.85),
              Colors.black.withOpacity(0.95),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'BIENVENIDO A URBAN STUDIO',
              style: TextStyle(
                color: _colorDoradoClaro,
                fontSize: 11,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tu Estilo,\nNuestra Pasión',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w300,
                letterSpacing: 3,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cortes modernos, clásicos y atención premium.',
              style: TextStyle(
                color: _colorTextoMuted,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _irCitas, // 👈 Redirige a citas en vez de "próximamente"
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colorDoradoClaro,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child: const Text(
                  'RESERVAR CITA',
                  style: TextStyle(
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _irServicios,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _colorDoradoClaro,
                  side: BorderSide(color: _colorDoradoClaro.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child: const Text(
                  'VER SERVICIOS',
                  style: TextStyle(letterSpacing: 3, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                border: Border.all(color: _colorLinea),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  _Stat(numero: '500+', etiqueta: 'CLIENTES FELICES'),
                  _DivisorVertical(),
                  _Stat(numero: '5+', etiqueta: 'AÑOS DE EXPERIENCIA'),
                  _DivisorVertical(),
                  _Stat(
                    numero: '4.9',
                    etiqueta: 'VALORACIÓN PROMEDIO',
                    icono: Icons.star,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════ SERVICIOS ══════════════
  Widget _construirServicios() {
    final servicios = [
      (
        icono: Icons.content_cut,
        titulo: 'Cabello',
        desc: 'Cortes clásicos, modernos y degradados con técnicas premium.',
        precio: 'Desde \$20.000',
        destacado: false,
      ),
      (
        icono: Icons.face_retouching_natural,
        titulo: 'Barba',
        desc: 'Afeitado clásico, perfilado y diseño de barba a tu medida.',
        precio: 'Desde \$25.000',
        destacado: false,
      ),
      (
        icono: Icons.spa_outlined,
        titulo: 'Rostro',
        desc: 'Tratamientos faciales, hidratación y cuidado de la piel.',
        precio: 'Desde \$35.000',
        destacado: false,
      ),
      (
        icono: Icons.smart_toy_outlined,
        titulo: 'IA Estilo',
        desc:
            'Análisis facial inteligente que recomienda el corte ideal para ti.',
        precio: 'Incluido',
        destacado: true,
      ),
    ];

    return Container(
      color: _colorFondo,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
      child: Column(
        children: [
          _encabezadoSeccion(
            'LO QUE OFRECEMOS',
            'Nuestros Servicios',
            'Cada servicio está diseñado para resaltar tu mejor versión',
          ),
          const SizedBox(height: 36),
          Column(
            children: servicios
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: _tarjetaServicio(s),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: _irServicios,
            style: OutlinedButton.styleFrom(
              foregroundColor: _colorDoradoClaro,
              side: const BorderSide(color: _colorDoradoClaro),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
            child: const Text(
              'VER TODOS LOS SERVICIOS →',
              style: TextStyle(fontSize: 11, letterSpacing: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaServicio(
    ({
      IconData icono,
      String titulo,
      String desc,
      String precio,
      bool destacado,
    })
    s,
  ) {
    return Container(
      width: double.infinity,
      color: s.destacado ? _colorDorado.withOpacity(0.05) : _colorSuperficie,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(s.icono, size: 32, color: _colorDorado),
          const SizedBox(height: 14),
          Text(
            s.titulo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.desc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _colorTextoMuted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            s.precio,
            style: const TextStyle(
              color: _colorDorado,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════ POR QUÉ ══════════════
  Widget _construirPorQue() {
    final items = [
      (
        icono: Icons.emoji_events_outlined,
        titulo: 'Barberos expertos',
        desc:
            'Profesionales con años de experiencia y certificaciones internacionales.',
      ),
      (
        icono: Icons.calendar_today_outlined,
        titulo: 'Reservas online',
        desc:
            'Agenda tu cita en segundos, elige tu barbero y horario favorito.',
      ),
      (
        icono: Icons.chat_bubble_outline,
        titulo: 'Chat directo',
        desc: 'Habla directamente con tu barbero antes y después de tu cita.',
      ),
      (
        icono: Icons.auto_awesome,
        titulo: 'IA personalizada',
        desc:
            'Tecnología de análisis facial para recomendarte el mejor estilo.',
      ),
    ];

    return Container(
      color: const Color(0xFF060606),
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
      child: Column(
        children: [
          _encabezadoSeccion(
            'NUESTRA DIFERENCIA',
            '¿Por qué Urban Studio?',
            null,
          ),
          const SizedBox(height: 32),
          ...items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(
                children: [
                  Icon(i.icono, size: 26, color: _colorDorado),
                  const SizedBox(height: 12),
                  Text(
                    i.titulo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    i.desc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _colorTextoMuted,
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════ TESTIMONIOS ══════════════
  Widget _construirTestimonios() {
    return Container(
      color: _colorFondo,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
      child: Column(
        children: [
          _encabezadoSeccion('LO QUE DICEN', 'Testimonios', null),
          const SizedBox(height: 32),
          if (_cargandoTestimonios)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(color: _colorDoradoClaro),
            )
          else if (_testimonios.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(
                    child: Text(
                      'No hay reseñas recientes. ¡Sé el primero en calificar tu cita!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _colorTextoMuted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: _colorDoradoClaro,
                  ),
                ],
              ),
            )
          else
            ..._testimonios.map(
              (t) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 1),
                color: _colorSuperficie,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        t.estrellas,
                        (_) => const Icon(
                          Icons.star,
                          size: 14,
                          color: _colorDoradoClaro,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '"${t.comentario}"',
                      style: const TextStyle(
                        color: Color(0xFF7A7A7A),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _colorLinea,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _colorDorado.withOpacity(0.3),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            t.inicial,
                            style: const TextStyle(
                              color: _colorDorado,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.clienteUsername,
                              style: const TextStyle(
                                color: Color(0xFFC8C4BC),
                                fontSize: 12,
                              ),
                            ),
                            const Text(
                              'Cliente Verificado',
                              style: TextStyle(
                                color: Color(0xFF4A4A4A),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════ CTA FINAL ══════════════
  Widget _construirCtaFinal() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1510), Color(0xFF0A0A0A)],
        ),
        border: Border(top: BorderSide(color: _colorLinea)),
      ),
      child: Column(
        children: [
          const Text(
            '¿LISTO PARA EL CAMBIO?',
            style: TextStyle(
              color: _colorDoradoClaro,
              fontSize: 10,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'RESERVA TU CITA HOY',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w300,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Elige tu barbero, servicio y horario en menos de 2 minutos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _colorTextoMuted, fontSize: 11),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _irCitas, // 👈 Redirige a citas en vez de "próximamente"
              style: ElevatedButton.styleFrom(
                backgroundColor: _colorDoradoClaro,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              child: const Text(
                'RESERVAR AHORA →',
                style: TextStyle(
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════ FOOTER ══════════════
  Widget _construirFooter() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF060606),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.content_cut, color: _colorDorado, size: 16),
              const SizedBox(width: 8),
              const Text(
                'urban studio',
                style: TextStyle(
                  color: _colorDorado,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Estilo premium para el hombre moderno.',
            style: TextStyle(color: Color(0xFF3A3A3A), fontSize: 10),
          ),
          const SizedBox(height: 20),
          const Text(
            '© 2026 Urban Studio. Todos los derechos reservados.',
            style: TextStyle(color: Color(0xFF2A2A2A), fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _encabezadoSeccion(String eyebrow, String titulo, String? sub) {
    return Column(
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: _colorDoradoClaro,
            fontSize: 10,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 8),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _colorTextoMuted, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String numero;
  final String etiqueta;
  final IconData? icono;
  const _Stat({required this.numero, required this.etiqueta, this.icono});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              numero,
              style: const TextStyle(color: _colorDoradoClaro, fontSize: 20),
            ),
            if (icono != null) ...[
              const SizedBox(width: 3),
              Icon(icono, size: 14, color: _colorDoradoClaro),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          etiqueta,
          style: const TextStyle(
            color: Color(0xFF5A5A5A),
            fontSize: 8,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _DivisorVertical extends StatelessWidget {
  const _DivisorVertical();
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: _colorLinea);
  }
}
