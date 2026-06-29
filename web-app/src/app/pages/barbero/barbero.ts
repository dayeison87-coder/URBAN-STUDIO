import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Router } from '@angular/router';

// Interfaces
interface Cita {
  id: number;
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


@Component({
  selector: 'app-barbero',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './barbero.html',
  styleUrl: './barbero.css'
})
export class BarberoComponent implements OnInit {
  private http = inject(HttpClient);
  private router = inject(Router);

  nombreUsuario = '';

  // ✅ Ahora incluye la pestaña chat
  pestanaActiva: 'citas' | 'horarios' | 'perfil' | 'chat' = 'citas';

  mensaje = '';

  listaCitas: Cita[] = [];
  listaHorarios: Disponibilidad[] = [];

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
    this.cargarHorarios();
    this.cargarPerfil();
    this.iniciarChat();
  }

  // ✅ También acepta "chat"
  cambiarPestana(p: 'citas' | 'horarios' | 'perfil' | 'chat'): void {
    this.pestanaActiva = p;
    this.mensaje = '';
  }

  // ───────────── CITAS ─────────────

  cargarCitas(): void {
    this.http.get<Cita[]>(`${this.apiUrl}/citas/`, {
      headers: this.getHeaders()
    }).subscribe({
      next: (data) => this.listaCitas = data,
      error: (err) => console.error('Error citas:', err)
    });
  }

  cambiarEstado(cita: Cita, estado: string): void {
    this.http.patch(
      `${this.apiUrl}/citas/${cita.id}/`,
      { estado },
      { headers: this.getHeaders() }
    ).subscribe({
      next: () => cita.estado = estado,
      error: (err) => console.error(err)
    });
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
    this.http.post(
      `${this.apiUrl}/disponibilidad/`,
      this.horarioForm,
      { headers: this.getHeaders() }
    ).subscribe({
      next: () => {
        this.mensaje = 'Horario guardado correctamente.';
        this.cargarHorarios();

        this.horarioForm = {
          dia_semana: 'Lunes',
          hora_inicio: '08:00',
          hora_fin: '17:00'
        };

        setTimeout(() => this.mensaje = '', 3000);
      },
      error: (err) => console.error(err)
    });
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
        this.fotoPreview = data.foto
          ? `http://localhost:8000${data.foto}`
          : null;
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
        setTimeout(() => this.mensaje = '', 3000);
      },
      error: (err) => console.error(err)
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