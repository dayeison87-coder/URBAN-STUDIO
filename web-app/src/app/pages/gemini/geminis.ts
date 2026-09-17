import { Component, ElementRef, ViewChild, OnDestroy, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { GeminiService } from '../../services/gemini';

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

  // Indica si el usuario ya validó correctamente
  // el código y puede utilizar la IA.
  iaDesbloqueada = false;

  // ==========================================
  // CÁMARA
  // ==========================================

  modo: 'inicial' | 'camara' = 'inicial';
  streamActivo: MediaStream | null = null;
  private autoCaptureTimer?: ReturnType<typeof setTimeout>;
  private cameraReadyFallbackTimer?: ReturnType<typeof setTimeout>;
  private intentosCaptura = 0;
  private readonly MAX_INTENTOS_CAPTURA = 5;
  private escaneoProgramado = false;

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

    // Si ya validó el código anteriormente,
    // no necesitamos volver a solicitarlo.
    if (this.iaDesbloqueada) {
      return;
    }

    this.errorMensaje = '';

    // Solicitar código al correo
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
  // CÁMARA
  // ==========================================

  async activarCamara() {

    // Seguridad adicional:
    // no permitimos utilizar la cámara
    // si la IA todavía está bloqueada.
    if (!this.iaDesbloqueada) {

      this.errorMensaje =
        'Primero debes validar el código de seguridad para utilizar la IA.';

      return;
    }

    this.errorMensaje = '';

    try {

      this.streamActivo =
        await navigator.mediaDevices.getUserMedia({

          video: {
            facingMode: 'user',
            width: { ideal: 640 },
            height: { ideal: 480 }
          },

          audio: false
        });

      this.modo = 'camara';

      setTimeout(async () => {

        if (this.videoRef) {

          const video =
            this.videoRef.nativeElement;

          video.muted = true;
          video.playsInline = true;
          video.srcObject =
            this.streamActivo;

          try {
            // Algunos navegadores dejan esta promesa pendiente aun cuando el
            // stream ya fue autorizado. No bloqueamos el escaneo por ello.
            void video.play().catch((error) => {
              console.error('Error reproduciendo cámara:', error);
            });

            // La apertura de la cámara debe venir de un clic por seguridad
            // del navegador. Una vez concedido el permiso, la captura y el
            // análisis se hacen solos para no pedir un segundo clic al usuario.
            // No esperamos eventos de video: algunos navegadores no los emiten
            // aunque el stream esté activo, lo que dejaba el escáner bloqueado.
            this.programarCapturaAutomatica();

            console.log('✅ Cámara reproduciendo');

            console.log(
              '📷 Video width:',
              video.videoWidth
            );

            console.log(
              '📷 Video height:',
              video.videoHeight
            );

            console.log(
              '📷 ReadyState:',
              video.readyState
            );

          } catch (error) {

            console.error(
              '❌ Error reproduciendo cámara:',
              error
            );
          }
        }

      }, 100);

    } catch (err) {

      console.error(err);

      this.errorMensaje =
        'No pudimos acceder a la cámara. Revisa los permisos del navegador.';
    }
  }

  private iniciarVideoYEsperarListo(video: HTMLVideoElement) {
    this.escaneoProgramado = false;
    this.intentosCaptura = 0;

    const programarEscaneo = () => {
      if (this.escaneoProgramado || this.modo !== 'camara' || !this.streamActivo) {
        return;
      }

      this.escaneoProgramado = true;
      if (this.cameraReadyFallbackTimer) {
        clearTimeout(this.cameraReadyFallbackTimer);
        this.cameraReadyFallbackTimer = undefined;
      }

      // Da tiempo para centrar el rostro antes de la captura automática.
      this.autoCaptureTimer = setTimeout(() => this.intentarCapturaAutomatica(), 1200);
    };

    video.addEventListener('loadeddata', programarEscaneo, { once: true });
    video.addEventListener('canplay', programarEscaneo, { once: true });

    if (video.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA && video.videoWidth > 0) {
      programarEscaneo();
    }

    // Respaldo para navegadores que no emiten los eventos esperados.
    this.cameraReadyFallbackTimer = setTimeout(programarEscaneo, 4000);
  }

  private intentarCapturaAutomatica() {
    const video = this.videoRef?.nativeElement;
    const listo = !!video && !video.paused && video.videoWidth > 0 && video.videoHeight > 0;

    if (listo) {
      this.capturarFoto(true);
      return;
    }

    this.intentosCaptura += 1;
    if (this.intentosCaptura < this.MAX_INTENTOS_CAPTURA && this.modo === 'camara') {
      this.autoCaptureTimer = setTimeout(() => this.intentarCapturaAutomatica(), 500);
      return;
    }

    this.errorMensaje =
      'La cámara no entregó imagen. Revisa el permiso de cámara del navegador y vuelve a intentarlo.';
    this.detenerCamara();
  }

  private programarCapturaAutomatica() {
    this.intentosCaptura = 0;
    if (this.autoCaptureTimer) {
      clearTimeout(this.autoCaptureTimer);
    }

    // La cámara puede tardar en mostrar el primer cuadro. Tras esta pausa,
    // intentarCapturaAutomatica verifica el video y reintenta si hace falta.
    this.autoCaptureTimer = setTimeout(() => this.intentarCapturaAutomatica(), 3000);
  }

  // ==========================================
  // CAPTURAR FOTO
  // ==========================================

  capturarFoto(analizarAutomaticamente = false) {

    if (!this.iaDesbloqueada) {

      this.errorMensaje =
        'Primero debes validar el código de seguridad.';

      return;
    }

    if (!this.videoRef || !this.canvasRef) {

      console.error(
        '❌ Video o canvas no disponibles'
      );

      return;
    }

    const video =
      this.videoRef.nativeElement;

    const canvas =
      this.canvasRef.nativeElement;

    console.log(
      '========== 📷 CAPTURANDO =========='
    );

    console.log(
      'Video width:',
      video.videoWidth
    );

    console.log(
      'Video height:',
      video.videoHeight
    );

    console.log(
      'ReadyState:',
      video.readyState
    );

    console.log(
      'Paused:',
      video.paused
    );

    if (video.videoWidth === 0 || video.videoHeight === 0 || video.paused) {
      this.intentarCapturaAutomatica();
      return;
    }

    if (
      video.videoWidth === 0 ||
      video.videoHeight === 0
    ) {

      this.errorMensaje =
        'No recibimos imagen de la cámara. Revisa que el navegador tenga permitido usar la cámara y vuelve a intentarlo.';

      this.detenerCamara();

      return;
    }

    if (video.paused) {

      this.errorMensaje =
        'La cámara todavía no está reproduciendo. Espera un momento.';

      return;
    }

    canvas.width =
      video.videoWidth;

    canvas.height =
      video.videoHeight;

    const ctx =
      canvas.getContext('2d');

    if (!ctx) {

      console.error(
        '❌ No se pudo obtener el contexto del canvas'
      );

      return;
    }

    ctx.clearRect(
      0,
      0,
      canvas.width,
      canvas.height
    );

    ctx.drawImage(
      video,
      0,
      0,
      canvas.width,
      canvas.height
    );

    canvas.toBlob(
      (blob) => {

        if (!blob) {

          console.error(
            '❌ No se pudo crear el Blob'
          );

          return;
        }

        if (blob.size < 10000) {

          this.errorMensaje =
            'La cámara entregó una imagen vacía. Revisa el permiso de cámara del navegador y vuelve a intentarlo.';

          this.detenerCamara();

          return;
        }

        const file =
          new File(
            [blob],
            'captura.jpg',
            {
              type: 'image/jpeg',
              lastModified: Date.now()
            }
          );

        this.setImagen(file);

        this.detenerCamara();

        if (analizarAutomaticamente) {
          this.analizarImagen();
        }

      },
      'image/jpeg',
      0.92
    );
  }

  // ==========================================
  // DETENER CÁMARA
  // ==========================================

  detenerCamara() {

    if (this.autoCaptureTimer) {
      clearTimeout(this.autoCaptureTimer);
      this.autoCaptureTimer = undefined;
    }

    if (this.cameraReadyFallbackTimer) {
      clearTimeout(this.cameraReadyFallbackTimer);
      this.cameraReadyFallbackTimer = undefined;
    }

    this.intentosCaptura = 0;
    this.escaneoProgramado = false;

    if (this.streamActivo) {

      this.streamActivo
        .getTracks()
        .forEach(
          (track) => track.stop()
        );

      this.streamActivo = null;
    }

    this.modo = 'inicial';
  }

  cancelarCamara() {

    this.detenerCamara();
  }

  // ==========================================
  // GUARDAR IMAGEN
  // ==========================================

  private setImagen(file: File) {

    // No permitimos seleccionar imagen
    // si la IA todavía está bloqueada.
    if (!this.iaDesbloqueada) {

      this.errorMensaje =
        'Primero debes validar el código de seguridad para utilizar la IA.';

      return;
    }

    this.imagenSeleccionada = file;

    this.previewUrl =
      URL.createObjectURL(file);

    this.resultadoAnalisis = null;

    this.errorMensaje = '';
  }

  quitarImagen() {

    this.imagenSeleccionada = null;
    this.resultadoAnalisis = null;
    this.errorMensaje = '';

    if (this.previewUrl) {

      URL.revokeObjectURL(
        this.previewUrl
      );

      this.previewUrl = null;
    }
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

    this.geminiService
      .solicitarCodigoIA(this.barberoSeleccionado)
      .subscribe({

        next: () => {

          this.validandoCodigo = false;

          this.mostrarCodigo = true;
          this.mostrarSelectorBarbero = false;
          this.codigoEnviado = true;

        },

        error: (err: any) => {

          this.validandoCodigo = false;

          this.errorMensaje =
            err?.error?.error ||
            'No fue posible enviar el código de seguridad.';
        }
      });
  }

  
    // ==========================================
  // INPUT DEL CÓDIGO DE SEGURIDAD
  // ==========================================

  actualizarCodigo(event: Event, index: number): void {

    const input = event.target as HTMLInputElement;

    // Solo permitimos números
    let valor = input.value.replace(/\D/g, '');

    // Solo un número por casilla
    if (valor.length > 1) {
      valor = valor.charAt(valor.length - 1);
    }

    const codigoArray = this.codigo
      .split('');

    codigoArray[index] = valor;

    this.codigo = codigoArray
      .join('')
      .slice(0, 6);

    input.value = valor;

    // Pasar automáticamente a la siguiente casilla
    if (valor && index < 5) {

      const inputs =
        document.querySelectorAll<HTMLInputElement>(
          '.codigo-input'
        );

      inputs[index + 1]?.focus();
    }
  }


  manejarTecla(
    event: KeyboardEvent,
    index: number
  ): void {

    // Si presiona Backspace estando
    // la casilla vacía, vuelve a la anterior
    if (
      event.key === 'Backspace' &&
      !(event.target as HTMLInputElement).value &&
      index > 0
    ) {

      const inputs =
        document.querySelectorAll<HTMLInputElement>(
          '.codigo-input'
        );

      inputs[index - 1]?.focus();
    }
  }


  pegarCodigo(event: ClipboardEvent): void {

    event.preventDefault();

    const texto =
      event.clipboardData
        ?.getData('text')
        .replace(/\D/g, '')
        .slice(0, 6);

    if (!texto) {
      return;
    }

    this.codigo = texto;

    // Esperamos a que Angular actualice
    // los inputs antes de mover el foco
    setTimeout(() => {

      const inputs =
        document.querySelectorAll<HTMLInputElement>(
          '.codigo-input'
        );

      const index =
        Math.min(texto.length - 1, 5);

      inputs[index]?.focus();

    });
  }

  // ==========================================
  // VALIDAR CÓDIGO
  // ==========================================

  validarCodigo() {

    if (!this.codigo.trim()) {

      this.errorMensaje =
        'Debes ingresar el código de seguridad.';

      return;
    }

    this.errorMensaje = '';
    this.validandoCodigo = true;

    if (this.barberoSeleccionado === null) {
      this.validandoCodigo = false;
      this.errorMensaje = 'Debes seleccionar un barbero.';
      return;
    }

    this.geminiService
      .validarCodigoIA(this.codigo.trim(), this.barberoSeleccionado)
      .subscribe({

        next: () => {

          this.validandoCodigo = false;

          this.mostrarCodigo = false;
          this.codigoEnviado = false;
          this.codigo = '';

          // ======================================
          // CÓDIGO CORRECTO
          // ======================================

          this.iaDesbloqueada = true;

          console.log(
            '✅ IA desbloqueada correctamente'
          );

        },

        error: (err: any) => {

          this.validandoCodigo = false;

          this.errorMensaje =
            err?.error?.error ||
            'El código ingresado no es válido.';
        }
      });
  }

  // ==========================================
  // ANALIZAR IMAGEN
  // ==========================================

  enviarImagen() {

    if (!this.iaDesbloqueada) {

      this.errorMensaje =
        'Primero debes validar el código de seguridad para utilizar la IA.';

      return;
    }

    if (!this.imagenSeleccionada) {

      this.errorMensaje =
        'Primero selecciona o captura una imagen.';

      return;
    }

    // Si ya validó el código,
    // analizamos directamente.
    this.analizarImagen();
  }

  // ==========================================
  // ANALIZAR IMAGEN
  // ==========================================

  private analizarImagen() {

    if (!this.iaDesbloqueada) {

      this.errorMensaje =
        'El acceso a la IA no está autorizado.';

      return;
    }

    if (!this.imagenSeleccionada) {
      return;
    }

    this.cargando = true;

    this.errorMensaje = '';

    this.resultadoAnalisis = null;

    this.geminiService
      .analizarRostro(
        this.imagenSeleccionada
      )
      .subscribe({

        next: (response: any) => {

          this.cargando = false;

          if (
            response.estado ===
            'completado'
          ) {

            this.resultadoAnalisis =
              response;

          } else if (
            response.estado === 'error'
          ) {

            this.errorMensaje =
              response.error_detalle ||
              'Hubo un error al analizar el rostro.';
          }
        },

        error: (err: any) => {

          this.cargando = false;

          this.errorMensaje =
            err?.error?.error ||
            'Hubo un error al analizar el rostro. Inténtalo de nuevo.';

          console.error(err);
        }
      });
  }

  // ==========================================
  // DESTRUIR COMPONENTE
  // ==========================================

  ngOnDestroy() {

    this.detenerCamara();

    if (this.previewUrl) {

      URL.revokeObjectURL(
        this.previewUrl
      );
    }
  }
}
