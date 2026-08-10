import { Component, ElementRef, ViewChild, OnDestroy, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { GeminiService } from '../../services/gemini';

@Component({
  selector: 'app-analisis-rostro',
  standalone: true,
  imports: [CommonModule, RouterLink],
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

  modo: 'inicial' | 'camara' = 'inicial';
  streamActivo: MediaStream | null = null;

  constructor(private geminiService: GeminiService) {
    const usuarioGuardado = localStorage.getItem('username');
    if (usuarioGuardado) {
      this.nombreUsuario = usuarioGuardado;
    }
  }

  logout() {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('username');
    this.router.navigate(['/login']);
  }

  // --- Subir archivo ---
  onFileSelected(event: any) {
    const file = event.target.files[0];
    if (file) {
      this.setImagen(file);
    }
  }

  // --- Cámara ---
  async activarCamara() {
  this.errorMensaje = '';

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

    setTimeout(async () => {
      if (this.videoRef) {
        const video = this.videoRef.nativeElement;

        video.srcObject = this.streamActivo;

        try {
          await video.play();

          console.log('✅ Cámara reproduciendo');
          console.log('📷 Video width:', video.videoWidth);
          console.log('📷 Video height:', video.videoHeight);
          console.log('📷 ReadyState:', video.readyState);
        } catch (error) {
          console.error('❌ Error reproduciendo cámara:', error);
        }
      }
    }, 100);

  } catch (err) {
    console.error(err);

    this.errorMensaje =
      'No pudimos acceder a la cámara. Revisa los permisos del navegador.';
  }
}

  capturarFoto() {
  if (!this.videoRef || !this.canvasRef) {
    console.error('❌ Video o canvas no disponibles');
    return;
  }

  const video = this.videoRef.nativeElement;
  const canvas = this.canvasRef.nativeElement;

  console.log('========== 📷 CAPTURANDO ==========');
  console.log('Video width:', video.videoWidth);
  console.log('Video height:', video.videoHeight);
  console.log('ReadyState:', video.readyState);
  console.log('Paused:', video.paused);

  if (
    video.videoWidth === 0 ||
    video.videoHeight === 0
  ) {
    this.errorMensaje =
      'La cámara todavía no está lista. Espera un momento e inténtalo nuevamente.';

    console.error('❌ La cámara no tiene dimensiones');
    return;
  }

  if (video.paused) {
    console.error('❌ El video está pausado');
    this.errorMensaje =
      'La cámara todavía no está reproduciendo. Espera un momento.';
    return;
  }

  canvas.width = video.videoWidth;
  canvas.height = video.videoHeight;

  const ctx = canvas.getContext('2d');

  if (!ctx) {
    console.error('❌ No se pudo obtener el contexto del canvas');
    return;
  }

  // Limpiar canvas
  ctx.clearRect(
    0,
    0,
    canvas.width,
    canvas.height
  );

  // Dibujar el frame actual
  ctx.drawImage(
    video,
    0,
    0,
    canvas.width,
    canvas.height
  );

  console.log('✅ Frame dibujado en canvas');

  canvas.toBlob(
    (blob) => {

      if (!blob) {
        console.error('❌ No se pudo crear el Blob');
        return;
      }

      console.log('✅ Blob creado');
      console.log('📦 Tamaño:', blob.size);
      console.log('📄 Tipo:', blob.type);

      if (blob.size < 10000) {
        console.warn(
          '⚠️ La imagen parece demasiado pequeña:',
          blob.size,
          'bytes'
        );

        this.errorMensaje =
          'La captura salió demasiado oscura o vacía. Mira directamente a la cámara y vuelve a intentarlo.';

        return;
      }

      const file = new File(
        [blob],
        'captura.jpg',
        {
          type: 'image/jpeg',
          lastModified: Date.now()
        }
      );

      console.log('✅ File creado');
      console.log('📛 Nombre:', file.name);
      console.log('📦 Tamaño:', file.size);
      console.log('📄 Tipo:', file.type);

      this.setImagen(file);

      this.detenerCamara();

    },
    'image/jpeg',
    0.92
  );
}

  detenerCamara() {
    if (this.streamActivo) {
      this.streamActivo.getTracks().forEach((track) => track.stop());
      this.streamActivo = null;
    }
    this.modo = 'inicial';
  }

  cancelarCamara() {
    this.detenerCamara();
  }

  // --- Común ---
  private setImagen(file: File) {
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
  }

  enviarImagen() {
    if (!this.imagenSeleccionada) return;

    this.cargando = true;
    this.errorMensaje = '';
    this.resultadoAnalisis = null;

    this.geminiService.analizarRostro(this.imagenSeleccionada).subscribe({
      next: (response: any) => {
        this.cargando = false;
        if (response.estado === 'completado') {
          this.resultadoAnalisis = response;
        } else if (response.estado === 'error') {
          this.errorMensaje = response.error_detalle || 'Hubo un error al analizar el rostro.';
        }
      },
      error: (err: any) => {
        this.cargando = false;
        this.errorMensaje = err?.error?.error || 'Hubo un error al analizar el rostro. Inténtalo de nuevo.';
        console.error(err);
      }
    });
  }

  ngOnDestroy() {
    this.detenerCamara();
    if (this.previewUrl) {
      URL.revokeObjectURL(this.previewUrl);
    }
  }
}