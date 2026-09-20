import { Component, ElementRef, ViewChild, OnDestroy, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { Subscription } from 'rxjs';
import { GeminiService } from '../../services/gemini';
import {
  FaceLandmarker,
  FilesetResolver,
  NormalizedLandmark
} from '@mediapipe/tasks-vision';

interface Barbero {
  id: number;
  username: string;
  experiencia?: number | null;
}

@Component({
  selector: 'app-analisis-rostro',
  standalone: true,
  imports: [CommonModule, RouterLink, FormsModule],
  templateUrl: './gemini.html',
  styleUrls: ['./gemini.css']
})
export class AnalisisRostroComponent implements OnDestroy {

  @ViewChild('video') videoRef?: ElementRef<HTMLVideoElement>;
  @ViewChild('canvas') canvasRef?: ElementRef<HTMLCanvasElement>;

  private router = inject(Router);

  nombreUsuario: string = 'Usuario';

  imagenSeleccionada: File | null = null;
  previewUrl: string | null = null;

  resultadoAnalisis: any = null;

  cargando = false;
  errorMensaje = '';
  private analisisSubscription?: Subscription;

  // ==========================================
  // CÓDIGO DE SEGURIDAD / ACCESO A LA IA
  // ==========================================

  mostrarCodigo = false;
  codigo = '';
  codigoInputs = [0, 1, 2, 3, 4, 5];
  codigoEnviado = false;
  validandoCodigo = false;
  mostrarSelectorBarbero = false;
  cargandoBarberos = false;
  barberos: Barbero[] = [];
  barberoSeleccionado: number | null = null;

  iaDesbloqueada = false;

  // Puntos de referencia visuales del escáner, equivalentes al overlay
  // de la aplicación móvil. No representan datos faciales reales: sirven
  // para mostrar el recorrido del escaneo mientras se estabiliza la cámara.
  readonly puntosEscaneo = [
    { x: 23, y: 33, delay: '0s' },
    { x: 77, y: 33, delay: '0.15s' },
    { x: 50, y: 50, delay: '0.3s' },
    { x: 32, y: 70, delay: '0.45s' },
    { x: 68, y: 70, delay: '0.6s' }
  ];

  // ==========================================
  // CÁMARA
  // ==========================================

  modo: 'inicial' | 'camara' = 'inicial';
  streamActivo: MediaStream | null = null;

  // Mensaje corto que se muestra en la cámara (mismos textos que la app
  // de Flutter).
  estadoCamara: string = '';

  // Progreso 0-100 de la captura automática. IGUAL QUE EN FLUTTER:
  // solo sube mientras hay UN rostro bien puesto y de frente; si el rostro
  // se pierde, hay más de uno o se descentra, vuelve a 0.
  progresoEscaneo = 0;

  private escaneoActivo = false;
  private framesEscaneo = 0;
  // Frames estables que se necesitan para capturar (igual que Flutter: 12).
  private readonly FRAMES_ESCANEO_NECESARIOS = 12;
  // Igual que Flutter: se analiza como máximo un frame cada 100 ms.
  private readonly INTERVALO_FRAMES_MS = 100;
  private ultimoFrameProcesado = 0;

  private escaneoFrameId?: number;
  private faceLandmarker?: FaceLandmarker;
  private detectorInicializandose?: Promise<FaceLandmarker>;

  private videoListoListener?: () => void;
  private fallbackTimer?: ReturnType<typeof setTimeout>;
  private intentosCaptura = 0;
  private readonly MAX_INTENTOS_CAPTURA = 6;

  // Brillo mínimo promedio (0-255) que debe tener el frame capturado
  // para considerarlo válido. Frames muy oscuros suelen significar que
  // la cámara todavía no terminó de ajustar exposición/enfoque.
  private readonly BRILLO_MINIMO = 22;
  // Brillo máximo: descarta fotos quemadas (mismo valor que en Flutter).
  private readonly BRILLO_MAXIMO = 235;

  constructor(private geminiService: GeminiService) {

    const usuarioGuardado = localStorage.getItem('username');

    if (usuarioGuardado) {
      this.nombreUsuario = usuarioGuardado;
    }
  }

  // ==========================================
  // LOGOUT
  // ==========================================

  logout() {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('username');
    this.router.navigate(['/login']);
  }

  // ==========================================
  // ABRIR IA DESDE EL NAVBAR
  // ==========================================

  abrirIA() {

    if (this.iaDesbloqueada) {
      this.mostrarSelectorBarbero = false;
      return;
    }

    this.errorMensaje = '';
    this.cargandoBarberos = true;

    this.geminiService.obtenerBarberos().subscribe({
      next: (barberos) => {
        this.barberos = barberos;
        this.cargandoBarberos = false;
        this.mostrarSelectorBarbero = true;
      },
      error: () => {
        this.cargandoBarberos = false;
        this.errorMensaje = 'No fue posible cargar los barberos disponibles.';
      }
    });
  }

  // ==========================================
  // SUBIR ARCHIVO
  // ==========================================

  onFileSelected(event: any) {
    const file = event.target.files[0];
    if (file) {
      this.setImagen(file);
    }
  }

  // ==========================================
  // CÁMARA: ACTIVACIÓN
  // ==========================================

  async activarCamara() {

    if (!this.iaDesbloqueada) {
      this.errorMensaje =
        'Primero debes validar el código de seguridad para utilizar la IA.';
      return;
    }

    this.errorMensaje = '';
    this.intentosCaptura = 0;
    this.progresoEscaneo = 0;
    this.estadoCamara = 'Encendiendo cámara…';

    try {

      this.streamActivo = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: 'user',
          width: { ideal: 640 },
          height: { ideal: 480 }
        },
        audio: false
      });

      this.modo = 'camara';

      // Esperamos al siguiente ciclo para que Angular ya haya
      // renderizado el <video> del *ngIf antes de asignarle el stream.
      setTimeout(() => this.prepararVideo(), 0);

    } catch (err) {
      console.error('❌ Error obteniendo la cámara:', err);
      this.errorMensaje =
        'No pudimos acceder a la cámara. Revisa los permisos del navegador.';
      this.estadoCamara = '';
    }
  }

  private prepararVideo() {

    if (!this.videoRef || !this.streamActivo) {
      return;
    }

    const video = this.videoRef.nativeElement;

    video.muted = true;
    video.playsInline = true;
    video.srcObject = this.streamActivo;

    this.estadoCamara = 'Preparando cámara…';

    // En vez de adivinar con un tiempo fijo, esperamos al evento real
    // que indica que ya hay un frame de video decodificado antes de
    // arrancar la detección.
    this.videoListoListener = () => {
      if (this.videoListoListener) {
        video.removeEventListener('loadeddata', this.videoListoListener);
        this.videoListoListener = undefined;
      }
      if (this.fallbackTimer) {
        clearTimeout(this.fallbackTimer);
        this.fallbackTimer = undefined;
      }
      void this.iniciarEscaneo();
    };

    video.addEventListener('loadeddata', this.videoListoListener);

    void video.play().catch((error) => {
      console.error('Error reproduciendo cámara:', error);
    });

    // Red de seguridad: si 'loadeddata' nunca llega (pasa en algunos
    // navegadores/dispositivos), arrancamos de todos modos en vez de
    // dejar la cámara colgada para siempre.
    this.fallbackTimer = setTimeout(() => {
      if (this.modo === 'camara' && !this.escaneoActivo) {
        void this.iniciarEscaneo();
      }
    }, 4000);
  }

  // ==========================================
  // CÁMARA: DETECTAR ROSTRO, LLENAR PROGRESO Y CAPTURAR
  // (misma lógica que _procesarFrameCamara de Flutter)
  // ==========================================

  private async iniciarEscaneo() {
    if (this.escaneoActivo) {
      return;
    }
    this.escaneoActivo = true;
    this.framesEscaneo = 0;
    this.progresoEscaneo = 0;
    this.ultimoFrameProcesado = 0;
    this.estadoCamara = 'Coloca tu rostro dentro del marco';

    try {
      const detector = await this.obtenerDetectorFacial();
      if (this.modo !== 'camara' || !this.streamActivo) {
        return;
      }
      this.detectarRostroEnVideo(detector);
    } catch (error) {
      console.error('Error inicializando detector facial:', error);
      this.escaneoActivo = false;
      this.errorMensaje = 'No fue posible iniciar el detector facial.';
      this.detenerCamara();
    }
  }

  private obtenerDetectorFacial(): Promise<FaceLandmarker> {
    if (this.faceLandmarker) {
      return Promise.resolve(this.faceLandmarker);
    }
    if (!this.detectorInicializandose) {
      this.detectorInicializandose = FilesetResolver.forVisionTasks(
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.22/wasm'
      ).then((vision) => FaceLandmarker.createFromOptions(vision, {
        baseOptions: {
          modelAssetPath:
            'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task'
        },
        runningMode: 'VIDEO',
        // 2 para poder avisar "Solo debe aparecer un rostro" (como Flutter).
        numFaces: 2,
        minFaceDetectionConfidence: 0.65,
        minFacePresenceConfidence: 0.65,
        minTrackingConfidence: 0.65
      })).then((detector) => {
        this.faceLandmarker = detector;
        return detector;
      });
    }
    return this.detectorInicializandose;
  }

  private detectarRostroEnVideo(detector: FaceLandmarker) {
    const video = this.videoRef?.nativeElement;
    if (!video || this.modo !== 'camara' || !this.streamActivo) {
      this.escaneoActivo = false;
      return;
    }

    const ahora = performance.now();

    // Igual que Flutter: un frame analizado cada ~100 ms.
    if (ahora - this.ultimoFrameProcesado >= this.INTERVALO_FRAMES_MS) {
      this.ultimoFrameProcesado = ahora;

      const resultado = detector.detectForVideo(video, ahora);
      const rostros = resultado.faceLandmarks ?? [];

      if (rostros.length === 0) {
        this.actualizarEscaneo(0, 'Coloca tu rostro dentro del marco');
      } else if (rostros.length > 1) {
        this.actualizarEscaneo(0, 'Solo debe aparecer un rostro');
      } else if (!this.rostroEstaCorrectamentePosicionado(rostros[0], video)) {
        this.actualizarEscaneo(0, 'Centra tu rostro dentro del marco');
      } else {
        // Rostro bien puesto: el progreso sube un frame.
        const frames = this.framesEscaneo + 1;
        const porcentaje = Math.round(
          Math.min(frames / this.FRAMES_ESCANEO_NECESARIOS, 1) * 100
        );
        this.actualizarEscaneo(frames, `Rostro detectado · ${porcentaje}%`);

        if (frames >= this.FRAMES_ESCANEO_NECESARIOS) {
          this.escaneoActivo = false;
          this.finalizarEscaneo();
          return;
        }
      }
    }

    this.escaneoFrameId = requestAnimationFrame(() => {
      this.detectarRostroEnVideo(detector);
    });
  }

  /** Actualiza frames, porcentaje de la barra y mensaje de estado. */
  private actualizarEscaneo(frames: number, estado: string) {
    this.framesEscaneo = frames;
    this.progresoEscaneo = Math.round(
      Math.min(frames / this.FRAMES_ESCANEO_NECESARIOS, 1) * 100
    );
    this.estadoCamara = estado;
  }

  /**
   * Mismos rangos que _rostroEstaCorrecto de Flutter:
   * centrado, tamaño correcto, de frente y sin inclinar la cabeza.
   */
  private rostroEstaCorrectamentePosicionado(
    landmarks: NormalizedLandmark[],
    video: HTMLVideoElement
  ): boolean {
    const xs = landmarks.map((punto) => punto.x);
    const ys = landmarks.map((punto) => punto.y);
    const izquierda = Math.min(...xs);
    const derecha = Math.max(...xs);
    const arriba = Math.min(...ys);
    const abajo = Math.max(...ys);
    const centroX = (izquierda + derecha) / 2;
    const centroY = (arriba + abajo) / 2;
    const ancho = derecha - izquierda;
    const alto = abajo - arriba;

    const posicionOk =
      centroX > 0.30 &&
      centroX < 0.70 &&
      centroY > 0.25 &&
      centroY < 0.75 &&
      ancho > 0.18 &&
      ancho < 0.75 &&
      alto > 0.18 &&
      alto < 0.85;

    const nariz = landmarks[1];
    const ojoIzquierdo = landmarks[33];
    const ojoDerecho = landmarks[263];

    // Mirando al frente (equivale a headEulerAngleY < 18 de Flutter).
    // MediaPipe web no entrega ángulos, así que se usa la nariz respecto
    // al centro de los ojos.
    const ojosCentroX = (ojoIzquierdo.x + ojoDerecho.x) / 2;
    const deFrente = Math.abs(nariz.x - ojosCentroX) < ancho * 0.22;

    // Cabeza sin inclinar (equivale a headEulerAngleZ < 18 de Flutter):
    // ángulo de la línea de los ojos, en píxeles reales.
    const dx = Math.abs(ojoDerecho.x - ojoIzquierdo.x) * video.videoWidth;
    const dy = Math.abs(ojoDerecho.y - ojoIzquierdo.y) * video.videoHeight;
    const inclinacionGrados = (Math.atan2(dy, dx) * 180) / Math.PI;
    const sinInclinar = inclinacionGrados < 18;

    return posicionOk && deFrente && sinInclinar;
  }

  private finalizarEscaneo() {

    if (this.modo !== 'camara' || !this.streamActivo) {
      this.escaneoActivo = false;
      return;
    }

    const video = this.videoRef?.nativeElement;

    const listo =
      !!video &&
      video.videoWidth > 0 &&
      video.videoHeight > 0 &&
      !video.paused &&
      video.readyState >= 2;

    if (!listo) {
      this.reintentarEscaneo('Preparando cámara…');
      return;
    }

    const resultado = this.capturarFrameSiEsValido();

    if (!resultado) {
      // El frame salió demasiado oscuro/negro: reiniciamos la detección.
      this.reintentarEscaneo('Ajustando iluminación…');
      return;
    }

    this.escaneoActivo = false;
    this.estadoCamara = '';
    this.setImagen(resultado);
    this.detenerCamara();
    this.analizarImagen();
  }

  private reintentarEscaneo(mensaje: string) {

    this.intentosCaptura++;

    if (this.intentosCaptura >= this.MAX_INTENTOS_CAPTURA) {
      this.escaneoActivo = false;
      this.errorMensaje =
        'No pudimos obtener una imagen clara de la cámara. Verifica la iluminación o los permisos e inténtalo de nuevo.';
      this.detenerCamara();
      return;
    }

    this.estadoCamara = mensaje;
    this.progresoEscaneo = 0;

    void this.iniciarEscaneo();
  }

  // ==========================================
  // CAPTURA MANUAL (botón, disponible como respaldo)
  // ==========================================

  capturarFoto(analizarAutomaticamente = false) {

    if (!this.iaDesbloqueada) {
      this.errorMensaje = 'Primero debes validar el código de seguridad.';
      return;
    }

    if (this.escaneoFrameId !== undefined) {
      cancelAnimationFrame(this.escaneoFrameId);
      this.escaneoFrameId = undefined;
    }
    this.escaneoActivo = false;

    const resultado = this.capturarFrameSiEsValido(/* exigirBrillo */ false);

    if (!resultado) {
      this.errorMensaje =
        'No recibimos imagen de la cámara. Revisa los permisos e inténtalo de nuevo.';
      this.detenerCamara();
      return;
    }

    this.setImagen(resultado);
    this.detenerCamara();

    if (analizarAutomaticamente) {
      this.analizarImagen();
    }
  }

  /**
   * Dibuja el frame actual del video en el canvas oculto y valida que
   * tenga contenido real (no esté negro) antes de convertirlo a File.
   * Devuelve null si el frame no es válido/aceptable todavía.
   */
  private capturarFrameSiEsValido(exigirBrillo: boolean = true): File | null {

    if (!this.videoRef || !this.canvasRef) {
      return null;
    }

    const video = this.videoRef.nativeElement;
    const canvas = this.canvasRef.nativeElement;

    if (video.videoWidth === 0 || video.videoHeight === 0) {
      return null;
    }

    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;

    const ctx = canvas.getContext('2d');
    if (!ctx) {
      return null;
    }

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // La vista previa de cámara se muestra como espejo. Guardamos el frame
    // con el mismo reflejo para que la foto y el resultado no cambien de lado.
    ctx.save();
    ctx.translate(canvas.width, 0);
    ctx.scale(-1, 1);
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
    ctx.restore();

    if (exigirBrillo && !this.frameTieneBrilloSuficiente(ctx, canvas.width, canvas.height)) {
      return null;
    }

    return this.canvasABlobSincrono(canvas);
  }

  /**
   * Calcula el brillo promedio de una muestra de píxeles del frame.
   * Un frame casi negro (cámara aún ajustando exposición) da un
   * promedio muy bajo, así lo descartamos y reintentamos.
   */
  private frameTieneBrilloSuficiente(
    ctx: CanvasRenderingContext2D,
    width: number,
    height: number
  ): boolean {

    try {
      const muestra = ctx.getImageData(0, 0, width, height).data;

      let suma = 0;
      let contados = 0;

      // Muestreamos 1 de cada ~40 píxeles para que sea rápido.
      const paso = 40 * 4;

      for (let i = 0; i < muestra.length; i += paso) {
        const r = muestra[i];
        const g = muestra[i + 1];
        const b = muestra[i + 2];
        suma += (r + g + b) / 3;
        contados++;
      }

      const promedio = contados > 0 ? suma / contados : 0;

      return promedio >= this.BRILLO_MINIMO && promedio <= this.BRILLO_MAXIMO;

    } catch (error) {
      // Si por algún motivo no se puede leer el canvas (ej. políticas
      // de seguridad), no bloqueamos el flujo por esto.
      console.warn('No se pudo evaluar el brillo del frame:', error);
      return true;
    }
  }

  private canvasABlobSincrono(canvas: HTMLCanvasElement): File | null {

    const dataUrl = canvas.toDataURL('image/jpeg', 0.92);
    const partes = dataUrl.split(',');

    if (partes.length !== 2) {
      return null;
    }

    const binario = atob(partes[1]);
    const bytes = new Uint8Array(binario.length);

    for (let i = 0; i < binario.length; i++) {
      bytes[i] = binario.charCodeAt(i);
    }

    if (bytes.length < 8000) {
      // Imagen sospechosamente pequeña: probablemente vacía/corrupta.
      return null;
    }

    return new File([bytes], 'captura.jpg', {
      type: 'image/jpeg',
      lastModified: Date.now()
    });
  }

  // ==========================================
  // DETENER CÁMARA
  // ==========================================

  detenerCamara() {

    if (this.escaneoFrameId !== undefined) {
      cancelAnimationFrame(this.escaneoFrameId);
      this.escaneoFrameId = undefined;
    }

    if (this.fallbackTimer) {
      clearTimeout(this.fallbackTimer);
      this.fallbackTimer = undefined;
    }

    if (this.videoRef && this.videoListoListener) {
      this.videoRef.nativeElement.removeEventListener('loadeddata', this.videoListoListener);
      this.videoListoListener = undefined;
    }

    if (this.streamActivo) {
      this.streamActivo.getTracks().forEach((track) => track.stop());
      this.streamActivo = null;
    }

    this.faceLandmarker?.close();
    this.faceLandmarker = undefined;
    this.detectorInicializandose = undefined;
    this.intentosCaptura = 0;
    this.framesEscaneo = 0;
    this.progresoEscaneo = 0;
    this.ultimoFrameProcesado = 0;
    this.escaneoActivo = false;
    this.estadoCamara = '';
    this.modo = 'inicial';
  }

  cancelarCamara() {
    this.detenerCamara();
  }

  // ==========================================
  // GUARDAR IMAGEN
  // ==========================================

  private setImagen(file: File) {

    if (!this.iaDesbloqueada) {
      this.errorMensaje =
        'Primero debes validar el código de seguridad para utilizar la IA.';
      return;
    }

    this.imagenSeleccionada = file;
    this.previewUrl = URL.createObjectURL(file);
    this.resultadoAnalisis = null;
    this.errorMensaje = '';
  }

  quitarImagen() {

    this.imagenSeleccionada = null;

    if (this.previewUrl) {
      URL.revokeObjectURL(this.previewUrl);
      this.previewUrl = null;
    }

    this.resultadoAnalisis = null;
  }

  cancelarYReescanear() {
    this.analisisSubscription?.unsubscribe();
    this.analisisSubscription = undefined;
    this.cargando = false;
    this.quitarImagen();
    this.errorMensaje = '';
    void this.activarCamara();
  }

  // ==========================================
  // SOLICITAR CÓDIGO
  // ==========================================

  solicitarCodigo() {

    if (this.barberoSeleccionado === null) {
      this.errorMensaje = 'Debes seleccionar un barbero.';
      return;
    }

    this.errorMensaje = '';
    this.validandoCodigo = true;

    this.geminiService.solicitarCodigoIA(this.barberoSeleccionado).subscribe({
      next: () => {
        this.validandoCodigo = false;
        this.mostrarCodigo = true;
        this.mostrarSelectorBarbero = false;
        this.codigoEnviado = true;
      },
      error: (err: any) => {
        this.validandoCodigo = false;
        this.errorMensaje =
          err?.error?.error || 'No fue posible enviar el código de seguridad.';
      }
    });
  }

  // ==========================================
  // INPUT DEL CÓDIGO DE SEGURIDAD
  // ==========================================

  actualizarCodigo(event: Event, index: number): void {

    const input = event.target as HTMLInputElement;

    let valor = input.value.replace(/\D/g, '');

    if (valor.length > 1) {
      valor = valor.charAt(valor.length - 1);
    }

    const codigoArray = this.codigo.split('');
    codigoArray[index] = valor;
    this.codigo = codigoArray.join('').slice(0, 6);

    input.value = valor;

    if (valor && index < 5) {
      const inputs = document.querySelectorAll<HTMLInputElement>('.codigo-input');
      inputs[index + 1]?.focus();
    }
  }

  manejarTecla(event: KeyboardEvent, index: number): void {

    if (
      event.key === 'Backspace' &&
      !(event.target as HTMLInputElement).value &&
      index > 0
    ) {
      const inputs = document.querySelectorAll<HTMLInputElement>('.codigo-input');
      inputs[index - 1]?.focus();
    }
  }

  pegarCodigo(event: ClipboardEvent): void {

    event.preventDefault();

    const texto = event.clipboardData?.getData('text').replace(/\D/g, '').slice(0, 6);

    if (!texto) {
      return;
    }

    this.codigo = texto;

    setTimeout(() => {
      const inputs = document.querySelectorAll<HTMLInputElement>('.codigo-input');
      const index = Math.min(texto.length - 1, 5);
      inputs[index]?.focus();
    });
  }

  // ==========================================
  // VALIDAR CÓDIGO
  // ==========================================

  validarCodigo() {

    if (!this.codigo.trim()) {
      this.errorMensaje = 'Debes ingresar el código de seguridad.';
      return;
    }

    if (this.barberoSeleccionado === null) {
      this.errorMensaje = 'Debes seleccionar un barbero.';
      return;
    }

    this.errorMensaje = '';
    this.validandoCodigo = true;

    this.geminiService.validarCodigoIA(this.codigo.trim(), this.barberoSeleccionado).subscribe({
      next: () => {
        this.validandoCodigo = false;
        this.mostrarCodigo = false;
        this.codigoEnviado = false;
        this.codigo = '';
        this.iaDesbloqueada = true;
      },
      error: (err: any) => {
        this.validandoCodigo = false;
        this.errorMensaje = err?.error?.error || 'El código ingresado no es válido.';
      }
    });
  }

  // ==========================================
  // ENVIAR / ANALIZAR IMAGEN
  // ==========================================

  enviarImagen() {

    if (!this.iaDesbloqueada) {
      this.errorMensaje =
        'Primero debes validar el código de seguridad para utilizar la IA.';
      return;
    }

    if (!this.imagenSeleccionada) {
      this.errorMensaje = 'Primero selecciona o captura una imagen.';
      return;
    }

    this.analizarImagen();
  }

  private analizarImagen() {

    if (!this.iaDesbloqueada) {
      this.errorMensaje = 'El acceso a la IA no está autorizado.';
      return;
    }

    if (!this.imagenSeleccionada) {
      return;
    }

    this.cargando = true;
    this.errorMensaje = '';
    this.resultadoAnalisis = null;

    this.analisisSubscription = this.geminiService.analizarRostro(this.imagenSeleccionada).subscribe({
      next: (response: any) => {

        this.cargando = false;

        if (response.estado === 'completado') {
          this.resultadoAnalisis = response;
        } else if (response.estado === 'error') {
          this.errorMensaje =
            response.error_detalle || 'Hubo un error al analizar el rostro.';
        }
      },
      error: (err: any) => {
        this.cargando = false;
        this.errorMensaje =
          err?.error?.error || 'Hubo un error al analizar el rostro. Inténtalo de nuevo.';
        console.error(err);
      }
    });
  }

  // ==========================================
  // DESTRUIR COMPONENTE
  // ==========================================

  ngOnDestroy() {

    this.detenerCamara();
    this.analisisSubscription?.unsubscribe();

    if (this.previewUrl) {
      URL.revokeObjectURL(this.previewUrl);
    }
  }
}