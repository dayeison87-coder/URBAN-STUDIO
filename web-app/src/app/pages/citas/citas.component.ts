import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { ActivatedRoute, Router } from '@angular/router';

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

interface Disponibilidad {
  dia_semana: string;
  hora_inicio: string;
  hora_fin: string;
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
  private route = inject(ActivatedRoute);

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
  disponibilidades: Disponibilidad[] = [];

  // ── 🌟 VARIABLES PARA EL SISTEMA DE CALIFICACIÓN ────────────────────────
  citaSeleccionadaId: number | null = null;
  estrellas: number[] = [1, 2, 3, 4, 5];
  calificacionSeleccionada = 0;
  votoTemporal = 0;
  comentario = '';
  mensajeCalificacion = '';

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
    this.route.queryParams.subscribe(params => {
      const categoriaId = Number(params['categoria']);
      const servicioId = Number(params['servicio']);
      if (categoriaId && servicioId) {
        this.preseleccionarServicio(categoriaId, servicioId);
      }
    });
  }

  cargarCategorias(): void {
    this.http.get<Categoria[]>(`${this.apiUrl}/categorias/`).subscribe({
      next: (data) => {
        this.categorias = data;
        const params = this.route.snapshot.queryParams;
        const categoriaId = Number(params['categoria']);
        const servicioId = Number(params['servicio']);
        if (categoriaId && servicioId) this.preseleccionarServicio(categoriaId, servicioId);
      },
      error: (err) => console.error(err)
    });
  }

  private preseleccionarServicio(categoriaId: number, servicioId: number): void {
    const categoria = this.categorias.find(cat => cat.id === categoriaId);
    const servicio = categoria?.servicios.find(srv => srv.id === servicioId && srv.disponible);
    if (categoria && servicio) {
      this.categoriaSeleccionada = categoria;
      this.servicioSeleccionado = servicio;
      this.paso = 3;
    }
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

  nuevaCita(): void {
    this.editandoId = null;
    this.resetearSelecciones();
    this.paso = 1;
  }

  volverHome(): void {
    this.router.navigate(['/home']);
  }

  editarCita(cita: any): void {
    this.editandoId = cita.id;
    this.paso = 1;
    this.resetearSelecciones();

    setTimeout(() => {
      for (const cat of this.categorias) {
        const srv = cat.servicios.find(s => s.id === cita.servicio);
        if (srv) {
          this.categoriaSeleccionada = cat;
          this.servicioSeleccionado = srv;
          break;
        }
      }
      this.barberoSeleccionado = this.barberos.find(b => b.id === cita.barbero) || null;
      if (this.barberoSeleccionado) this.cargarDisponibilidad(this.barberoSeleccionado.id);
      this.fechaSeleccionada = cita.fecha;
      this.horaSeleccionada = cita.hora?.substring(0, 5);
      if (this.fechaSeleccionada) this.calcularHorarios();
    }, 300);
  }

  seleccionarCategoria(cat: Categoria): void { this.categoriaSeleccionada = cat; this.servicioSeleccionado = null; }
  seleccionarServicio(srv: Servicio): void { this.servicioSeleccionado = srv; }
  seleccionarBarbero(b: Barbero): void {
    this.barberoSeleccionado = b;
    this.fechaSeleccionada = '';
    this.horaSeleccionada = '';
    this.horariosDisponibles = [];
    this.cargarDisponibilidad(b.id);
  }

  private cargarDisponibilidad(barberoId: number): void {
    this.http.get<Disponibilidad[]>(`${this.apiUrl}/disponibilidad/?barbero=${barberoId}`, { headers: this.getHeaders() }).subscribe({
      next: (data) => this.disponibilidades = data,
      error: (err) => console.error('Error cargando disponibilidad:', err)
    });
  }

  seleccionarFecha(dia: Date): void {
    this.fechaSeleccionada = this.formatFecha(dia);
    this.horaSeleccionada = '';
    this.calcularHorarios();
  }

  seleccionarHora(hora: string): void { this.horaSeleccionada = hora; }

  irPaso(n: number): void { this.paso = n; this.mensaje = ''; }

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
           c.id !== this.editandoId
    );

    const horasOcupadas = citasDelDia.map((c: any) => c.hora.substring(0, 5));

    const ahora = new Date();
    const fechaHoy = this.formatFecha(ahora);

    const esHoy = this.fechaSeleccionada === fechaHoy;

    const minutosActuales = ahora.getHours() * 60 + ahora.getMinutes();

    const diaSemana = this.diaSemana(this.fechaSeleccionada);
    const jornada = this.disponibilidades.find(h => this.normalizarDia(h.dia_semana) === diaSemana);
    const horariosDeJornada = jornada ? this.generarFranjas(jornada.hora_inicio, jornada.hora_fin) : [];

    this.horariosDisponibles = horariosDeJornada.map(h => {
      const [hora, minutos] = h.split(':').map(Number);
      const minutosHorario = hora * 60 + minutos;

      const horaPasada = esHoy && minutosHorario <= minutosActuales;

      return {
        valor: h,
        ocupado: horasOcupadas.includes(h) || horaPasada
      };
    });
  }

  tieneTodasHorasOcupadas(dia: Date): boolean {
    const fecha = this.formatFecha(dia);
    const diaSemana = this.diaSemana(fecha);
    const jornada = this.disponibilidades.find(h => this.normalizarDia(h.dia_semana) === diaSemana);
    const horariosDeJornada = jornada ? this.generarFranjas(jornada.hora_inicio, jornada.hora_fin) : [];
    const citasDelDia = this.citasExistentes.filter(
      c => c.fecha === fecha && c.barbero === this.barberoSeleccionado?.id
    );
    return horariosDeJornada.length > 0 && citasDelDia.length >= horariosDeJornada.length;
  }

  private diaSemana(fecha: string): string {
    const [año, mes, dia] = fecha.split('-').map(Number);
    return ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'][new Date(año, mes - 1, dia).getDay()];
  }

  private normalizarDia(dia: string): string {
    return dia.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  }

  private generarFranjas(inicio: string, fin: string): string[] {
    const [horaInicio, minutoInicio] = inicio.substring(0, 5).split(':').map(Number);
    const [horaFin, minutoFin] = fin.substring(0, 5).split(':').map(Number);
    const inicioMinutos = horaInicio * 60 + minutoInicio;
    const finMinutos = horaFin * 60 + minutoFin;
    const franjas: string[] = [];
    for (let minutos = inicioMinutos; minutos + 30 <= finMinutos; minutos += 30) {
      franjas.push(`${String(Math.floor(minutos / 60)).padStart(2, '0')}:${String(minutos % 60).padStart(2, '0')}`);
    }
    return franjas;
  }

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
      this.http.put(`${this.apiUrl}/citas/${this.editandoId}/`, payload, { headers: this.getHeaders() }).subscribe({
        next: () => { this.mensaje = '✓ Cita actualizada correctamente.'; this.cargarCitas(); this.resetear(); },
        error: (err) => { console.error(err); this.mensaje = 'Error al actualizar la cita.'; }
      });
    } else {
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

  // ── 🌟 FUNCIONES PARA EL MANEJO VISUAL DE LAS ESTRELLAS ────────────────────────
  abrirModalCalificar(citaId: number): void {
    this.citaSeleccionadaId = citaId;
    this.calificacionSeleccionada = 0;
    this.votoTemporal = 0;
    this.comentario = '';
    this.mensajeCalificacion = '';
  }

  fijarCalificacion(voto: number): void {
    this.calificacionSeleccionada = voto;
  }

  resaltarEstrellas(voto: number): void {
    this.votoTemporal = voto;
  }

  limpiarResaltado(): void {
    this.votoTemporal = 0;
  }

  enviarCalificacion(): void {
    if (this.calificacionSeleccionada === 0) {
      this.mensajeCalificacion = 'Por favor selecciona al menos una estrella.';
      return;
    }

    const payload = {
      cita: this.citaSeleccionadaId,
      estrellas: this.calificacionSeleccionada,
      comentario: this.comentario
    };

    this.http.post(`${this.apiUrl}/calificaciones/`, payload, { headers: this.getHeaders() }).subscribe({
      next: () => {
        this.mensajeCalificacion = '✓ ¡Muchas gracias por calificar!';
        this.cargarCitas();
        setTimeout(() => {
          this.citaSeleccionadaId = null;
        }, 2000);
      },
      error: (err) => {
        console.error(err);
        if (err.error && err.error.non_field_errors) {
          this.mensajeCalificacion = err.error.non_field_errors[0];
        } else {
          this.mensajeCalificacion = 'Error al enviar la calificación.';
        }
      }
    });
  }

  // ── Helpers ───────────────────────────────────────────────
  getIconCategoria(slug: string): string {
    if (!slug) return 'bi bi-scissors';

    const slugLimpio = slug.toLowerCase();

    if (slugLimpio.includes('barba')) {
      return 'bi bi-person-bounding-box';
    }
    if (slugLimpio.includes('corte') || slugLimpio.includes('cabello') || slugLimpio.includes('pelo')) {
      return 'bi bi-scissors';
    }
    if (slugLimpio.includes('rostro') || slugLimpio.includes('facil') || slugLimpio.includes('facial') || slugLimpio.includes('skin')) {
      return 'bi bi-stars';
    }
    if (slugLimpio.includes('producto') || slugLimpio.includes('tienda')) {
      return 'bi bi-bag-check';
    }
    if (slugLimpio.includes('color') || slugLimpio.includes('tint')) {
      return 'bi bi-paint-bucket';
    }

    return 'bi bi-scissors';
  }

  getInicial(nombre: string): string { return nombre.charAt(0).toUpperCase(); }

  formatPrecio(precio: any): string {
    if (!precio) return '';
    return '$' + parseFloat(precio).toLocaleString('es-CO');
  }
}