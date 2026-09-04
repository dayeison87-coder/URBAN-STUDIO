import { Component, inject, OnDestroy, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Router } from '@angular/router';

// Interfaces
interface Cita {
  id: number;
  cliente: number;
  cliente_nombre: string;
  servicio_nombre: string;
  servicio_precio: string;
  fecha: string;
  hora: string;
  estado: string;
}

interface Disponibilidad {
  id?: number;
  dia_semana: string;
  hora_inicio: string;
  hora_fin: string;
}

interface Perfil {
  id: number;
  username: string;
  email: string;
  telefono: string;
  descripcion: string;
  experiencia: number | null;
  foto: string | null;
}

interface Mensaje {
  usuario: string;
  mensaje: string;
  propio?: boolean;
}

interface DashboardResumen {
  citas: number; clientes: number; servicios: number;
  ingresos_total: number; ingresos_semana: number; ingresos_mes: number;
  valoracion: number; valoraciones_total: number;
}

interface ClienteBarbero {
  id: number; nombre: string; email: string; telefono: string;
  total_citas: number; ultimo_servicio: string; ultima_fecha: string;
}

interface HistorialCorte {
  id: number; cliente_nombre: string; servicio_nombre: string;
  precio: string; fecha: string; hora: string; observaciones: string;
}

interface IngresoDiario { fecha: string; total: number; }


@Component({
  selector: 'app-barbero',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './barbero.html',
  styleUrl: './barbero.css'
})
export class BarberoComponent implements OnInit, OnDestroy {
  private http = inject(HttpClient);
  private router = inject(Router);

  nombreUsuario = '';

  // ✅ Ahora incluye la pestaña chat
  pestanaActiva: 'dashboard' | 'clientes' | 'historial' | 'ingresos' | 'citas' | 'horarios' | 'perfil' | 'chat' = 'dashboard';

  mensaje = '';

  listaCitas: Cita[] = [];
  listaHorarios: Disponibilidad[] = [];
  horarioEditandoId: number | null = null;
  dashboardResumen: DashboardResumen = {
    citas: 0, clientes: 0, servicios: 0, ingresos_total: 0,
    ingresos_semana: 0, ingresos_mes: 0, valoracion: 0, valoraciones_total: 0
  };
  listaClientes: ClienteBarbero[] = [];
  historialCortes: HistorialCorte[] = [];
  ingresosDiarios: IngresoDiario[] = [];
  cargandoDashboard = true;
  fechaHoy = new Date().toISOString().substring(0, 10);
  errorDashboard = '';
  filtroCitas = '';
  estadoCitas = 'Todas';
  filtroHistorial = '';
  fechaHistorial = '';
  private actualizacionAutomatica?: ReturnType<typeof setInterval>;

  perfil: Perfil = {
    id: 0,
    username: '',
    email: '',
    telefono: '',
    descripcion: '',
    experiencia: null,
    foto: null
  };

  fotoPreview: string | null = null;
  fotoArchivo: File | null = null;

