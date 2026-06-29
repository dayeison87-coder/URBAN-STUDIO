// servicio.component.ts

import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';

interface Servicio {
  id: number;
  nombre: string;
  descripcion: string;
  precio: string;
  disponible: boolean;
}

interface Categoria {
  id: number;
  slug: string;
  nombre: string;
  descripcion: string;
  servicios: Servicio[];
}

@Component({
  selector: 'app-servicio',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './servicio.component.html',
  styleUrls: ['./servicio.component.css']
})
export class ServicioComponent implements OnInit {

  categorias: Categoria[] = [];
  categoriaActiva: Categoria | null = null;
  cargando = true;

  // Iconos SVG por categoría
  iconos: Record<string, string> = {
    cabello: `<svg viewBox="0 0 80 80" fill="none" stroke="#c9a96e" stroke-width="0.5">
      <path d="M20 60 Q30 20 40 40 Q50 60 60 20"/>
      <circle cx="40" cy="12" r="4"/>
      <path d="M30 50 Q40 35 50 50"/>
    </svg>`,
    barba: `<svg viewBox="0 0 80 80" fill="none" stroke="#c9a96e" stroke-width="0.5">
      <path d="M25 30 Q20 50 25 65 Q40 72 55 65 Q60 50 55 30"/>
      <path d="M30 28 Q40 22 50 28"/>
      <path d="M32 50 Q40 55 48 50"/>
    </svg>`,
    rostro: `<svg viewBox="0 0 80 80" fill="none" stroke="#c9a96e" stroke-width="0.5">
      <ellipse cx="40" cy="38" rx="16" ry="20"/>
      <circle cx="34" cy="34" r="2"/>
      <circle cx="46" cy="34" r="2"/>
      <path d="M34 46 Q40 50 46 46"/>
    </svg>`,
    productos: `<svg viewBox="0 0 80 80" fill="none" stroke="#c9a96e" stroke-width="0.5">
      <rect x="28" y="24" width="24" height="36" rx="2"/>
      <path d="M34 24 V20 Q40 16 46 20 V24"/>
      <line x1="34" y1="38" x2="46" y2="38"/>
      <line x1="34" y1="44" x2="42" y2="44"/>
    </svg>`,
  };

  numeros: Record<number, string> = { 0: '01', 1: '02', 2: '03', 3: '04' };

  constructor(private http: HttpClient, private router: Router) {}

  volver(): void {
  this.router.navigate(['/home']);
}

  ngOnInit(): void {
    this.http.get<Categoria[]>('http://localhost:8000/api/categorias/')
      .subscribe({
        next: (data) => {
          this.categorias = data;
          this.cargando = false;
        },
        error: (err) => {
          console.error('Error cargando categorías:', err);
          this.cargando = false;
        }
      });
  }

  abrirModal(categoria: Categoria): void {
    this.categoriaActiva = categoria;
  }

  cerrarModal(): void {
    this.categoriaActiva = null;
  }

  cerrarSiOverlay(event: MouseEvent): void {
    if ((event.target as HTMLElement).classList.contains('us-modal-bg')) {
      this.cerrarModal();
    }
  }

  getIcono(slug: string): string {
    return this.iconos[slug] ?? this.iconos['cabello'];
  }

  formatPrecio(precio: string): string {
    const num = parseFloat(precio);
    return '$' + num.toLocaleString('es-CO');
  }

  irACitas() {
    this.router.navigate(['/citas']);
  }
}