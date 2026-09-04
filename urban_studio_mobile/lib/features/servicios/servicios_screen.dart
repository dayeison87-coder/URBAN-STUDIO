import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../citas/citas_screen.dart';

const _gold = Color(0xFFc9a96e);
const _bg = Color(0xFF0a0a0a);
const _card = Color(0xFF0f0f0f);

class ServiciosScreen extends StatefulWidget {
  const ServiciosScreen({super.key});

  @override
  State<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends State<ServiciosScreen> {
  List<dynamic> categorias = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    try {
      final response =
          await http.get(Uri.parse(ApiConstants.serviciosEndpoint));
      if (response.statusCode == 200) {
        setState(() {
          categorias = jsonDecode(response.body);
          cargando = false;
        });
      }
    } catch (e) {
      setState(() => cargando = false);
    }
  }

  final Map<String, String> _imagenes = {
  'cabello':  'assets/img/cabello.jpg',
  'barba':    'assets/img/barba.jpg',
  'rostro':   'assets/img/rostro.jpg',
  'productos':'assets/img/productos.jpg',
};

  void _abrirModal(dynamic categoria) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ModalServicios(categoria: categoria),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          // APP BAR
          SliverAppBar(
            backgroundColor: Colors.black.withOpacity(0.92),
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: _gold, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('urban studio',
                style: TextStyle(
                    color: _gold,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0.5),
              child: Container(height: 0.5, color: _gold.withOpacity(0.2)),
            ),
          ),

          // HERO
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: Colors.white.withOpacity(0.08))),
              ),
              child: Column(
                children: [
                  Text('URBAN STUDIO',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 6,
                          color: _gold,
                          fontWeight: FontWeight.w400)),
                  const SizedBox(height: 12),
                  const Text('SERVICIOS',
                      style: TextStyle(
                          fontSize: 36,
                          letterSpacing: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w300)),
                  const SizedBox(height: 8),
                  Text('ELIGE TU EXPERIENCIA',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 4,
                          color: Colors.white.withOpacity(0.3))),
                ],
              ),
            ),
          ),

          // LOADING
          if (cargando)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _gold)),
            ),

          // LISTA DE CATEGORÍAS
          if (!cargando)
            SliverPadding(
              padding: const EdgeInsets.all(2),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final cat = categorias[i];
                    final slug = cat['slug'] ?? '';
                    final imagen =
                        _imagenes[slug] ?? _imagenes['cabello']!;
                    final numeros = ['01', '02', '03', '04'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: GestureDetector(
                          onTap: () => _abrirModal(cat),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(imagen, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                Container(color: const Color(0xFF1a1a1a))),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.85),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 20, left: 24, right: 24,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        i < numeros.length
                                            ? numeros[i]
                                            : '0${i + 1}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            letterSpacing: 3,
                                            color: Colors.white
                                                .withOpacity(0.4))),
                                    const SizedBox(height: 6),
                                    Text(
                                        (cat['nombre'] ?? '')
                                            .toString()
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 28,
                                            letterSpacing: 3,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w300)),
                                    const SizedBox(height: 4),
                                    Text(
                                        (cat['descripcion'] ?? '')
                                            .toString()
                                            .toUpperCase(),
                                        style: TextStyle(
                                            fontSize: 10,
                                            letterSpacing: 2,
                                            color: Colors.white
                                                .withOpacity(0.5))),
                                    const SizedBox(height: 10),
                                    Text('VER SERVICIOS →',
                                        style: TextStyle(
                                            fontSize: 10,
                                            letterSpacing: 2,
                                            color: _gold,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 0, left: 0, right: 0,
                                child: Container(
                                    height: 2,
                                    color: _gold.withOpacity(0.6)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: categorias.length,
                ),
              ),
            ),

          // FOOTER
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: Colors.white.withOpacity(0.05))),
              ),
              child: Text('URBAN STUDIO — BOGOTÁ, COLOMBIA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 4,
                      color: Colors.white.withOpacity(0.2))),
            ),
          ),
        ],
      ),
    );
  }
}

// ── MODAL DE SERVICIOS ──────────────────────────────────────
class _ModalServicios extends StatelessWidget {
  final dynamic categoria;
  const _ModalServicios({required this.categoria});

  String _formatPrecio(dynamic precio) {
    final num = double.tryParse(precio.toString()) ?? 0;
    return '\$${num.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final servicios = categoria['servicios'] as List? ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0f0f0f),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('URBAN STUDIO',
                            style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 4,
                                color: _gold,
                                fontWeight: FontWeight.w400)),
                        const SizedBox(height: 6),
                        Text(
                            (categoria['nombre'] ?? '')
                                .toString()
                                .toUpperCase(),
                            style: const TextStyle(
                                fontSize: 26,
                                letterSpacing: 4,
                                color: Colors.white,
                                fontWeight: FontWeight.w300)),
                        const SizedBox(height: 4),
                        Text(
                            (categoria['descripcion'] ?? '')
                                .toString(),
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.4),
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: Colors.white.withOpacity(0.5)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Divider(
                color: Colors.white.withOpacity(0.08), height: 1),

            // Lista de servicios — cada uno con su botón reservar
            Expanded(
              child: servicios.isEmpty
                  ? Center(
                      child: Text(
                          'Próximamente servicios en esta categoría.',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 12,
                              letterSpacing: 1)))
                  : ListView.separated(
                      controller: controller,
                      padding:
                          const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: servicios.length,
                      separatorBuilder: (_, __) => Divider(
                          color: Colors.white.withOpacity(0.06),
                          height: 1),
                      itemBuilder: (_, i) {
                        final srv = servicios[i];
                        final disponible =
                            srv['disponible'] ?? true;
                        return Opacity(
                          opacity: disponible ? 1.0 : 0.4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(srv['nombre'] ?? '',
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Color(
                                                      0xFFc8c4bc),
                                                  letterSpacing: 0.5,
                                                  fontWeight:
                                                      FontWeight.w500)),
                                          if ((srv['descripcion'] ??
                                                  '')
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(srv['descripcion'],
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white
                                                        .withOpacity(
                                                            0.3),
                                                    letterSpacing:
                                                        0.3)),
                                          ],
                                          if (!disponible) ...[
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 6,
                                                  vertical: 2),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(
                                                            0.15)),
                                              ),
                                              child: Text(
                                                  'NO DISPONIBLE',
                                                  style: TextStyle(
                                                      fontSize: 7,
                                                      letterSpacing:
                                                          1.5,
                                                      color: Colors
                                                          .white
                                                          .withOpacity(
                                                              0.4))),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                        _formatPrecio(srv['precio']),
                                        style: const TextStyle(
                                            fontSize: 22,
                                            color: _gold,
                                            fontWeight: FontWeight.w300,
                                            letterSpacing: 1)),
                                  ],
                                ),

                                // Botón reservar por servicio
                                if (disponible) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CitasScreen(
                                              servicioPreseleccionado: srv,
                                              categoriaPreseleccionada: categoria,
                                            ),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                            color: _gold, width: 0.5),
                                        foregroundColor: _gold,
                                        padding: const EdgeInsets
                                            .symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    4)),
                                      ),
                                      child: Text(
                                          'RESERVAR — ${_formatPrecio(srv['precio'])}',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              letterSpacing: 3,
                                              fontWeight:
                                                  FontWeight.w500)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}