  dias = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo'
  ];

  horarioForm: Disponibilidad = {
    dia_semana: 'Lunes',
    hora_inicio: '08:00',
    hora_fin: '17:00'
  };

  // Chat
  mensajes: Mensaje[] = [];
  mensajeTexto = '';
  private socket!: WebSocket;
  barberoId = '';

  private apiUrl = 'http://localhost:8000/api';

  private getHeaders(): HttpHeaders {
    const token = localStorage.getItem('access_token');

    return new HttpHeaders({
      'Content-Type': 'application/json',
      'Authorization': token ? `Bearer ${token}` : ''
    });
  }

  private getHeadersMultipart(): HttpHeaders {
    const token = localStorage.getItem('access_token');

    return new HttpHeaders({
      'Authorization': token ? `Bearer ${token}` : ''
    });
  }

  ngOnInit(): void {
    this.nombreUsuario = localStorage.getItem('username') || 'Barbero';

    this.cargarCitas();
    this.cargarDashboard();
    this.cargarHorarios();
    this.cargarPerfil();
    this.iniciarChat();
    this.actualizacionAutomatica = setInterval(() => this.cargarDashboard(), 15000);
  }

  // ✅ También acepta "chat"
  cambiarPestana(p: 'dashboard' | 'clientes' | 'historial' | 'ingresos' | 'citas' | 'horarios' | 'perfil' | 'chat'): void {
    this.pestanaActiva = p;
    this.mensaje = '';
    if (['dashboard', 'clientes', 'historial', 'ingresos', 'citas'].includes(p)) {
      this.cargarCitas();
      this.cargarDashboard();
    }
  }

  ngOnDestroy(): void {
    if (this.actualizacionAutomatica) clearInterval(this.actualizacionAutomatica);
    this.socket?.close();
  }

  // ───────────── CITAS ─────────────

  cargarCitas(): void {
    this.http.get<Cita[]>(`${this.apiUrl}/citas/`, {
      headers: this.getHeaders()
    }).subscribe({
      next: (data) => {
        this.listaCitas = data;
        this.sincronizarDesdeCitas(data);
      },
      error: (err) => {
        console.error('Error citas:', err);
        this.errorDashboard = 'No se pudieron cargar las citas. Revisa tu conexión o sesión.';
      }
    });
  }

  private sincronizarDesdeCitas(citas: Cita[]): void {
    const clientes = new Map<number, ClienteBarbero>();
    const completadas = citas.filter(cita => cita.estado === 'Completada');
    for (const cita of citas) {
      const cliente = clientes.get((cita as any).cliente) || {
        id: (cita as any).cliente || 0,
        nombre: cita.cliente_nombre,
        email: '', telefono: '', total_citas: 0,
        ultimo_servicio: cita.servicio_nombre,
        ultima_fecha: cita.fecha
      };
      cliente.total_citas++;
      if (cita.fecha >= cliente.ultima_fecha) {
        cliente.ultimo_servicio = cita.servicio_nombre;
        cliente.ultima_fecha = cita.fecha;
      }
      clientes.set(cliente.id, cliente);
    }
    this.listaClientes = Array.from(clientes.values());
    this.historialCortes = completadas.map(cita => ({
      id: cita.id,
      cliente_nombre: cita.cliente_nombre,
      servicio_nombre: cita.servicio_nombre,
      precio: cita.servicio_precio,
      fecha: cita.fecha,
      hora: cita.hora.substring(0, 5),
      observaciones: ''
    }));
    const ingresosPorFecha = new Map<string, number>();
    for (const cita of completadas) {
      ingresosPorFecha.set(cita.fecha, (ingresosPorFecha.get(cita.fecha) || 0) + Number(cita.servicio_precio || 0));
    }
    this.ingresosDiarios = Array.from(ingresosPorFecha, ([fecha, total]) => ({ fecha, total }))
      .sort((a, b) => b.fecha.localeCompare(a.fecha));
    const ingresos = completadas.reduce((total, cita) => total + Number(cita.servicio_precio || 0), 0);
    this.dashboardResumen = {
      ...this.dashboardResumen,
      citas: citas.length,
      clientes: this.listaClientes.length,
      servicios: completadas.length,
      ingresos_total: ingresos,
      ingresos_semana: ingresos,
      ingresos_mes: ingresos
    };
  }

  cargarDashboard(): void {
    const actualizado = Date.now();
    this.http.get<any>(`${this.apiUrl}/barbero/dashboard/?actualizado=${actualizado}`, { headers: this.getHeaders() }).subscribe({
      next: (data) => {
        this.dashboardResumen = data.resumen;
        this.listaClientes = data.clientes;
        this.historialCortes = data.historial;
        this.ingresosDiarios = data.ingresos;
        this.cargandoDashboard = false;
        this.errorDashboard = '';
      },
      error: (err) => {
        console.error('Error dashboard:', err);
        this.cargandoDashboard = false;
        this.errorDashboard = 'No se pudo cargar el resumen. Mostrando los datos de tus citas.';
      }
    });
  }

  cambiarEstado(cita: Cita, estado: string): void {
    if (estado === 'Cancelada' && !confirm(`¿Quieres cancelar la cita de ${cita.cliente_nombre}?`)) {
      return;
    }
    this.http.patch(
      `${this.apiUrl}/citas/${cita.id}/`,
      { estado },
      { headers: this.getHeaders() }
    ).subscribe({
      next: () => {
        cita.estado = estado;
        this.mensaje = estado === 'Completada'
          ? 'Servicio completado. Dashboard actualizado.'
          : 'Estado de la cita actualizado.';
        this.cargarCitas();
        this.cargarDashboard();
        setTimeout(() => this.mensaje = '', 3000);
      },
      error: (err) => {
        console.error(err);
        this.mensaje = 'No se pudo actualizar el estado de la cita.';
      }
    });
  }

  formatMoneda(valor: number): string {
    return `$${valor.toLocaleString('es-CO', { maximumFractionDigits: 0 })}`;
  }

  get ingresosGrafica(): IngresoDiario[] {
    return [...this.ingresosDiarios].reverse().slice(-8);
  }

  get maxIngresoGrafica(): number {
    return Math.max(...this.ingresosGrafica.map(ingreso => ingreso.total), 1);
  }

  alturaBarraIngreso(total: number): number {
    return Math.max((total / this.maxIngresoGrafica) * 100, 5);
  }

  get puntosGrafica(): string {
    const ingresos = this.ingresosGrafica;
    if (!ingresos.length) return '';
    return ingresos.map((ingreso, index) => {
      const x = ingresos.length === 1 ? 50 : (index / (ingresos.length - 1)) * 100;
      const y = 100 - (ingreso.total / this.maxIngresoGrafica) * 82 - 8;
      return `${x},${y}`;
    }).join(' ');
  }

  get citasFiltradas(): Cita[] {
    const texto = this.filtroCitas.trim().toLowerCase();
    return this.listaCitas.filter(cita =>
      (!texto || `${cita.cliente_nombre} ${cita.servicio_nombre}`.toLowerCase().includes(texto)) &&
      (this.estadoCitas === 'Todas' || cita.estado === this.estadoCitas)
    );
  }

  get historialFiltrado(): HistorialCorte[] {
    const texto = this.filtroHistorial.trim().toLowerCase();
    return this.historialCortes.filter(corte =>
      (!texto || `${corte.cliente_nombre} ${corte.servicio_nombre}`.toLowerCase().includes(texto)) &&
      (!this.fechaHistorial || corte.fecha === this.fechaHistorial)
    );
  }

  limpiarFiltrosCitas(): void {
    this.filtroCitas = '';
    this.estadoCitas = 'Todas';
  }

  limpiarFiltrosHistorial(): void {
    this.filtroHistorial = '';
    this.fechaHistorial = '';
  }

  // ───────────── HORARIOS ─────────────

  cargarHorarios(): void {
    this.http.get<Disponibilidad[]>(`${this.apiUrl}/disponibilidad/`, {
      headers: this.getHeaders()
    }).subscribe({
      next: (data) => this.listaHorarios = data,
      error: (err) => console.error(err)
    });
  }

  guardarHorario(): void {
    if (this.horarioForm.hora_inicio >= this.horarioForm.hora_fin) {
      this.mensaje = 'La hora de cierre debe ser posterior a la hora de apertura.';
      return;
    }
    const duplicado = this.listaHorarios.some(h =>
      h.id !== this.horarioEditandoId &&
      h.dia_semana === this.horarioForm.dia_semana &&
      h.hora_inicio === this.horarioForm.hora_inicio &&
      h.hora_fin === this.horarioForm.hora_fin
    );
    if (duplicado) {
      this.mensaje = 'Ese horario ya está configurado.';
      return;
    }
    const peticion = this.horarioEditandoId === null
      ? this.http.post(`${this.apiUrl}/disponibilidad/`, this.horarioForm, { headers: this.getHeaders() })
      : this.http.patch(`${this.apiUrl}/disponibilidad/${this.horarioEditandoId}/`, this.horarioForm, { headers: this.getHeaders() });

    peticion.subscribe({
      next: () => {
        this.mensaje = this.horarioEditandoId === null
          ? 'Horario guardado correctamente.'
          : 'Horario actualizado correctamente.';
        this.cargarHorarios();
        this.cancelarEdicionHorario();

        setTimeout(() => this.mensaje = '', 3000);
      },
      error: (err) => console.error(err)
    });
  }

  editarHorario(horario: Disponibilidad): void {
    this.horarioEditandoId = horario.id || null;
    this.horarioForm = {
      dia_semana: horario.dia_semana,
      hora_inicio: horario.hora_inicio.substring(0, 5),
      hora_fin: horario.hora_fin.substring(0, 5)
    };
  }

  cancelarEdicionHorario(): void {
    this.horarioEditandoId = null;
    this.horarioForm = { dia_semana: 'Lunes', hora_inicio: '08:00', hora_fin: '17:00' };
  }

  eliminarHorario(id: number): void {
    if (!confirm('¿Eliminar este horario?')) return;

    this.http.delete(`${this.apiUrl}/disponibilidad/${id}/`, {
      headers: this.getHeaders()
    }).subscribe({
      next: () => {
        this.mensaje = 'Horario eliminado.';
        this.cargarHorarios();
      },
      error: (err) => console.error(err)
    });
  }

  // ───────────── PERFIL ─────────────

  cargarPerfil(): void {
  this.http.get<Perfil>(`${this.apiUrl}/perfil/barbero/`, {
    headers: this.getHeaders()
  }).subscribe({
    next: (data) => {
      this.perfil = data;
      console.log('🔍 DATA COMPLETA DEL PERFIL:', data);
      console.log('🔍 VALOR DE data.foto:', data.foto);
      this.fotoPreview = data.foto
  ? (data.foto.startsWith('http') ? data.foto : `http://localhost:8000${data.foto}`)
  : null;
      console.log('🔍 fotoPreview FINAL:', this.fotoPreview);
    },
    error: (err) => console.error(err)
  });
}
  onFotoSeleccionada(event: Event): void {
    const input = event.target as HTMLInputElement;

    if (input.files?.length) {
      this.fotoArchivo = input.files[0];

      const reader = new FileReader();

      reader.onload = (e) => {
        this.fotoPreview = e.target?.result as string;
      };

      reader.readAsDataURL(this.fotoArchivo);
    }
  }

 guardarPerfil(): void {
  const formData = new FormData();

  formData.append('descripcion', this.perfil.descripcion || '');
  formData.append('experiencia', String(this.perfil.experiencia || 0));
  formData.append('telefono', this.perfil.telefono || '');

  if (this.fotoArchivo) {
    formData.append('foto', this.fotoArchivo);
  }

  this.http.patch(
    `${this.apiUrl}/perfil/barbero/`,
    formData,
    { headers: this.getHeadersMultipart() }
  ).subscribe({
    next: () => {
      this.mensaje = 'Perfil actualizado correctamente.';
      this.fotoArchivo = null;
      this.cargarPerfil();
      setTimeout(() => this.mensaje = '', 3000);
    },
    error: (err) => {
      console.error('Error guardando perfil:', err);
      this.mensaje = `❌ Error al guardar: ${err.status} - ${JSON.stringify(err.error)}`;
    }
  });
}

  // ───────────── CHAT ─────────────

  // En barbero.ts actualiza el método iniciarChat() y enviarMensaje()
// También agrega scrollAbajo()

  iniciarChat(): void {
    this.barberoId = localStorage.getItem('user_id') || '';

    this.socket = new WebSocket(
      `ws://localhost:8000/ws/chat/${this.barberoId}/`
    );

    this.socket.onopen = () => {
      console.log('✅ Barbero conectado al chat sala:', this.barberoId);
    };

    this.socket.onmessage = (event) => {
      const data = JSON.parse(event.data);
      this.mensajes.push({
        usuario: data.usuario,
        mensaje: data.mensaje,
        propio: data.usuario === this.nombreUsuario
      });
      setTimeout(() => this.scrollAbajo(), 50);
    };

    this.socket.onerror = (err) => {
      console.error('WebSocket error:', err);
    };
  }

  enviarMensaje(): void {
    if (!this.mensajeTexto.trim()) return;
    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) return;

    this.socket.send(JSON.stringify({
      usuario: this.nombreUsuario,
      mensaje: this.mensajeTexto.trim()
    }));

    this.mensajeTexto = '';
  }

  scrollAbajo(): void {
    const el = document.getElementById('chatMensajes');
    if (el) el.scrollTop = el.scrollHeight;
  }
  logout(): void {
  localStorage.clear();
  this.router.navigate(['/login']);
}
}