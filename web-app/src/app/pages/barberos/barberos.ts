import { Component, OnInit, inject, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { BarberosService } from '../../services/barberos';

@Component({
  selector: 'app-barberos',
  standalone: true,
  imports: [CommonModule, RouterLink, FormsModule],
  templateUrl: './barberos.html',
  styleUrl: './barberos.css'
})
export class Barberos implements OnInit {
  private barberosService = inject(BarberosService);
  private router = inject(Router);

  barberos: any[] = [];
  nombreUsuario: string = localStorage.getItem('username') || 'Usuario';

  // --- Lógica IA ---
  paso: number = 0;
  verificando: boolean = false;
  capturado: boolean = false;
  private stream: MediaStream | null = null;
  @ViewChild('videoRef') videoRef!: ElementRef<HTMLVideoElement>;
  @ViewChild('canvasRef') canvasRef!: ElementRef<HTMLCanvasElement>;

  constructor() {}

  ngOnInit(): void {
    this.cargarBarberos();
  }

  cargarBarberos() {
    this.barberosService.obtenerBarberos().subscribe({
      next: (data) => this.barberos = data,
      error: (err) => console.error(err)
    });
  }

  // --- MÉTODOS IA (Copiados de Home para que funcionen aquí) ---
  abrirIA() {
    this.paso = 1; this.verificando = true;
    setTimeout(() => { this.verificando = false; }, 1500);
  }

  solicitarCamara() { this.paso = 2; }

  async activarCamara() {
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ video: { width: 640, height: 480 } });
      this.paso = 3;
      setTimeout(() => { if (this.videoRef?.nativeElement) this.videoRef.nativeElement.srcObject = this.stream; }, 100);
    } catch (err) { console.error(err); }
  }

  escanear() {
    const video = this.videoRef.nativeElement;
    const canvas = this.canvasRef.nativeElement;
    canvas.width = video.videoWidth; canvas.height = video.videoHeight;
    const ctx = canvas.getContext('2d');
    ctx?.drawImage(video, 0, 0);
    this.capturado = true;
  }

  cerrarModal() {
    this.paso = 0;
    if (this.stream) { this.stream.getTracks().forEach(t => t.stop()); }
  }

  cerrarSiOverlay(event: MouseEvent) {
    if ((event.target as HTMLElement).classList.contains('modal-bg')) this.cerrarModal();
  }

  // --- Navegación ---
  irACitas() { this.router.navigate(['/citas']); }
  logout() {
    localStorage.clear();
    this.router.navigate(['/login']);
  }
}