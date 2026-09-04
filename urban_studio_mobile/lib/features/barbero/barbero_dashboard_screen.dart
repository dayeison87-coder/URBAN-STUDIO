import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../../core/network/auth_service.dart';
import '../auth/login_screen.dart';

const _gold = Color(0xFFE6BB3F);
const _background = Color(0xFF0A0A0A);
const _surface = Color(0xFF111111);
const _muted = Color(0xFF888888);

class BarberoDashboardScreen extends StatefulWidget {
  const BarberoDashboardScreen({super.key});

  @override
  State<BarberoDashboardScreen> createState() => _BarberoDashboardScreenState();
}

class _BarberoDashboardScreenState extends State<BarberoDashboardScreen> {
  final _auth = AuthService();
  final _picker = ImagePicker();
  int _tab = 0;
  bool _loading = true;
  String _message = '';
  String _username = 'Barbero';
  List<dynamic> _citas = [];
  List<dynamic> _clientes = [];
  List<dynamic> _historial = [];
  List<dynamic> _ingresos = [];
  List<dynamic> _horarios = [];
  Map<String, dynamic> _resumen = {};
  Map<String, dynamic> _perfil = {};
  XFile? _photo;

  final _days = const [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  String _day = 'Lunes';
  TimeOfDay _from = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 17, minute: 0);
  int? _editingScheduleId;
  final _phone = TextEditingController();
  final _experience = TextEditingController();
  final _description = TextEditingController();
  final _search = TextEditingController();
  String _status = 'Todas';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _experience.dispose();
    _description.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await _auth.getAccessToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final headers = await _headers();
      final responses = await Future.wait([
        http.get(
          Uri.parse('${ApiConstants.baseUrl}/barbero/dashboard/'),
          headers: headers,
        ),
        http.get(Uri.parse(ApiConstants.citasEndpoint), headers: headers),
        http.get(
          Uri.parse(ApiConstants.disponibilidadEndpoint),
          headers: headers,
        ),
        http.get(
          Uri.parse('${ApiConstants.baseUrl}/perfil/barbero/'),
          headers: headers,
        ),
      ]);
      if (responses[0].statusCode == 403 || responses[0].statusCode == 401) {
        throw Exception('Esta cuenta no tiene permisos de barbero.');
      }
      final dashboard = _decodeMap(responses[0].body);
      final citas = _decodeList(responses[1].body);
      setState(() {
        _resumen = dashboard['resumen'] is Map
            ? Map<String, dynamic>.from(dashboard['resumen'])
            : {};
        _clientes = _decodeListValue(dashboard['clientes']);
        _historial = _decodeListValue(dashboard['historial']);
        _ingresos = _decodeListValue(dashboard['ingresos']);
        _citas = citas;
        _horarios = _decodeList(responses[2].body);
        _perfil = _decodeMap(responses[3].body);
        _username = '${_perfil['username'] ?? 'Barbero'}';
        _phone.text = '${_perfil['telefono'] ?? ''}';
        _experience.text = '${_perfil['experiencia'] ?? ''}';
        _description.text = '${_perfil['descripcion'] ?? ''}';
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Map<String, dynamic> _decodeMap(String body) {
    final value = jsonDecode(body);
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  List<dynamic> _decodeList(String body) {
    final value = jsonDecode(body);
    return value is List ? value : [];
  }

  List<dynamic> _decodeListValue(dynamic value) =>
      value is List ? List<dynamic>.from(value) : [];

  Future<void> _changeStatus(dynamic cita, String status) async {
    if (status == 'Cancelada') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _surface,
          title: const Text(
            'Cancelar cita',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '¿Cancelar la cita de ${cita['cliente_nombre']}?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    final response = await http.patch(
      Uri.parse('${ApiConstants.citasEndpoint}${cita['id']}/'),
      headers: await _headers(json: true),
      body: jsonEncode({'estado': status}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _load();
    } else {
      setState(() => _message = 'No se pudo actualizar el estado de la cita.');
    }
  }

  String _time(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';

  Future<void> _saveSchedule() async {
    if (_from.hour * 60 + _from.minute >= _to.hour * 60 + _to.minute) {
      setState(
        () => _message = 'La hora de cierre debe ser posterior a la apertura.',
      );
      return;
    }
    final url = _editingScheduleId == null
        ? ApiConstants.disponibilidadEndpoint
        : '${ApiConstants.disponibilidadEndpoint}$_editingScheduleId/';
    final response = _editingScheduleId == null
        ? await http.post(
            Uri.parse(url),
            headers: await _headers(json: true),
            body: jsonEncode({
              'dia_semana': _day,
              'hora_inicio': _time(_from),
              'hora_fin': _time(_to),
            }),
          )
        : await http.patch(
            Uri.parse(url),
            headers: await _headers(json: true),
            body: jsonEncode({
              'dia_semana': _day,
              'hora_inicio': _time(_from),
              'hora_fin': _time(_to),
            }),
          );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      setState(() {
        _message = _editingScheduleId == null
            ? 'Horario guardado correctamente.'
            : 'Horario actualizado correctamente.';
        _editingScheduleId = null;
      });
      await _load();
    } else {
      setState(() => _message = 'No se pudo guardar el horario.');
    }
  }

  Future<void> _deleteSchedule(dynamic schedule) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.disponibilidadEndpoint}${schedule['id']}/'),
      headers: await _headers(),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) await _load();
  }

  void _editSchedule(dynamic schedule) {
    final from = '${schedule['hora_inicio']}'.substring(0, 5).split(':');
    final to = '${schedule['hora_fin']}'.substring(0, 5).split(':');
    setState(() {
      _editingScheduleId = schedule['id'];
      _day = '${schedule['dia_semana']}';
      _from = TimeOfDay(hour: int.parse(from[0]), minute: int.parse(from[1]));
      _to = TimeOfDay(hour: int.parse(to[0]), minute: int.parse(to[1]));
      _tab = 5;
    });
  }

  Future<void> _saveProfile() async {
    final request = http.MultipartRequest(
      'PATCH',
      Uri.parse('${ApiConstants.baseUrl}/perfil/barbero/'),
    );
    final headers = await _headers();
    request.headers.addAll(headers);
    request.fields.addAll({
      'telefono': _phone.text.trim(),
      'experiencia': _experience.text.trim().isEmpty
          ? '0'
          : _experience.text.trim(),
      'descripcion': _description.text.trim(),
    });
    if (_photo != null) {
      request.files.add(
        await http.MultipartFile.fromPath('foto', _photo!.path),
      );
    }
    final response = await request.send();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      setState(() => _message = 'Perfil actualizado correctamente.');
      await _load();
    } else {
      setState(() => _message = 'No se pudo actualizar el perfil.');
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String _money(dynamic value) {
    final amount = (double.tryParse('$value') ?? 0).round().toString();
    final groups = <String>[];
    for (var end = amount.length; end > 0; end -= 3) {
      final start = end - 3 < 0 ? 0 : end - 3;
      groups.insert(0, amount.substring(start, end));
    }
    return '\$${groups.join('.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            const Icon(Icons.content_cut, color: _gold, size: 18),
            const SizedBox(width: 8),
            Text(
              'Hola, $_username',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: _gold),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white70),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _message.isNotEmpty && _resumen.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
          : Column(
              children: [
                if (_message.isNotEmpty) _notice(),
                Expanded(
                  child: RefreshIndicator(
                    color: _gold,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [_content()],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDrawer() {
    const labels = [
      'Resumen',
      'Clientes',
      'Historial',
      'Ingresos',
      'Citas',
      'Horarios',
      'Perfil',
    ];
    const icons = [
      Icons.dashboard_outlined,
      Icons.people_outline,
      Icons.content_cut,
      Icons.wallet_outlined,
      Icons.calendar_month_outlined,
      Icons.schedule,
      Icons.person_outline,
    ];
    return Drawer(
      backgroundColor: _surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.content_cut, color: _gold, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Hola, $_username',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            for (var index = 0; index < labels.length; index++)
              ListTile(
                leading: Icon(
                  icons[index],
                  color: _tab == index ? _gold : _muted,
                ),
                title: Text(
                  labels[index],
                  style: TextStyle(
                    color: _tab == index ? _gold : Colors.white70,
                    fontSize: 14,
                  ),
                ),
                selected: _tab == index,
                selectedTileColor: _gold.withOpacity(.10),
                onTap: () {
                  setState(() {
                    _tab = index;
                    _message = '';
                  });
                  Navigator.pop(context);
                },
              ),
            const Spacer(),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice() => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    padding: const EdgeInsets.all(10),
    color: _gold.withOpacity(.12),
    child: Text(_message, style: const TextStyle(color: _gold)),
  );

  Widget _content() {
    switch (_tab) {
      case 1:
        return _clientsView();
      case 2:
        return _historyView();
      case 3:
        return _incomeView();
      case 4:
        return _appointmentsView();
      case 5:
        return _scheduleView();
      case 6:
        return _profileView();
      default:
        return _dashboardView();
    }
  }

  Widget _heading(String kicker, String title, [String? help]) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        kicker.toUpperCase(),
        style: const TextStyle(color: _gold, fontSize: 10, letterSpacing: 1.5),
      ),
      const SizedBox(height: 5),
      Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w500,
        ),
      ),
      if (help != null) ...[
        const SizedBox(height: 5),
        Text(help, style: const TextStyle(color: _muted, fontSize: 12)),
      ],
      const SizedBox(height: 18),
    ],
  );

  Widget _dashboardView() {
    final values = [
      ['Citas', _resumen['citas'] ?? 0, Icons.calendar_month],
      ['Clientes', _resumen['clientes'] ?? 0, Icons.people_outline],
      ['Servicios', _resumen['servicios'] ?? 0, Icons.content_cut],
      ['Valoración', '${_resumen['valoracion'] ?? 0} ★', Icons.star_outline],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Tu actividad', 'Resumen del negocio'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: values
              .map(
                (item) =>
                    _metric(item[0] as String, item[1], item[2] as IconData),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        _incomeStrip(),
        _panel(
          'Próximas citas',
          _citas.take(5).map(_miniAppointment).toList(),
          empty: 'No tienes citas programadas.',
        ),
        const SizedBox(height: 14),
        _panel(
          'Últimos cortes',
          _historial.take(5).map(_miniHistory).toList(),
          empty: 'Aún no tienes cortes completados.',
        ),
      ],
    );
  }

  Widget _metric(String label, dynamic value, IconData icon) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: Colors.white12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _gold, size: 18),
        const Spacer(),
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: _muted, fontSize: 9, letterSpacing: 1),
        ),
        const SizedBox(height: 5),
        Text(
          '$value',
          style: const TextStyle(color: Colors.white, fontSize: 22),
        ),
      ],
    ),
  );

  Widget _incomeStrip() => Row(
    children: [
      Expanded(child: _incomeBox('Esta semana', _resumen['ingresos_semana'])),
      const SizedBox(width: 8),
      Expanded(child: _incomeBox('Este mes', _resumen['ingresos_mes'])),
    ],
  );

  Widget _incomeBox(String label, dynamic value) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: _gold.withOpacity(.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        const SizedBox(height: 8),
        Text(_money(value), style: const TextStyle(color: _gold, fontSize: 20)),
      ],
    ),
  );

  Widget _panel(String title, List<Widget> children, {required String empty}) =>
      Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: Colors.white12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (children.isEmpty)
              Text(empty, style: const TextStyle(color: _muted, fontSize: 12))
            else
              ...children,
          ],
        ),
      );

  Widget _miniAppointment(dynamic item) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: _avatar(item['cliente_nombre']),
    title: Text(
      '${item['cliente_nombre'] ?? 'Cliente'}',
      style: const TextStyle(color: Colors.white, fontSize: 13),
    ),
    subtitle: Text(
      '${item['fecha']} · ${item['hora']}',
      style: const TextStyle(color: _muted, fontSize: 11),
    ),
    trailing: _badge(item['estado']),
  );

  Widget _miniHistory(dynamic item) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: _avatar(item['cliente_nombre']),
    title: Text(
      '${item['cliente_nombre'] ?? 'Cliente'}',
      style: const TextStyle(color: Colors.white, fontSize: 13),
    ),
    subtitle: Text(
      '${item['servicio_nombre']} · ${item['fecha']}',
      style: const TextStyle(color: _muted, fontSize: 11),
    ),
    trailing: Text(
      _money(item['precio']),
      style: const TextStyle(color: _gold),
    ),
  );

  Widget _avatar(dynamic name) {
    final value = '${name ?? ''}'.trim();
    final initial = value.isEmpty ? 'B' : value[0].toUpperCase();
    return CircleAvatar(
      radius: 16,
      backgroundColor: _gold.withOpacity(.12),
      child: Text(initial, style: const TextStyle(color: _gold)),
    );
  }

  Widget _clientsView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Relación profesional', 'Mis clientes'),
      Text(
        '${_clientes.length} clientes',
        style: const TextStyle(color: _muted),
      ),
      const SizedBox(height: 10),
      ..._clientes.map(
        (client) => _card([
          _avatar(client['nombre']),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${client['nombre'] ?? 'Cliente'}',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                Text(
                  '${client['email'] ?? 'Sin correo'} · ${client['telefono'] ?? 'Sin teléfono'}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                Text(
                  '${client['total_citas'] ?? 0} citas · Último: ${client['ultimo_servicio'] ?? '-'}',
                  style: const TextStyle(color: _gold, fontSize: 11),
                ),
              ],
            ),
          ),
        ]),
      ),
    ],
  );

  Widget _historyView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Trabajo realizado', 'Historial de cortes'),
      _searchField('Buscar cliente o servicio'),
      const SizedBox(height: 10),
      ..._historial
          .where((item) {
            final query = _search.text.toLowerCase();
            return query.isEmpty ||
                '${item['cliente_nombre']} ${item['servicio_nombre']}'
                    .toLowerCase()
                    .contains(query);
          })
          .map(
            (item) => _card([
              _avatar(item['cliente_nombre']),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${item['cliente_nombre']}\n${item['servicio_nombre']} · ${item['fecha']}',
                  style: const TextStyle(color: Colors.white, height: 1.5),
                ),
              ),
              Text(
                _money(item['precio']),
                style: const TextStyle(color: _gold),
              ),
            ]),
          ),
    ],
  );

  Widget _incomeView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Rendimiento',
        'Mis ingresos',
        'Calculados con los servicios completados.',
      ),
      _incomeBox('Acumulado anual', _resumen['ingresos_total']),
      const SizedBox(height: 12),
      _incomeStrip(),
      const SizedBox(height: 20),
      _panel(
        'Ingresos del día',
        _ingresos
            .map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month, color: _gold),
                title: Text(
                  '${item['fecha']}',
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Text(
                  _money(item['total']),
                  style: const TextStyle(color: _gold),
                ),
              ),
            )
            .toList(),
        empty: 'Aún no hay ingresos registrados.',
      ),
    ],
  );

  Widget _appointmentsView() {
    final filtered = _citas.where((item) {
      final query = _search.text.toLowerCase();
      final matchesText =
          query.isEmpty ||
          '${item['cliente_nombre']} ${item['servicio_nombre']}'
              .toLowerCase()
              .contains(query);
      return matchesText && (_status == 'Todas' || item['estado'] == _status);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Agenda del día', 'Citas programadas'),
        _searchField('Buscar cliente o servicio'),
        DropdownButton<String>(
          value: _status,
          dropdownColor: _surface,
          style: const TextStyle(color: Colors.white),
          items: ['Todas', 'Pendiente', 'Completada', 'Cancelada']
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) => setState(() => _status = value ?? 'Todas'),
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          const Text(
            'No hay citas con estos filtros.',
            style: TextStyle(color: _muted),
          ),
        ...filtered.map((item) => _appointmentCard(item)),
      ],
    );
  }

  Widget _appointmentCard(dynamic item) => _card([
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item['cliente_nombre'] ?? 'Cliente'}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          Text(
            '${item['servicio_nombre']} · ${item['fecha']} · ${item['hora']}',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            _money(item['servicio_precio']),
            style: const TextStyle(color: _gold),
          ),
        ],
      ),
    ),
    Column(
      children: [
        _badge(item['estado']),
        if (item['estado'] == 'Pendiente') ...[
          TextButton(
            onPressed: () => _changeStatus(item, 'Completada'),
            child: const Text('Completar'),
          ),
          TextButton(
            onPressed: () => _changeStatus(item, 'Cancelada'),
            child: const Text('Cancelar'),
          ),
        ],
      ],
    ),
  ]);

  Widget _scheduleView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading(
        'Agenda profesional',
        'Mis horarios de atención',
        'Define cuándo pueden reservar tus clientes.',
      ),
      _card([
        Expanded(
          child: DropdownButton<String>(
            value: _day,
            isExpanded: true,
            dropdownColor: _surface,
            style: const TextStyle(color: Colors.white),
            items: _days
                .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                .toList(),
            onChanged: (value) => setState(() => _day = value ?? _day),
          ),
        ),
        const SizedBox(width: 8),
        _timeButton(_from, (value) => setState(() => _from = value)),
        const Text(' - ', style: TextStyle(color: _muted)),
        _timeButton(_to, (value) => setState(() => _to = value)),
        IconButton(
          onPressed: _saveSchedule,
          icon: Icon(
            _editingScheduleId == null ? Icons.add : Icons.check,
            color: _gold,
          ),
        ),
        if (_editingScheduleId != null)
          IconButton(
            onPressed: () => setState(() => _editingScheduleId = null),
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
      ]),
      const SizedBox(height: 12),
      if (_horarios.isEmpty)
        const Text(
          'No tienes horarios configurados.',
          style: TextStyle(color: _muted),
        ),
      ..._horarios.map(
        (item) => _card([
          Expanded(
            child: Text(
              '${item['dia_semana']}\n${item['hora_inicio'].toString().substring(0, 5)} - ${item['hora_fin'].toString().substring(0, 5)}',
              style: const TextStyle(color: Colors.white, height: 1.5),
            ),
          ),
          IconButton(
            onPressed: () => _editSchedule(item),
            icon: const Icon(Icons.edit_outlined, color: _gold),
          ),
          IconButton(
            onPressed: () => _deleteSchedule(item),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
        ]),
      ),
    ],
  );

  Widget _timeButton(TimeOfDay time, ValueChanged<TimeOfDay> onChanged) =>
      TextButton(
        onPressed: () async {
          final value = await showTimePicker(
            context: context,
            initialTime: time,
          );
          if (value != null) onChanged(value);
        },
        child: Text(time.format(context), style: const TextStyle(color: _gold)),
      );

  Widget _profileView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _heading('Identidad profesional', 'Mi perfil'),
      Center(
        child: Column(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: _gold.withOpacity(.12),
              backgroundImage: _photo == null
                  ? null
                  : FileImage(File(_photo!.path)),
              child: _photo == null
                  ? Text(
                      _username[0].toUpperCase(),
                      style: const TextStyle(color: _gold, fontSize: 30),
                    )
                  : null,
            ),
            TextButton.icon(
              onPressed: () async {
                final photo = await _picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (photo != null) setState(() => _photo = photo);
              },
              icon: const Icon(Icons.photo_camera, color: _gold),
              label: const Text('Cambiar foto', style: TextStyle(color: _gold)),
            ),
          ],
        ),
      ),
      _field(
        'Usuario',
        initial: '${_perfil['username'] ?? _username}',
        enabled: false,
      ),
      _field('Correo', initial: '${_perfil['email'] ?? ''}', enabled: false),
      _field('Teléfono', controller: _phone),
      _field(
        'Años de experiencia',
        controller: _experience,
        keyboard: TextInputType.number,
      ),
      _field('Descripción', controller: _description, maxLines: 4),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: Colors.black,
          ),
          child: const Text('Guardar cambios'),
        ),
      ),
    ],
  );

  Widget _field(
    String label, {
    TextEditingController? controller,
    String? initial,
    bool enabled = true,
    int maxLines = 1,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller ?? TextEditingController(text: initial),
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _muted),
          filled: true,
          fillColor: _surface,
          border: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white12),
          ),
        ),
      ),
    );
  }

  Widget _searchField(String hint) => TextField(
    controller: _search,
    onChanged: (_) => setState(() {}),
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted),
      prefixIcon: const Icon(Icons.search, color: _muted),
      filled: true,
      fillColor: _surface,
      border: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white12),
      ),
    ),
  );

  Widget _card(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: Colors.white12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    ),
  );

  Widget _badge(dynamic value) {
    final text = '$value';
    final color = text == 'Completada'
        ? Colors.greenAccent
        : text == 'Cancelada'
        ? Colors.redAccent
        : _gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10)),
    );
  }
}
