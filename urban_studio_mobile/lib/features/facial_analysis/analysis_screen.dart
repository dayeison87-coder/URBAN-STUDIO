import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_service.dart';

const _gold = Color(0xFFc9a227);
const _goldLight = Color(0xFFe8cd6e);
const _bg = Color(0xFF0b0a08);
const _surface = Color(0xFF171410);
const _surfaceLine = Color(0xFF2a251c);
const _textMuted = Color(0xFF8c8477);

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imagenBytes;
  String? _imagenNombre;

  dynamic _resultado;

  bool _cargando = false;
  bool _iaDesbloqueada = false;
  bool _mostrarCodigo = false;
  bool _validandoCodigo = false;
  bool _cargandoBarberos = false;

  List<dynamic> _barberos = [];
  dynamic _barberoSeleccionado;

  String _error = '';
  String _modo = 'inicial';

  final List<TextEditingController> _codigoControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _codigoFocus = List.generate(6, (_) => FocusNode());

  // ============================================================
  // CÁMARA
  // ============================================================

  CameraController? _cameraController;

  List<CameraDescription> _cameras = [];

  FaceDetector? _faceDetector;

  bool _camaraActiva = false;
  bool _procesandoFrame = false;
  bool _capturandoAutomaticamente = false;

  int _framesEstables = 0;

  DateTime? _ultimoFrameProcesado;

  static const int _framesNecesarios = 12;

  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_scanController);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cerrarCamara();

    _faceDetector?.close();

    _scanController.dispose();
    _waveController.dispose();

    for (final controller in _codigoControllers) {
      controller.dispose();
    }

    for (final focus in _codigoFocus) {
      focus.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // CÓDIGO DE SEGURIDAD
  // ============================================================

  String get _codigoCompleto {
    return _codigoControllers.map((controller) {
      return controller.text;
    }).join();
  }

  void _limpiarCodigo() {
    for (final controller in _codigoControllers) {
      controller.clear();
    }

    for (final focus in _codigoFocus) {
      focus.unfocus();
    }

    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<bool> _elegirBarbero() async {
    if (_barberoSeleccionado != null) return true;

    setState(() {
      _cargandoBarberos = true;
      _error = '';
    });

    try {
      _barberos = await _apiService.obtenerBarberos();
      if (!mounted) return false;

      final seleccionado = await showModalBottomSheet<dynamic>(
        context: context,
        backgroundColor: _surface,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * .65,
            child: Column(
              children: [
                const SizedBox(height: 18),
                const Text(
                  'ELIGE TU BARBERO',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'El código se enviará solo a este barbero.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _barberos.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay barberos disponibles.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _barberos.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: _surfaceLine),
                          itemBuilder: (_, index) {
                            final barbero = _barberos[index];
                            final nombre = barbero['username'] ?? 'Barbero';
                            final inicial = nombre.isNotEmpty
                                ? nombre[0].toUpperCase()
                                : 'B';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _gold.withOpacity(.18),
                                child: Text(
                                  inicial,
                                  style: const TextStyle(color: _gold),
                                ),
                              ),
                              title: Text(
                                nombre,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                barbero['experiencia'] == null
                                    ? 'Barbero Urban Studio'
                                    : '${barbero['experiencia']} años de experiencia',
                                style: const TextStyle(color: _textMuted),
                              ),
                              onTap: () => Navigator.pop(context, barbero),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );

      if (!mounted || seleccionado == null) return false;
      setState(() => _barberoSeleccionado = seleccionado);
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No fue posible cargar los barberos.';
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _cargandoBarberos = false);
    }
  }

  Future<void> _abrirIA() async {
    if (_iaDesbloqueada) return;

    if (!await _elegirBarbero()) return;

    final barberoId = _barberoSeleccionado?['id'];
    if (barberoId is! int) {
      setState(() => _error = 'Selecciona un barbero válido.');
      return;
    }

    setState(() {
      _error = '';
      _validandoCodigo = true;
    });

    try {
      await _apiService.solicitarCodigoIA(barberoId);

      if (!mounted) return;

      setState(() {
        _validandoCodigo = false;
        _mostrarCodigo = true;
      });

      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && _mostrarCodigo) {
          _codigoFocus[0].requestFocus();
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _validandoCodigo = false;
        _error = 'No fue posible enviar el código de seguridad.';
      });
    }
  }

  Future<void> _validarCodigo() async {
    final codigo = _codigoCompleto.trim();

    if (codigo.length != 6) {
      setState(() {
        _error = 'Ingresa el código completo de 6 dígitos.';
      });
      return;
    }

    setState(() {
      _error = '';
      _validandoCodigo = true;
    });

    FocusManager.instance.primaryFocus?.unfocus();

    try {
      final barberoId = _barberoSeleccionado?['id'];
      if (barberoId is! int) {
        throw Exception('Debes seleccionar un barbero.');
      }
      await _apiService.validarCodigoIA(codigo, barberoId);

      if (!mounted) return;

      _limpiarCodigo();

      setState(() {
        _validandoCodigo = false;
        _mostrarCodigo = false;
        _iaDesbloqueada = true;
        _error = '';
      });

      // ========================================================
      // NUEVO:
      // AL VALIDAR EL CÓDIGO, ABRIMOS LA CÁMARA AUTOMÁTICAMENTE.
      // ========================================================

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _iaDesbloqueada) {
          _abrirCamaraAutomatica();
        }
      });
    } catch (e) {
      if (!mounted) return;

      _limpiarCodigo();

      setState(() {
        _validandoCodigo = false;
        _error = 'El código ingresado no es válido.';
      });

      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _mostrarCodigo) {
          _codigoFocus[0].requestFocus();
        }
      });
    }
  }

  // ============================================================
  // GALERÍA / SUBIR FOTO
  // ============================================================

  Future<void> _seleccionarImagen(ImageSource source) async {
    if (!_iaDesbloqueada) {
      setState(() {
        _error = 'Primero valida el código de seguridad.';
      });
      return;
    }

    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 90);

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      if (!mounted) return;

      setState(() {
        _imagenBytes = bytes;
        _imagenNombre = picked.name;
        _modo = 'escaneando';
        _resultado = null;
        _error = '';
        _cargando = true;
      });

      await _enviarImagen();
    } catch (e) {
      debugPrint('❌ Error seleccionando imagen: $e');

      if (!mounted) return;

      setState(() {
        _cargando = false;
        _modo = 'inicial';
        _error = 'No se pudo acceder a la imagen.';
      });
    }
  }

  // ============================================================
  // ABRIR CÁMARA
  // ============================================================

  Future<void> _abrirCamaraAutomatica() async {
    if (!_iaDesbloqueada) {
      setState(() {
        _error = 'Primero valida el código de seguridad.';
      });
      return;
    }

    // Windows / PC no ejecuta startImageStream.
    if (!Platform.isAndroid) {
      setState(() {
        _error =
            'El escaneo automático está disponible en Android. '
            'En el PC utiliza "SUBIR FOTO".';
      });
      return;
    }

    try {
      setState(() {
        _error = '';
        _modo = 'camara';
        _resultado = null;
        _framesEstables = 0;
        _capturandoAutomaticamente = false;
        _procesandoFrame = false;
      });

      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw Exception('No se encontró ninguna cámara.');
      }

      CameraDescription? frontal;

      for (final camera in _cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontal = camera;
          break;
        }
      }

      frontal ??= _cameras.first;

      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          enableLandmarks: true,
          enableClassification: true,
          enableTracking: true,
          minFaceSize: 0.15,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

      _cameraController = CameraController(
        frontal,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _camaraActiva = true;
      });

      // Iniciar detección automática.
      await _cameraController!.startImageStream(_procesarFrameCamara);
    } catch (e) {
      debugPrint('❌ Error cámara: $e');

      if (!mounted) return;

      setState(() {
        _camaraActiva = false;
        _modo = 'inicial';
        _error =
            'No fue posible iniciar la cámara. '
            'Verifica los permisos de cámara.';
      });

      await _cerrarCamara();
    }
  }

  // ============================================================
  // PROCESAR CADA FRAME
  // ============================================================

  Future<void> _procesarFrameCamara(CameraImage image) async {
    if (_procesandoFrame ||
        _capturandoAutomaticamente ||
        !_camaraActiva ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    final ahora = DateTime.now();

    if (_ultimoFrameProcesado != null &&
        ahora.difference(_ultimoFrameProcesado!).inMilliseconds < 100) {
      return;
    }

    _ultimoFrameProcesado = ahora;
    _procesandoFrame = true;

    try {
      final inputImage = _convertirImagen(image);

      if (inputImage == null) {
        _procesandoFrame = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);

      if (!mounted) {
        _procesandoFrame = false;
        return;
      }

      if (faces.isEmpty) {
        _framesEstables = 0;

        setState(() {
          _error = 'Coloca tu rostro dentro del marco';
        });

        _procesandoFrame = false;
        return;
      }

      if (faces.length > 1) {
        _framesEstables = 0;

        setState(() {
          _error = 'Solo debe aparecer un rostro';
        });

        _procesandoFrame = false;
        return;
      }

      final face = faces.first;

      final correcto = _rostroEstaCorrecto(
        face,
        image.width.toDouble(),
        image.height.toDouble(),
      );

      if (!correcto) {
        _framesEstables = 0;

        setState(() {
          _error = 'Centra tu rostro dentro del marco';
        });

        _procesandoFrame = false;
        return;
      }

      // ========================================================
      // ROSTRO CORRECTAMENTE POSICIONADO
      // ========================================================

      _framesEstables++;

      final progreso = (_framesEstables / _framesNecesarios).clamp(0.0, 1.0);

      setState(() {
        _error = 'Rostro detectado · ${(progreso * 100).round()}%';
      });

      // ========================================================
      // CAPTURA AUTOMÁTICA AL LLEGAR AL 100%
      // ========================================================

      if (_framesEstables >= _framesNecesarios) {
        await _capturarFotoAutomaticamente();
      }
    } catch (e) {
      debugPrint('❌ Error procesando frame: $e');
    }

    _procesandoFrame = false;
  }

  // ============================================================
  // CONVERTIR CAMERA IMAGE
  // ============================================================

  InputImage? _convertirImagen(CameraImage image) {
    try {
      if (_cameraController == null) return null;

      final camera = _cameraController!.description;

      final sensorOrientation = camera.sensorOrientation;

      InputImageRotation rotation;

      if (Platform.isAndroid) {
        switch (sensorOrientation) {
          case 0:
            rotation = InputImageRotation.rotation0deg;
            break;
          case 90:
            rotation = InputImageRotation.rotation90deg;
            break;
          case 180:
            rotation = InputImageRotation.rotation180deg;
            break;
          case 270:
            rotation = InputImageRotation.rotation270deg;
            break;
          default:
            rotation = InputImageRotation.rotation0deg;
        }
      } else {
        rotation = InputImageRotation.rotation0deg;
      }

      final bytes = _concatenarPlanes(image.planes);

      final format = InputImageFormat.nv21;

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      debugPrint('❌ Error convirtiendo frame: $e');
      return null;
    }
  }

  Uint8List _concatenarPlanes(List<Plane> planes) {
    final allBytes = <int>[];

    for (final plane in planes) {
      allBytes.addAll(plane.bytes);
    }

    return Uint8List.fromList(allBytes);
  }

  // ============================================================
  // COMPROBAR ROSTRO
  // ============================================================

  bool _rostroEstaCorrecto(Face face, double imageWidth, double imageHeight) {
    final box = face.boundingBox;

    final centroX = box.center.dx / imageWidth;
    final centroY = box.center.dy / imageHeight;

    final ancho = box.width / imageWidth;
    final alto = box.height / imageHeight;

    final centradoX = centroX > 0.30 && centroX < 0.70;

    final centradoY = centroY > 0.25 && centroY < 0.75;

    final tamanoCorrecto =
        ancho > 0.18 && ancho < 0.75 && alto > 0.18 && alto < 0.85;

    final rotacionY = face.headEulerAngleY?.abs() ?? 0;

    final rotacionZ = face.headEulerAngleZ?.abs() ?? 0;

    final mirandoFrente = rotacionY < 18 && rotacionZ < 18;

    return centradoX && centradoY && tamanoCorrecto && mirandoFrente;
  }

  // ============================================================
  // CAPTURA AUTOMÁTICA
  // ============================================================

  Future<void> _capturarFotoAutomaticamente() async {
    if (_capturandoAutomaticamente) return;

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _capturandoAutomaticamente = true;
    _framesEstables = 0;

    try {
      if (mounted) {
        setState(() {
          _error = '';
          _modo = 'escaneando';
          _cargando = true;
        });
      }

      if (_cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }

      await Future.delayed(const Duration(milliseconds: 250));

      final foto = await _cameraController!.takePicture();

      final bytes = await foto.readAsBytes();

      if (!mounted) return;

      setState(() {
        _imagenBytes = bytes;
        _imagenNombre = 'rostro_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });

      await _cerrarCamara();

      if (!mounted) return;

      setState(() {
        _modo = 'escaneando';
        _cargando = true;
      });

      await _enviarImagen();
    } catch (e) {
      debugPrint('❌ Error captura automática: $e');

      if (!mounted) return;

      setState(() {
        _cargando = false;
        _modo = 'inicial';
        _error = 'No fue posible capturar el rostro. Intenta nuevamente.';
      });

      await _cerrarCamara();
    } finally {
      _capturandoAutomaticamente = false;
    }
  }

  // ============================================================
  // CERRAR CÁMARA
  // ============================================================

  Future<void> _cerrarCamara() async {
    try {
      if (_cameraController != null) {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }

        await _cameraController!.dispose();
      }
    } catch (e) {
      debugPrint('⚠️ Error cerrando cámara: $e');
    }

    _cameraController = null;
    _camaraActiva = false;
    _procesandoFrame = false;
    _capturandoAutomaticamente = false;
    _framesEstables = 0;
  }

  // ============================================================
  // ANALIZAR FOTO
  // ============================================================

  Future<void> _enviarImagen() async {
    if (!_iaDesbloqueada || _imagenBytes == null) return;

    if (!_cargando) {
      setState(() {
        _cargando = true;
        _error = '';
        _resultado = null;
        _modo = 'escaneando';
      });
    }

    try {
      final res = await _apiService.analyzeFace(
        _imagenBytes!,
        filename: _imagenNombre ?? 'foto.jpg',
      );

      debugPrint('📸 foto_original: ${res.fotoOriginal}');
      debugPrint('📸 imagen_resultado: ${res.imagenResultado}');

      if (!mounted) return;

      setState(() {
        _resultado = res;
        _cargando = false;
        _modo = 'resultado';
        _error = '';
      });
    } catch (e) {
      debugPrint('❌ Error análisis facial: $e');

      if (!mounted) return;

      setState(() {
        _cargando = false;
        _modo = 'preview';
        _error =
            'No fue posible analizar el rostro. '
            'Intenta con una foto frontal y con buena iluminación.';
      });
    }
  }

  // ============================================================
  // QUITAR IMAGEN
  // ============================================================

  void _quitarImagen() {
    setState(() {
      _imagenBytes = null;
      _imagenNombre = null;
      _modo = 'inicial';
      _resultado = null;
      _error = '';
      _cargando = false;
      _framesEstables = 0;
    });
  }

  // ============================================================
  // URL IMÁGENES
  // ============================================================

  String _urlCompleta(String? url) {
    if (url == null || url.isEmpty) return '';

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    return 'http://127.0.0.1:8000$url';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.92),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _gold, size: 18),
          onPressed: () async {
            await _cerrarCamara();

            if (mounted) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'urban studio',
          style: TextStyle(
            color: _gold,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          if (!_iaDesbloqueada)
            TextButton.icon(
              onPressed: (_validandoCodigo || _cargandoBarberos)
                  ? null
                  : _abrirIA,
              icon: const Icon(
                Icons.lock_outline,
                size: 14,
                color: Colors.black,
              ),
              label: const Text(
                'Obtener código',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: _gold,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          if (_iaDesbloqueada)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                border: Border.all(color: Colors.green.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: Colors.green,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'IA activa',
                    style: TextStyle(color: Colors.green, fontSize: 11),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _gold.withOpacity(0.2)),
        ),
      ),
      body: Stack(
        children: [
          _resultado != null ? _pantallaResultado() : _pantallaAnalisis(),
          if (_mostrarCodigo) _overlayCodigoSeguridad(),
        ],
      ),
    );
  }

  // ============================================================
  // OVERLAY CÓDIGO
  // ============================================================

  Widget _overlayCodigoSeguridad() {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.88),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 390),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  border: Border.all(color: _gold.withOpacity(0.28)),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.7),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _gold.withOpacity(0.35)),
                        color: _gold.withOpacity(0.08),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.security_outlined,
                          color: _gold,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'VERIFICACIÓN DE SEGURIDAD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2.4,
                        color: _gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Ingresa el código',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        color: Colors.white,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'El código fue enviado al barbero seleccionado. '
                      'Pídeselo en persona e ingrésalo para continuar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (i) {
                        return Container(
                          width: 42,
                          height: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          child: TextField(
                            controller: _codigoControllers[i],
                            focusNode: _codigoFocus[i],
                            enabled: !_validandoCodigo,
                            textAlign: TextAlign.center,
                            textInputAction: i == 5
                                ? TextInputAction.done
                                : TextInputAction.next,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.04),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.12),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.12),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: _gold,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty && i < 5) {
                                _codigoFocus[i + 1].requestFocus();
                              }

                              if (value.isEmpty && i > 0) {
                                _codigoFocus[i - 1].requestFocus();
                              }

                              if (_codigoCompleto.length == 6) {
                                FocusManager.instance.primaryFocus?.unfocus();
                              }
                            },
                            onSubmitted: (_) {
                              if (i == 5 && _codigoCompleto.length == 6) {
                                _validarCodigo();
                              }
                            },
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    if (_error.isNotEmpty) ...[
                      Text(
                        _error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFe2a394),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _validandoCodigo ? null : _validarCodigo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: const Color(0xFF14120d),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          disabledBackgroundColor: _gold.withOpacity(0.35),
                        ),
                        child: _validandoCodigo
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF14120d),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Verificando...'),
                                ],
                              )
                            : const Text(
                                'VERIFICAR CÓDIGO',
                                style: TextStyle(
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _validandoCodigo
                          ? null
                          : () {
                              _limpiarCodigo();

                              setState(() {
                                _mostrarCodigo = false;
                                _error = '';
                              });
                            },
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PANTALLA PRINCIPAL
  // ============================================================

  Widget _pantallaAnalisis() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            'ANÁLISIS INTELIGENTE',
            style: TextStyle(fontSize: 10, letterSpacing: 6, color: _gold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tu próximo corte,\nvisualizado',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w300,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coloca tu rostro frente a la cámara y la IA '
            'lo detectará automáticamente. También puedes subir una foto.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _textMuted, height: 1.6),
          ),
          const SizedBox(height: 28),
          _indicadorPasos(),
          const SizedBox(height: 24),
          _panelEscaneo(),
          const SizedBox(height: 20),
          if (_cargando) _barraOnda(),
          const SizedBox(height: 8),
          if (!_iaDesbloqueada) _bannerBloqueo(),
          if (_iaDesbloqueada) _botonesAccion(),
          if (_error.isNotEmpty && !_mostrarCodigo) ...[
            const SizedBox(height: 16),
            _mensajeError(),
          ],
          const SizedBox(height: 32),
          _sidebarInfo(),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _mensajeError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error,
              style: const TextStyle(color: Color(0xFFe2a394), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BLOQUEO
  // ============================================================

  Widget _bannerBloqueo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _gold.withOpacity(0.05),
        border: Border.all(color: _gold.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_outline, color: _gold, size: 24),
          const SizedBox(height: 8),
          const Text(
            'IA bloqueada',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Obtén el código de seguridad para activar la IA.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textMuted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_validandoCodigo || _cargandoBarberos)
                  ? null
                  : _abrirIA,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: const Color(0xFF14120d),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: _validandoCodigo
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF14120d),
                      ),
                    )
                  : const Text(
                      'OBTENER CÓDIGO',
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

  // ============================================================
  // PASOS
  // ============================================================

  Widget _indicadorPasos() {
    final pasos = [
      (num: '01', label: 'Detecta tu rostro', icono: Icons.face_outlined),
      (num: '02', label: 'La IA analiza', icono: Icons.auto_awesome),
      (num: '03', label: 'Recibe tu estilo', icono: Icons.content_cut),
    ];

    return Row(
      children: pasos.asMap().entries.map((entry) {
        final i = entry.key;
        final paso = entry.value;

        final activo =
            (_modo == 'inicial' && i == 0) ||
            ((_modo == 'camara' ||
                    _modo == 'preview' ||
                    _modo == 'escaneando') &&
                i == 1) ||
            (_resultado != null && i == 2);

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: activo ? _gold : _surfaceLine,
                        ),
                        color: activo
                            ? _gold.withOpacity(0.1)
                            : Colors.transparent,
                      ),
                      child: Icon(
                        paso.icono,
                        size: 16,
                        color: activo ? _gold : _textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      paso.num,
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: activo ? _gold : _textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      paso.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        color: activo ? Colors.white : _textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < pasos.length - 1)
                Container(width: 20, height: 1, color: _surfaceLine),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // PANEL DE ESCANEO
  // ============================================================

  Widget _panelEscaneo() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _surfaceLine),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            if (_modo == 'inicial') _estadoInicial(),

            if (_modo == 'camara' && _camaraActiva) _vistaCamara(),

            if ((_modo == 'preview' || _modo == 'escaneando') &&
                !_camaraActiva &&
                _imagenBytes != null)
              _estadoPreview(),

            if (_modo == 'escaneando' && !_camaraActiva && _imagenBytes != null)
              _overlayEscaneo(),

            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: _gold, width: 1.5),
                    left: BorderSide(color: _gold, width: 1.5),
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _gold, width: 1.5),
                    right: BorderSide(color: _gold, width: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // VISTA DE CÁMARA
  // ============================================================

  // ============================================================
  // VISTA DE CÁMARA (corregida: ya no se estira/distorsiona)
  // ============================================================

  Widget _vistaCamara() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // previewSize viene "acostado" (landscape) en la mayoría de
          // sensores Android aunque la app esté en modo vertical, por
          // eso se invierte alto/ancho para calcular la proporción real.
          final previewSize = _cameraController!.value.previewSize!;
          final previewAspectRatio = previewSize.height / previewSize.width;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Cámara con "cover" real (recorta en vez de estirar)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: constraints.maxHeight * previewAspectRatio,
                  height: constraints.maxHeight,
                  child: CameraPreview(_cameraController!),
                ),
              ),

              Container(color: Colors.black.withOpacity(0.10)),

              Center(
                child: AnimatedBuilder(
                  animation: _scanController,
                  builder: (_, __) {
                    return CustomPaint(
                      size: const Size(190, 230),
                      painter: _FaceFramePainter(_scanAnimation.value),
                    );
                  },
                ),
              ),

              AnimatedBuilder(
                animation: _scanController,
                builder: (_, __) {
                  return Positioned(
                    left: 55,
                    right: 55,
                    top: 35 + (_scanAnimation.value * 210),
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: _gold,
                        boxShadow: [
                          BoxShadow(
                            color: _gold.withOpacity(0.8),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 22,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.70),
                      border: Border.all(color: _gold.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.face_outlined, color: _gold, size: 15),
                        const SizedBox(width: 8),
                        Text(
                          _error.isEmpty
                              ? 'BUSCANDO ROSTRO...'
                              : _error.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 15,
                left: 15,
                right: 15,
                child: LinearProgressIndicator(
                  value: (_framesEstables / _framesNecesarios).clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withOpacity(0.12),
                  valueColor: const AlwaysStoppedAnimation<Color>(_gold),
                  minHeight: 2,
                ),
              ),

              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () async {
                    await _cerrarCamara();
                    if (!mounted) return;
                    setState(() {
                      _modo = 'inicial';
                      _error = '';
                    });
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.65),
                      border: Border.all(color: _gold.withOpacity(0.5)),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // ESTADO INICIAL
  // ============================================================

  Widget _estadoInicial() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _scanController,
            builder: (_, __) {
              return CustomPaint(
                size: const Size(160, 200),
                painter: _FacePainter(_scanAnimation.value),
              );
            },
          ),

          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () {
                if (_iaDesbloqueada) {
                  _seleccionarImagen(ImageSource.gallery);
                } else {
                  setState(() {
                    _error = 'Primero valida el código de seguridad.';
                  });
                }
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _surfaceLine),
                  color: _surface,
                ),
                child: const Icon(
                  Icons.upload_outlined,
                  size: 14,
                  color: _gold,
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 25,
            child: Text(
              _iaDesbloqueada ? 'LISTO PARA ESCANEAR' : 'IA BLOQUEADA',
              style: TextStyle(
                color: _iaDesbloqueada ? _gold : _textMuted,
                fontSize: 9,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FOTO SELECCIONADA
  // ============================================================

  Widget _estadoPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.memory(
        _imagenBytes!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
      ),
    );
  }

  // ============================================================
  // OVERLAY ANALIZANDO
  // ============================================================

  Widget _overlayEscaneo() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _scanController,
        builder: (_, __) {
          return Stack(
            children: [
              Container(color: Colors.black.withOpacity(0.28)),
              Positioned(
                left: 25,
                right: 25,
                top: 30 + (_scanAnimation.value * 240),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: _gold,
                    boxShadow: [
                      BoxShadow(color: _gold.withOpacity(0.8), blurRadius: 12),
                    ],
                  ),
                ),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.72),
                    border: Border.all(color: _gold.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: _gold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'ANALIZANDO ROSTRO...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // ONDA
  // ============================================================

  Widget _barraOnda() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(20, (i) {
            final h = i % 5 == 0
                ? 1.0
                : i % 3 == 0
                ? 0.7
                : i % 2 == 0
                ? 0.55
                : 0.4;

            return Container(
              width: 2,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              height: 22 * h * (_waveController.value * 0.6 + 0.4),
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        );
      },
    );
  }

  // ============================================================
  // BOTONES
  // ============================================================

  Widget _botonesAccion() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _cargando || _camaraActiva
                ? null
                : _abrirCamaraAutomatica,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: const Color(0xFF14120d),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
              disabledBackgroundColor: _gold.withOpacity(0.35),
            ),
            icon: const Icon(Icons.face_retouching_natural, size: 17),
            label: const Text(
              'ESCANEAR MI ROSTRO',
              style: TextStyle(
                letterSpacing: 2.5,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _cargando
                ? null
                : () {
                    _seleccionarImagen(ImageSource.gallery);
                  },
            style: OutlinedButton.styleFrom(
              foregroundColor: _textMuted,
              side: const BorderSide(color: _surfaceLine),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            icon: const Icon(Icons.upload_outlined, size: 16),
            label: const Text(
              'SUBIR FOTO',
              style: TextStyle(letterSpacing: 3, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INFORMACIÓN
  // ============================================================

  Widget _sidebarInfo() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            border: Border.all(color: _surfaceLine),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ESTILOS TENDENCIA',
                style: TextStyle(fontSize: 10, letterSpacing: 3, color: _gold),
              ),
              const SizedBox(height: 16),
              ...['Mohicano bajo', 'Fade texturizado', 'Corte clásico'].map(
                (estilo) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: _surfaceLine)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _gold.withOpacity(0.08),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.content_cut,
                            size: 12,
                            color: _gold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        estilo,
                        style: const TextStyle(fontSize: 12, color: _textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            border: Border.all(color: _surfaceLine),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CASOS DE ÉXITO',
                style: TextStyle(fontSize: 10, letterSpacing: 3, color: _gold),
              ),
              const SizedBox(height: 16),
              Row(
                children: ['J', 'C', 'A']
                    .map(
                      (letra) => Container(
                        width: 34,
                        height: 34,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _gold),
                          color: _bg,
                        ),
                        child: Center(
                          child: Text(
                            letra,
                            style: const TextStyle(color: _gold, fontSize: 14),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              const Text(
                '+500 clientes ya encontraron su estilo con IA',
                style: TextStyle(fontSize: 12, color: _textMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RESULTADO
  // ============================================================

  Widget _pantallaResultado() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'RESULTADO DEL ANÁLISIS',
            style: TextStyle(fontSize: 10, letterSpacing: 4, color: _gold),
          ),
          const SizedBox(height: 24),

          Container(
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _surfaceLine),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                _statItem('Forma del rostro', _resultado?.formaRostro ?? '—'),
                Container(width: 1, height: 80, color: _surfaceLine),
                _statItem(
                  'Índice cefálico',
                  _resultado?.indiceCefalico?.toString() ?? '—',
                ),
                Container(width: 1, height: 80, color: _surfaceLine),
                _statItem('Tipo de cabello', _resultado?.tipoCabello ?? '—'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _gold),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CORTE RECOMENDADO',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 3,
                    color: _textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _resultado?.nombreCorteSugerido ?? '',
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _resultado?.descripcionIa ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _textMuted,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (_resultado?.imagenResultado != null &&
              (_resultado!.imagenResultado as String).isNotEmpty) ...[
            const Text(
              'ANTES Y DESPUÉS',
              style: TextStyle(fontSize: 10, letterSpacing: 4, color: _gold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _mirrorCard('Foto original', _resultado?.fotoOriginal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _mirrorCard(
                    'Corte sugerido',
                    _resultado?.imagenResultado,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _quitarImagen,
              child: const Text(
                '← Hacer otro análisis',
                style: TextStyle(color: _textMuted, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TARJETA IMAGEN
  // ============================================================

  Widget _mirrorCard(String label, String? url) {
    final urlCompleta = _urlCompleta(url);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _surfaceLine),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          if (urlCompleta.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Image.network(
                urlCompleta,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) {
                    return child;
                  }

                  return Container(
                    height: 120,
                    color: _surfaceLine,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: _gold,
                        strokeWidth: 1,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) {
                  return Container(
                    height: 120,
                    color: _surfaceLine,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: _textMuted,
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              height: 120,
              color: _surfaceLine,
              child: const Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: _textMuted,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 2,
              color: _textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATS
  // ============================================================

  Widget _statItem(String label, String valor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              valor,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: _goldLight,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                letterSpacing: 1,
                color: _textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// PAINTER DEL ROSTRO INICIAL
// ================================================================

class _FacePainter extends CustomPainter {
  final double animValue;

  _FacePainter(this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    final facePaint = Paint()
      ..color = const Color(0xFFc9a227).withOpacity(0.4 + animValue * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.85,
        height: size.height * 0.9,
      ),
      facePaint,
    );

    final dotPaint = Paint()
      ..color = const Color(0xFFc9a227).withOpacity(0.3 + animValue * 0.4)
      ..style = PaintingStyle.fill;

    final puntos = [
      Offset(size.width * 0.2, size.height * 0.35),
      Offset(size.width * 0.8, size.height * 0.35),
      Offset(size.width * 0.5, size.height * 0.5),
      Offset(size.width * 0.35, size.height * 0.65),
      Offset(size.width * 0.65, size.height * 0.65),
      Offset(size.width * 0.15, size.height * 0.55),
      Offset(size.width * 0.85, size.height * 0.55),
      Offset(size.width * 0.3, size.height * 0.2),
      Offset(size.width * 0.7, size.height * 0.2),
    ];

    for (final punto in puntos) {
      canvas.drawCircle(punto, 2, dotPaint);
    }

    final lineY = size.height * (0.1 + animValue * 0.8);

    canvas.drawLine(
      Offset(size.width * 0.05, lineY),
      Offset(size.width * 0.95, lineY),
      Paint()
        ..color = const Color(0xFFc9a227).withOpacity(0.6)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_FacePainter old) {
    return old.animValue != animValue;
  }
}

// ================================================================
// MARCO DEL ESCÁNER REAL
// ================================================================

class _FaceFramePainter extends CustomPainter {
  final double animValue;

  _FaceFramePainter(this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _gold.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.82,
      height: size.height * 0.9,
    );

    canvas.drawOval(rect, paint);

    final pointPaint = Paint()
      ..color = _gold.withOpacity(0.5 + animValue * 0.3)
      ..style = PaintingStyle.fill;

    final puntos = [
      Offset(size.width * 0.28, size.height * 0.35),
      Offset(size.width * 0.72, size.height * 0.35),
      Offset(size.width * 0.5, size.height * 0.50),
      Offset(size.width * 0.35, size.height * 0.68),
      Offset(size.width * 0.65, size.height * 0.68),
    ];

    for (final punto in puntos) {
      canvas.drawCircle(punto, 2.5, pointPaint);
    }

    final lineY = rect.top + rect.height * (0.08 + animValue * 0.84);

    final linePaint = Paint()
      ..color = _gold.withOpacity(0.9)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(rect.left, lineY),
      Offset(rect.right, lineY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_FaceFramePainter oldDelegate) {
    return oldDelegate.animValue != animValue;
  }
}
