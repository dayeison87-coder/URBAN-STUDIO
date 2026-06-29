import { Component, inject, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';

interface Mensaje {
  usuario: string;
  mensaje: string;
  propio: boolean;
}

interface Barbero {
  id: number;
  username: string;
  email: string;
}

@Component({
  selector: 'app-chat',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './chat.html',
  styleUrl: './chat.css'
})
export class ChatComponent implements OnInit, OnDestroy {
  private http = inject(HttpClient);
  private apiUrl = 'http://localhost:8000/api';

  nombreUsuario = '';
  barberos: Barbero[] = [];
  barberoActivo: Barbero | null = null;
  mensajes: Mensaje[] = [];
  mensajeTexto = '';
  conectado = false;
  private socket!: WebSocket;

  private getHeaders(): HttpHeaders {
    const token = localStorage.getItem('access_token') || '';
    return new HttpHeaders({ 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` });
  }

  ngOnInit(): void {
    this.nombreUsuario = localStorage.getItem('username') || 'Cliente';
    this.cargarBarberos();
  }

  ngOnDestroy(): void {
    this.desconectar();
  }

  cargarBarberos(): void {
    this.http.get<Barbero[]>(`${this.apiUrl}/usuarios/barberos/`, { headers: this.getHeaders() }).subscribe({
      next: (data) => this.barberos = data,
      error: (err) => console.error(err)
    });
  }

  seleccionarBarbero(barbero: Barbero): void {
    if (this.barberoActivo?.id === barbero.id) return;
    this.desconectar();
    this.barberoActivo = barbero;
    this.mensajes = [];
    this.conectarChat(barbero.id);
  }

  conectarChat(barberoId: number): void {
    this.socket = new WebSocket(`ws://localhost:8000/ws/chat/${barberoId}/`);

    this.socket.onopen = () => {
      this.conectado = true;
    };

    this.socket.onmessage = (event) => {
      const data = JSON.parse(event.data);
      this.mensajes.push({
        usuario: data.usuario,
        mensaje: data.mensaje,
        propio:  data.usuario === this.nombreUsuario
      });
      setTimeout(() => this.scrollAbajo(), 50);
    };

    this.socket.onclose = () => {
      this.conectado = false;
    };

    this.socket.onerror = (err) => {
      console.error('WebSocket error:', err);
      this.conectado = false;
    };
  }

  enviarMensaje(): void {
    if (!this.mensajeTexto.trim() || !this.socket || this.socket.readyState !== WebSocket.OPEN) return;

    this.socket.send(JSON.stringify({
      usuario: this.nombreUsuario,
      mensaje: this.mensajeTexto.trim()
    }));

    this.mensajeTexto = '';
  }

  desconectar(): void {
    if (this.socket) {
      this.socket.close();
      this.conectado = false;
    }
  }

  scrollAbajo(): void {
    const el = document.getElementById('chatMensajes');
    if (el) el.scrollTop = el.scrollHeight;
  }

  getInicial(nombre: string): string { return nombre.charAt(0).toUpperCase(); }
}