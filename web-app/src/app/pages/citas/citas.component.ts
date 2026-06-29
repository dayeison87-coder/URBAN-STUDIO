import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
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

interface Barbero {
  id: number;
  username: string;
  email: string;
}

interface HoraSlot {
  valor: string;
  ocupado: boolean;
}

@Component({
  selector: 'app-citas',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './citas.component.html',
  styleUrl: './citas.component.css'
})
export class CitasComponent implements OnInit {
  private http = inject(HttpClient);
  private apiUrl = 'http://localhost:8000/api';
  private router = inject(Router);

  paso = 0; // 0 = oculto (solo muestra mis citas)
  editandoId: number | null = null;
  mensaje = '';

  categorias: Categoria[] = [];
  barberos: Barbero[] = [];
  listaCitas: any[] = [];
  citasExistentes: any[] = [];

  categoriaSeleccionada: Categoria | null = null;
  servicioSeleccionado: Servicio | null = null;
  barberoSeleccionado: Barbero | null = null;
  fechaSeleccionada = '';
  horaSeleccionada = '';

  hoy = new Date();
  mesActual = new Date(this.hoy.getFullYear(), this.hoy.getMonth(), 1);
  diasSemana = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
  diasCalendario: (Date | null)[] = [];
  meses = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
  horariosBase = ['09:00','09:30','10:00','10:30','11:00','11:30','12:00','12:30','14:00','14:30','15:00','15:30','16:00','16:30','17:00','17:30'];
  horariosDisponibles: HoraSlot[] = [];

  get nombreMes(): string { return this.meses[this.mesActual.getMonth()]; }
  get anioActual(): number { return this.mesActual.getFullYear(); }

