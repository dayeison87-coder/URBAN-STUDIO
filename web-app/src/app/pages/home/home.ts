import { Component, inject, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';

interface Mensaje {
  usuario: string;
  mensaje: string;
}

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [CommonModule, RouterLink, FormsModule],
  templateUrl: './home.html',
  styleUrl: './home.css'
})
export class HomeComponent {

  private router = inject(Router);

  nombreUsuario: string = 'Usuario';

  // Flujo IA
  paso: number = 0;
  verificando: boolean = true;
  capturado: boolean = false;
  private stream: MediaStream | null = null;

  @ViewChild('videoRef') videoRef!: ElementRef<HTMLVideoElement>;
  @ViewChild('canvasRef') canvasRef!: ElementRef<HTMLCanvasElement>;

  // =======================
  // CHAT
  // =======================

  chatAbierto = false;
  mensajes: Mensaje[] = [];
  mensajeTexto = '';
  private socket!: WebSocket;

  constructor() {
    const usuarioGuardado = localStorage.getItem('username');

    if (usuarioGuardado) {
      this.nombreUsuario = usuarioGuardado;
    }
  }

  // =======================
  // Navegación
  // =======================

  irACitas() {
    this.router.navigate(['/citas']);
  }

  irAReservas() {
    this.router.navigate(['/servicios']);
  }

  logout() {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('username');

    this.router.navigate(['/login']);
  }

  // =======================
  // IA
  // =======================

  abrirIA() {
    this.paso = 1;
    this.verificando = true;
    this.capturado = false;

    setTimeout(() => {
      this.verificando = false;
    }, 1500);
  }

  solicitarCamara() {
    this.paso = 2;
  }

  async activarCamara() {
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: 'user',
          width: 640,
          height: 480
        }
      });

      this.paso = 3;

      setTimeout(() => {
        if (this.videoRef?.nativeElement) {
          this.videoRef.nativeElement.srcObject = this.stream;
        }
      }, 100);

    } catch (err) {
      alert('No se pudo acceder a la cámara.');
      console.error(err);
    }
  }

  escanear() {
    const video = this.videoRef.nativeElement;
    const canvas = this.canvasRef.nativeElement;

    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;

    const ctx = canvas.getContext('2d');

    ctx?.save();
    ctx?.translate(canvas.width, 0);
    ctx?.scale(-1, 1);
    ctx?.drawImage(video, 0, 0);
    ctx?.restore();

    this.capturado = true;
  }

  cerrarModal() {
    this.paso = 0;
    this.capturado = false;

    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop());
      this.stream = null;
    }
  }

  cerrarSiOverlay(event: MouseEvent) {
    if ((event.target as HTMLElement).classList.contains('modal-bg')) {
      this.cerrarModal();
    }
  }

  // =======================
  // CHAT
  // =======================

  abrirChat() {
    this.chatAbierto = true;

    if (!this.socket || this.socket.readyState === WebSocket.CLOSED) {

      this.socket = new WebSocket('ws://localhost:8000/ws/chat/general/');

      this.socket.onopen = () => {
        console.log('✅ Chat conectado');
      };

      this.socket.onmessage = (event) => {
        const data = JSON.parse(event.data);
        this.mensajes.push(data);
      };

      this.socket.onerror = (error) => {
        console.error('Error WebSocket:', error);
      };

      this.socket.onclose = () => {
        console.log('🔴 Chat desconectado');
      };
    }
  }

  cerrarChat() {
    this.chatAbierto = false;
  }

  enviarMensaje() {

    if (!this.mensajeTexto.trim()) {
      return;
    }

    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
      alert('El chat aún no está conectado.');
      return;
    }

    this.socket.send(JSON.stringify({
      usuario: this.nombreUsuario,
      mensaje: this.mensajeTexto
    }));

    this.mensajeTexto = '';
  }

}