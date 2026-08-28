import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';

const _gold = Color(0xFFc9a96e);
const _bg = Color(0xFF0a0a0a);
const _card = Color(0xFF0f0f0f);

class BarberosScreen extends StatefulWidget {
  const BarberosScreen({super.key});

  @override
  State<BarberosScreen> createState() => _BarberosScreenState();
}

class _BarberosScreenState extends State<BarberosScreen> {
  List<dynamic> barberos = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarBarberos();
  }

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> _cargarBarberos() async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(
        Uri.parse(ApiConstants.barberosEndpoint), headers: headers);
      if (res.statusCode == 200) {
        setState(() { barberos = jsonDecode(res.body); cargando = false; });
      }
    } catch (e) {
      setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.92),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _gold, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('✂ urban studio',
          style: TextStyle(color: _gold, fontSize: 18,
            fontWeight: FontWeight.bold, letterSpacing: 2)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _gold.withOpacity(0.2))),
      ),
      body: CustomScrollView(
        slivers: [

          // HERO
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(
                  color: Colors.white.withOpacity(0.06)))),
              child: Column(
                children: [
                  Text('URBAN STUDIO', style: TextStyle(fontSize: 10,
                    letterSpacing: 6, color: _gold)),
                  const SizedBox(height: 10),
                  const Text('NUESTRO EQUIPO', style: TextStyle(fontSize: 30,
                    letterSpacing: 8, color: Colors.white,
                    fontWeight: FontWeight.w300)),
                  const SizedBox(height: 6),
                  Text('PROFESIONALES A TU SERVICIO',
                    style: TextStyle(fontSize: 9, letterSpacing: 3,
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

          // LISTA DE BARBEROS
          if (!cargando && barberos.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text('No hay barberos registrados.',
                  style: TextStyle(color: Colors.white.withOpacity(0.3),
                    fontSize: 13, letterSpacing: 1)),
              ),
            ),

          if (!cargando && barberos.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _tarjetaBarbero(barberos[i], i),
                  childCount: barberos.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tarjetaBarbero(dynamic barbero, int index) {
    final inicial = (barbero['username'] ?? 'B')[0].toUpperCase();
    final telefono = barbero['telefono'];
    final descripcion = barbero['descripcion'];
    final experiencia = barbero['experiencia'];
    final foto = barbero['foto'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Foto o inicial
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _gold.withOpacity(0.4), width: 1.5),
                color: _gold.withOpacity(0.05),
              ),
              child: ClipOval(
                child: foto != null && foto.toString().isNotEmpty
                  ? Image.network(
                      'http://10.237.179.62:8000$foto',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(inicial, style: const TextStyle(
                          color: _gold, fontSize: 24, fontWeight: FontWeight.w300))),
                    )
                  : Center(child: Text(inicial, style: const TextStyle(
                      color: _gold, fontSize: 24, fontWeight: FontWeight.w300))),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(barbero['username'] ?? '',
                        style: const TextStyle(color: Colors.white,
                          fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 1)),
                      Text('0${index + 1}', style: TextStyle(fontSize: 10,
                        letterSpacing: 2, color: Colors.white.withOpacity(0.2))),
                    ],
                  ),

                  if (experiencia != null) ...[
                    const SizedBox(height: 4),
                    Text('$experiencia años de experiencia',
                      style: TextStyle(fontSize: 11, color: _gold.withOpacity(0.8))),
                  ],

                  if (descripcion != null && descripcion.toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(descripcion.toString(),
                      style: TextStyle(fontSize: 11,
                        color: Colors.white.withOpacity(0.4), height: 1.5)),
                  ],

                  if (telefono != null && telefono.toString().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 12,
                          color: Colors.white.withOpacity(0.3)),
                        const SizedBox(width: 6),
                        Text(telefono.toString(),
                          style: TextStyle(fontSize: 11,
                            color: Colors.white.withOpacity(0.3))),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        // Navegar a citas con este barbero preseleccionado
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _gold,
                        side: BorderSide(color: _gold.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2)),
                      ),
                      child: const Text('RESERVAR CON ESTE BARBERO',
                        style: TextStyle(fontSize: 9, letterSpacing: 2)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}