  private getHeaders(): HttpHeaders {
    const token = localStorage.getItem('access_token') || '';
    return new HttpHeaders({ 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` });
  }

  ngOnInit(): void {
    this.cargarCategorias();
    this.cargarBarberos();
    this.cargarCitas();
    this.generarCalendario();
  }

  cargarCategorias(): void {
    this.http.get<Categoria[]>(`${this.apiUrl}/categorias/`).subscribe({
      next: (data) => this.categorias = data,
      error: (err) => console.error(err)
    });
  }

  cargarBarberos(): void {
    this.http.get<Barbero[]>(`${this.apiUrl}/usuarios/barberos/`, { headers: this.getHeaders() }).subscribe({
      next: (data) => this.barberos = data,
      error: (err) => console.error(err)
    });
  }

  cargarCitas(): void {
    this.http.get<any[]>(`${this.apiUrl}/citas/`, { headers: this.getHeaders() }).subscribe({
      next: (data) => { this.listaCitas = data; this.citasExistentes = data; },
      error: (err) => console.error(err)
    });
  }

  // ── Iniciar nueva cita ────────────────────────────────────
  nuevaCita(): void {
    this.editandoId = null;
    this.resetearSelecciones();
    this.paso = 1;
  }

  
  volverHome(): void {
  this.router.navigate(['/home']);
  }

  // ── Editar cita existente ─────────────────────────────────
  editarCita(cita: any): void {
    this.editandoId = cita.id;
    this.paso = 1;
    this.resetearSelecciones();

    // Precargar categoría
    setTimeout(() => {
      // Buscar categoría que contiene el servicio
      for (const cat of this.categorias) {
        const srv = cat.servicios.find(s => s.id === cita.servicio);
        if (srv) {
          this.categoriaSeleccionada = cat;
          this.servicioSeleccionado = srv;
          break;
        }
      }
      // Precargar barbero
      this.barberoSeleccionado = this.barberos.find(b => b.id === cita.barbero) || null;
      // Precargar fecha y hora
      this.fechaSeleccionada = cita.fecha;
      this.horaSeleccionada = cita.hora?.substring(0, 5);
      if (this.fechaSeleccionada) this.calcularHorarios();
    }, 300);
  }

  // ── Selecciones ───────────────────────────────────────────
  seleccionarCategoria(cat: Categoria): void { this.categoriaSeleccionada = cat; this.servicioSeleccionado = null; }
  seleccionarServicio(srv: Servicio): void { this.servicioSeleccionado = srv; }
  seleccionarBarbero(b: Barbero): void { this.barberoSeleccionado = b; this.fechaSeleccionada = ''; this.horaSeleccionada = ''; }

  seleccionarFecha(dia: Date): void {
    this.fechaSeleccionada = this.formatFecha(dia);
    this.horaSeleccionada = '';
    this.calcularHorarios();
  }

  seleccionarHora(hora: string): void { this.horaSeleccionada = hora; }

  irPaso(n: number): void { this.paso = n; this.mensaje = ''; }

  // ── Calendario ────────────────────────────────────────────
  generarCalendario(): void {
    const año = this.mesActual.getFullYear();
    const mes = this.mesActual.getMonth();
    const primerDia = new Date(año, mes, 1).getDay();
    const diasEnMes = new Date(año, mes + 1, 0).getDate();
    this.diasCalendario = [];
    for (let i = 0; i < primerDia; i++) this.diasCalendario.push(null);
    for (let d = 1; d <= diasEnMes; d++) this.diasCalendario.push(new Date(año, mes, d));
  }

  mesPrevio(): void {
    const hoy = new Date();
    const anterior = new Date(this.mesActual.getFullYear(), this.mesActual.getMonth() - 1, 1);
    if (anterior >= new Date(hoy.getFullYear(), hoy.getMonth(), 1)) {
      this.mesActual = anterior; this.generarCalendario();
    }
  }

  mesSiguiente(): void {
    this.mesActual = new Date(this.mesActual.getFullYear(), this.mesActual.getMonth() + 1, 1);
    this.generarCalendario();
  }

  esPasado(dia: Date): boolean {
    const hoy = new Date(); hoy.setHours(0,0,0,0);
    return dia < hoy;
  }

  formatFecha(dia: Date): string {
    const y = dia.getFullYear();
    const m = String(dia.getMonth() + 1).padStart(2, '0');
    const d = String(dia.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  calcularHorarios(): void {
    const citasDelDia = this.citasExistentes.filter(
      c => c.fecha === this.fechaSeleccionada &&
           c.barbero === this.barberoSeleccionado?.id &&
           c.id !== this.editandoId  // excluye la cita que se está editando
    );
    const horasOcupadas = citasDelDia.map((c: any) => c.hora.substring(0, 5));
    this.horariosDisponibles = this.horariosBase.map(h => ({
      valor: h,
      ocupado: horasOcupadas.includes(h)
    }));
  }

  tieneTodasHorasOcupadas(dia: Date): boolean {
    const fecha = this.formatFecha(dia);
    const citasDelDia = this.citasExistentes.filter(
      c => c.fecha === fecha && c.barbero === this.barberoSeleccionado?.id
    );
    return citasDelDia.length >= this.horariosBase.length;
  }

  // ── Confirmar / Guardar ────────────────────────────────────
  confirmarCita(): void {
    if (!this.servicioSeleccionado || !this.barberoSeleccionado || !this.fechaSeleccionada || !this.horaSeleccionada) {
      this.mensaje = 'Completa todos los pasos.'; return;
    }

    const payload = {
      servicio: this.servicioSeleccionado.id,
      barbero:  this.barberoSeleccionado.id,
      fecha:    this.fechaSeleccionada,
      hora:     this.horaSeleccionada + ':00',
      estado:   'Pendiente'
    };

    if (this.editandoId !== null) {
      // EDITAR
      this.http.put(`${this.apiUrl}/citas/${this.editandoId}/`, payload, { headers: this.getHeaders() }).subscribe({
        next: () => { this.mensaje = '✓ Cita actualizada correctamente.'; this.cargarCitas(); this.resetear(); },
        error: (err) => { console.error(err); this.mensaje = 'Error al actualizar la cita.'; }
      });
    } else {
      // CREAR
      this.http.post(`${this.apiUrl}/citas/`, payload, { headers: this.getHeaders() }).subscribe({
        next: () => { this.mensaje = '✓ Cita agendada correctamente.'; this.cargarCitas(); this.resetear(); },
        error: (err) => { console.error(err); this.mensaje = 'Error al agendar la cita.'; }
      });
    }
  }

  borrarCita(id: number): void {
    if (confirm('¿Cancelar esta cita?')) {
      this.http.delete(`${this.apiUrl}/citas/${id}/`, { headers: this.getHeaders() }).subscribe({
        next: () => { this.mensaje = 'Cita cancelada.'; this.cargarCitas(); },
        error: (err) => console.error(err)
      });
    }
  }

  resetear(): void {
    this.paso = 0;
    this.editandoId = null;
    this.resetearSelecciones();
    setTimeout(() => this.mensaje = '', 4000);
  }

  resetearSelecciones(): void {
    this.categoriaSeleccionada = null;
    this.servicioSeleccionado = null;
    this.barberoSeleccionado = null;
    this.fechaSeleccionada = '';
    this.horaSeleccionada = '';
  }

  // ── Helpers ───────────────────────────────────────────────
  getIconCategoria(slug: string): string {
    const iconos: Record<string, string> = { cabello: '✂', barba: '🪒', rostro: '✨', productos: '🛍' };
    return iconos[slug] ?? '✦';
  }

  getInicial(nombre: string): string { return nombre.charAt(0).toUpperCase(); }

  formatPrecio(precio: any): string {
    if (!precio) return '';
    return '$' + parseFloat(precio).toLocaleString('es-CO');
  }
}