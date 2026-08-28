import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';

const _gold = Color(0xFFc9a96e);
const _bg = Color(0xFF0a0a0a);
const _card = Color(0xFF0f0f0f);
const _line = Color(0xFF1a1a1a);

class CitasScreen extends StatefulWidget {
  // Si vienes desde "Servicios" tocando una categoría, estos ya llegan
  // preseleccionados y el wizard arranca directo en "Elegir barbero"
  // (se salta el paso de escoger servicio).
  final dynamic categoriaInicial;
  final dynamic servicioInicial;
  final dynamic servicioPreseleccionado;
  final dynamic categoriaPreseleccionada;

  const CitasScreen({
    super.key,
    this.categoriaInicial,
    this.servicioInicial,
    this.servicioPreseleccionado,
    this.categoriaPreseleccionada,
  });

  @override
  State<CitasScreen> createState() => _CitasScreenState();
}

class _CitasScreenState extends State<CitasScreen> {
  int paso = 0;
  String mensaje = '';
  int? editandoId;

  List<dynamic> categorias = [];
  List<dynamic> barberos = [];
  List<dynamic> listaCitas = [];
  List<dynamic> disponibilidades = [];

  dynamic categoriaSeleccionada;
  dynamic servicioSeleccionado;
  dynamic barberoSeleccionado;
  String fechaSeleccionada = '';
  String horaSeleccionada = '';

  DateTime mesActual = DateTime.now();
  List<DateTime?> diasCalendario = [];

  final List<String> horariosBase = [
    '09:00',
    '09:30',
    '10:00',
    '10:30',
    '11:00',
    '11:30',
    '12:00',
    '12:30',
    '14:00',
    '14:30',
    '15:00',
    '15:30',
    '16:00',
    '16:30',
    '17:00',
    '17:30',
  ];

  final List<String> diasSemana = [
    'Dom',
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
  ];
  final List<String> meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _generarCalendario();
    _cargarDatos().then((_) {
      if (widget.servicioPreseleccionado != null) {
        setState(() {
          servicioSeleccionado = widget.servicioPreseleccionado;
          categoriaSeleccionada = widget.categoriaPreseleccionada;
          paso = 2;
        });
      }
    });
  }

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _cargarDatos() async {
    await Future.wait([_cargarCategorias(), _cargarBarberos(), _cargarCitas()]);
  }

  Future<void> _cargarCategorias() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.serviciosEndpoint));
      if (res.statusCode == 200) {
        setState(() => categorias = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error categorías: $e');
    }
  }

  Future<void> _cargarBarberos() async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(
        Uri.parse(ApiConstants.barberosEndpoint),
        headers: headers,
      );
      if (res.statusCode == 200) {
        setState(() => barberos = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error barberos: $e');
    }
  }

  Future<void> _cargarCitas() async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(
        Uri.parse(ApiConstants.citasEndpoint),
        headers: headers,
      );
      if (res.statusCode == 200) {
        setState(() => listaCitas = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error citas: $e');
    }
  }

  void _generarCalendario() {
    final primerDia = DateTime(mesActual.year, mesActual.month, 1);
    final diasEnMes = DateTime(mesActual.year, mesActual.month + 1, 0).day;
    diasCalendario = [];
    for (int i = 0; i < primerDia.weekday % 7; i++) diasCalendario.add(null);
    for (int d = 1; d <= diasEnMes; d++) {
      diasCalendario.add(DateTime(mesActual.year, mesActual.month, d));
    }
  }

  String _formatFecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _esPasado(DateTime d) {
    final hoy = DateTime.now();
    return d.isBefore(DateTime(hoy.year, hoy.month, hoy.day));
  }

  List<String> _horariosOcupados() {
    return listaCitas
        .where(
          (c) =>
              c['fecha'] == fechaSeleccionada &&
              c['barbero'] == barberoSeleccionado?['id'] &&
              c['id'] != editandoId,
        )
        .map((c) => (c['hora'] as String).substring(0, 5))
        .toList();
  }

  Future<void> _cargarDisponibilidad(int barberoId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(
        '${ApiConstants.disponibilidadEndpoint}?barbero=$barberoId',
      );
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200 && mounted) {
        setState(() => disponibilidades = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error disponibilidad: $e');
    }
  }

  Future<void> _seleccionarBarbero(dynamic barbero) async {
    setState(() {
      barberoSeleccionado = barbero;
      fechaSeleccionada = '';
      horaSeleccionada = '';
      disponibilidades = [];
    });
    await _cargarDisponibilidad(barbero['id']);
  }

  String _diaSemana(DateTime fecha) {
    const dias = [
      'domingo',
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
    ];
    return dias[fecha.weekday % 7];
  }

  String _normalizarDia(String dia) {
    return dia
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  List<String> _horariosDelDia(String fecha) {
    final partes = fecha.split('-').map(int.parse).toList();
    final fechaDateTime = DateTime(partes[0], partes[1], partes[2]);
    final jornada = disponibilidades.cast<dynamic>().firstWhere(
      (horario) =>
          _normalizarDia(horario['dia_semana']) == _diaSemana(fechaDateTime),
      orElse: () => null,
    );
    if (jornada == null) return [];

    final inicio = (jornada['hora_inicio'] as String)
        .substring(0, 5)
        .split(':')
        .map(int.parse)
        .toList();
    final fin = (jornada['hora_fin'] as String)
        .substring(0, 5)
        .split(':')
        .map(int.parse)
        .toList();
    final inicioMinutos = inicio[0] * 60 + inicio[1];
    final finMinutos = fin[0] * 60 + fin[1];
    return [
      for (
        int minutos = inicioMinutos;
        minutos + 30 <= finMinutos;
        minutos += 30
      )
        '${(minutos ~/ 60).toString().padLeft(2, '0')}:${(minutos % 60).toString().padLeft(2, '0')}',
    ];
  }

  Future<void> _confirmarCita() async {
    if (servicioSeleccionado == null ||
        barberoSeleccionado == null ||
        fechaSeleccionada.isEmpty ||
        horaSeleccionada.isEmpty) {
      setState(() => mensaje = 'Completa todos los pasos.');
      return;
    }

    final headers = await _getHeaders();
    final payload = jsonEncode({
      'servicio': servicioSeleccionado['id'],
      'barbero': barberoSeleccionado['id'],
      'fecha': fechaSeleccionada,
      'hora': '$horaSeleccionada:00',
      'estado': 'Pendiente',
    });

    try {
      http.Response res;
      if (editandoId != null) {
        res = await http.put(
          Uri.parse('${ApiConstants.citasEndpoint}$editandoId/'),
          headers: headers,
          body: payload,
        );
      } else {
        res = await http.post(
          Uri.parse(ApiConstants.citasEndpoint),
          headers: headers,
          body: payload,
        );
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() {
          mensaje = editandoId != null
              ? '✓ Cita actualizada.'
              : '✓ Cita agendada.';
          paso = 0;
          editandoId = null;
          categoriaSeleccionada = null;
          servicioSeleccionado = null;
          barberoSeleccionado = null;
          fechaSeleccionada = '';
          horaSeleccionada = '';
        });
        await _cargarCitas();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => mensaje = '');
        });
      }
    } catch (e) {
      setState(() => mensaje = 'Error de conexión.');
    }
  }

  Future<void> _borrarCita(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: const Text(
          '¿Cancelar cita?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sí, cancelar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final headers = await _getHeaders();
    await http.delete(
      Uri.parse('${ApiConstants.citasEndpoint}$id/'),
      headers: headers,
    );
    await _cargarCitas();
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
          onPressed: paso > 0
              ? () => setState(() => paso = 0)
              : () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.content_cut, color: _gold, size: 16),
            SizedBox(width: 8),
            Text(
              'urban studio',
              style: TextStyle(
                color: _gold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _gold.withOpacity(0.2)),
        ),
      ),
      body: paso == 0 ? _pantallaCitas() : _pantallaWizard(),
      floatingActionButton: paso == 0
          ? FloatingActionButton.extended(
              onPressed: () => setState(() {
                paso = 1;
                editandoId = null;
              }),
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text(
                'NUEVA CITA',
                style: TextStyle(
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            )
          : null,
    );
  }

  // ── PANTALLA PRINCIPAL: MIS CITAS ──────────────────────────
  Widget _pantallaCitas() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'URBAN STUDIO',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 6,
                    color: _gold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'MIS CITAS',
                  style: TextStyle(
                    fontSize: 28,
                    letterSpacing: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'TUS CITAS PROGRAMADAS',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 3,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (mensaje.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                mensaje,
                style: const TextStyle(color: Colors.green, fontSize: 13),
              ),
            ),
          ),

        if (listaCitas.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: Colors.white.withOpacity(0.1),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes citas programadas.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _tarjetaCita(listaCitas[i]),
                childCount: listaCitas.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _tarjetaCita(dynamic cita) {
    final estado = cita['estado'] ?? 'Pendiente';
    Color colorEstado = estado == 'Completada'
        ? Colors.green
        : estado == 'Cancelada'
        ? Colors.red
        : _gold;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorEstado.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      estado.toUpperCase(),
                      style: TextStyle(
                        fontSize: 8,
                        letterSpacing: 2,
                        color: colorEstado,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cita['servicio_nombre'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cita['barbero_nombre'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${cita['fecha']} — ${(cita['hora'] ?? '').substring(0, 5)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  '\$${cita['servicio_precio'] ?? ''}',
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 12),
                if (estado == 'Pendiente') ...[
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: _gold,
                      size: 18,
                    ),
                    onPressed: () => _editarCita(cita),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Colors.red.withOpacity(0.7),
                      size: 18,
                    ),
                    onPressed: () => _borrarCita(cita['id']),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editarCita(dynamic cita) {
    setState(() {
      editandoId = cita['id'];
      paso = 1;
      categoriaSeleccionada = null;
      servicioSeleccionado = null;
      barberoSeleccionado = null;
      fechaSeleccionada = cita['fecha'] ?? '';
      horaSeleccionada = (cita['hora'] ?? '').substring(0, 5);

      for (final cat in categorias) {
        final serviciosLista = cat['servicios'] as List? ?? [];
        final srv = serviciosLista.firstWhere(
          (s) => s['id'] == cita['servicio'],
          orElse: () => null,
        );
        if (srv != null) {
          categoriaSeleccionada = cat;
          servicioSeleccionado = srv;
          break;
        }
      }
      barberoSeleccionado = barberos.firstWhere(
        (b) => b['id'] == cita['barbero'],
        orElse: () => null,
      );
      if (barberoSeleccionado != null) {
        _cargarDisponibilidad(barberoSeleccionado['id']);
      }
    });
  }

  // ── WIZARD DE NUEVA CITA ───────────────────────────────────
  Widget _pantallaWizard() {
    return Column(
      children: [
        _indicadorPasos(),
        Expanded(
          child: paso == 1
              ? _paso1Servicio()
              : paso == 2
              ? _paso2Barbero()
              : paso == 3
              ? _paso3Fecha()
              : _paso4Confirmar(),
        ),
        _botonesNavegacion(),
      ],
    );
  }

  Widget _indicadorPasos() {
    final pasos = ['Servicio', 'Barbero', 'Fecha', 'Confirmar'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: List.generate(pasos.length, (i) {
          final activo = paso == i + 1;
          final completado = paso > i + 1;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completado
                        ? _gold
                        : activo
                        ? _gold.withOpacity(0.2)
                        : Colors.transparent,
                    border: Border.all(
                      color: activo || completado
                          ? _gold
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Center(
                    child: completado
                        ? const Icon(Icons.check, size: 12, color: Colors.black)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              color: activo
                                  ? _gold
                                  : Colors.white.withOpacity(0.3),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    pasos[i],
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1,
                      color: activo ? _gold : Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
                if (i < pasos.length - 1)
                  Container(
                    width: 16,
                    height: 0.5,
                    color: Colors.white.withOpacity(0.1),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // PASO 1: SERVICIO
  Widget _paso1Servicio() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'ELIGE TU SERVICIO',
          style: TextStyle(fontSize: 10, letterSpacing: 4, color: _gold),
        ),
        const SizedBox(height: 20),
        ...categorias.map((cat) {
          final servicios = cat['servicios'] as List? ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 16),
                child: Text(
                  (cat['nombre'] ?? '').toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 3,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
              ...servicios.map((srv) {
                final seleccionado = servicioSeleccionado?['id'] == srv['id'];
                return GestureDetector(
                  onTap: () => setState(() {
                    categoriaSeleccionada = cat;
                    servicioSeleccionado = srv;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: seleccionado ? _gold.withOpacity(0.1) : _card,
                      border: Border.all(
                        color: seleccionado
                            ? _gold
                            : Colors.white.withOpacity(0.06),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                srv['nombre'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                              if ((srv['descripcion'] ?? '').isNotEmpty)
                                Text(
                                  srv['descripcion'],
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${double.tryParse(srv['precio'].toString())?.toStringAsFixed(0) ?? ''}',
                          style: const TextStyle(
                            color: _gold,
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        if (seleccionado) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle,
                            color: _gold,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }

  // PASO 2: BARBERO
  Widget _paso2Barbero() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Si venimos ya con un servicio preseleccionado (desde Servicios),
        // lo mostramos como recordatorio arriba del paso.
        if (servicioSeleccionado != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.06),
              border: Border.all(color: _gold.withOpacity(0.25)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: _gold, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Servicio: ${servicioSeleccionado['nombre'] ?? ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => paso = 1),
                  child: const Text(
                    'Cambiar',
                    style: TextStyle(color: _gold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Text(
          'ELIGE TU BARBERO',
          style: TextStyle(fontSize: 10, letterSpacing: 4, color: _gold),
        ),
        const SizedBox(height: 20),
        ...barberos.map((b) {
          final seleccionado = barberoSeleccionado?['id'] == b['id'];
          return GestureDetector(
            onTap: () => _seleccionarBarbero(b),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: seleccionado ? _gold.withOpacity(0.1) : _card,
                border: Border.all(
                  color: seleccionado ? _gold : Colors.white.withOpacity(0.06),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _gold.withOpacity(0.3)),
                      color: _gold.withOpacity(0.05),
                    ),
                    child: Center(
                      child: Text(
                        (b['username'] ?? '')[0].toUpperCase(),
                        style: const TextStyle(color: _gold, fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b['username'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          b['email'] ?? '',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (seleccionado)
                    const Icon(Icons.check_circle, color: _gold, size: 18),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // PASO 3: FECHA Y HORA
  Widget _paso3Fecha() {
    final ocupados = _horariosOcupados();
    final horariosDelDia = fechaSeleccionada.isEmpty
        ? <String>[]
        : _horariosDelDia(fechaSeleccionada);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'ELIGE FECHA Y HORA',
          style: TextStyle(fontSize: 10, letterSpacing: 4, color: _gold),
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: _gold),
              onPressed: () {
                final anterior = DateTime(mesActual.year, mesActual.month - 1);
                final hoy = DateTime.now();
                if (!anterior.isBefore(DateTime(hoy.year, hoy.month))) {
                  setState(() {
                    mesActual = anterior;
                    _generarCalendario();
                  });
                }
              },
            ),
            Text(
              '${meses[mesActual.month - 1]} ${mesActual.year}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                letterSpacing: 2,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: _gold),
              onPressed: () => setState(() {
                mesActual = DateTime(mesActual.year, mesActual.month + 1);
                _generarCalendario();
              }),
            ),
          ],
        ),

        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: diasSemana
              .map(
                (d) => Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              )
              .toList(),
        ),

        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: diasCalendario.map((dia) {
            if (dia == null) return const SizedBox();
            final pasado = _esPasado(dia);
            final fecha = _formatFecha(dia);
            final seleccionado = fechaSeleccionada == fecha;
            return GestureDetector(
              onTap: pasado
                  ? null
                  : () => setState(() {
                      fechaSeleccionada = fecha;
                      horaSeleccionada = '';
                    }),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: seleccionado ? _gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    '${dia.day}',
                    style: TextStyle(
                      fontSize: 11,
                      color: pasado
                          ? Colors.white.withOpacity(0.15)
                          : seleccionado
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        if (fechaSeleccionada.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'HORARIOS DISPONIBLES',
            style: TextStyle(fontSize: 9, letterSpacing: 3, color: _gold),
          ),
          const SizedBox(height: 12),
          if (horariosDelDia.isEmpty)
            Text(
              'Este barbero no tiene jornada configurada para este día.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 12,
              ),
            ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: horariosDelDia.map((hora) {
              final ocupado = ocupados.contains(hora);
              final seleccionado = horaSeleccionada == hora;
              return GestureDetector(
                onTap: ocupado
                    ? null
                    : () => setState(() => horaSeleccionada = hora),
                child: Container(
                  decoration: BoxDecoration(
                    color: seleccionado
                        ? _gold
                        : ocupado
                        ? Colors.white.withOpacity(0.03)
                        : _card,
                    border: Border.all(
                      color: seleccionado
                          ? _gold
                          : ocupado
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withOpacity(0.1),
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      hora,
                      style: TextStyle(
                        fontSize: 11,
                        color: seleccionado
                            ? Colors.black
                            : ocupado
                            ? Colors.white.withOpacity(0.15)
                            : Colors.white,
                        decoration: ocupado ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // PASO 4: CONFIRMAR
  Widget _paso4Confirmar() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'CONFIRMAR CITA',
          style: TextStyle(fontSize: 10, letterSpacing: 4, color: _gold),
        ),
        const SizedBox(height: 24),
        _filaConfirmacion('Servicio', servicioSeleccionado?['nombre'] ?? ''),
        _filaConfirmacion(
          'Precio',
          '\$${servicioSeleccionado?['precio'] ?? ''}',
        ),
        _filaConfirmacion('Barbero', barberoSeleccionado?['username'] ?? ''),
        _filaConfirmacion('Fecha', fechaSeleccionada),
        _filaConfirmacion('Hora', horaSeleccionada),
        if (mensaje.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            mensaje,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _confirmarCita,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            child: Text(
              editandoId != null ? 'ACTUALIZAR CITA' : 'CONFIRMAR CITA',
              style: const TextStyle(
                letterSpacing: 3,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filaConfirmacion(String label, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          Text(
            valor,
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _botonesNavegacion() {
    // Si venimos preseleccionados desde Servicios, "Atrás" en el paso 2
    // sale del wizard en vez de mandarte al paso 1 (que no elegiste tú).
    final primerPasoReal = widget.servicioInicial != null ? 2 : 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          if (paso > 1)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  if (paso == primerPasoReal) {
                    paso = 0;
                  } else {
                    paso--;
                  }
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child: const Text(
                  '← ATRÁS',
                  style: TextStyle(letterSpacing: 2, fontSize: 11),
                ),
              ),
            ),
          if (paso > 1) const SizedBox(width: 12),
          if (paso < 4)
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (paso == 1 && servicioSeleccionado == null) {
                    setState(() => mensaje = 'Selecciona un servicio.');
                    return;
                  }
                  if (paso == 2 && barberoSeleccionado == null) {
                    setState(() => mensaje = 'Selecciona un barbero.');
                    return;
                  }
                  if (paso == 3 &&
                      (fechaSeleccionada.isEmpty || horaSeleccionada.isEmpty)) {
                    setState(() => mensaje = 'Selecciona fecha y hora.');
                    return;
                  }
                  setState(() {
                    mensaje = '';
                    paso++;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child: const Text(
                  'SIGUIENTE →',
                  style: TextStyle(
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
