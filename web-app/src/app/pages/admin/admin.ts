import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { HttpClient, HttpHeaders } from '@angular/common/http';

@Component({
  selector: 'app-admin',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './admin.html',
  styleUrl: './admin.css'
})
export class AdminComponent implements OnInit {
  private http = inject(HttpClient);
  private router = inject(Router);

  pestanaActiva: 'servicios' | 'barberos' = 'servicios';
  nombreUsuario: string = 'Admin';
  mensaje: string = '';

  listaServicios: any[] = [];
  servicioForm = { id: null as number | null, nombre: '', descripcion: '', precio: '', duracion: '' };
  editandoServicio = false;

  listaBarberos: any[] = [];
  barberoForm = { id: null as number | null, username: '', email: '', telefono: '' };
  editandoBarbero = false;

  private apiUrl = 'http://localhost:8000/api';

  private getHeaders(): HttpHeaders {
    const token = localStorage.getItem('access_token');
    return new HttpHeaders({
      'Content-Type': 'application/json',
      'Authorization': token ? `Bearer ${token}` : ''
    });
  }

  ngOnInit(): void {
    this.nombreUsuario = localStorage.getItem('username') || 'Admin';
    this.cargarServicios();
    this.cargarBarberos();
  }

  cambiarPestana(p: 'servicios' | 'barberos') {
    this.pestanaActiva = p;
    this.mensaje = '';
  }

  cargarServicios(): void {
    this.http.get<any[]>(`${this.apiUrl}/servicios/`, { headers: this.getHeaders() }).subscribe({
      next: (data) => this.listaServicios = data,
      error: (err) => console.error('Error servicios:', err)
    });
  }

  guardarServicio(): void {
    if (!this.servicioForm.nombre || !this.servicioForm.precio || !this.servicioForm.duracion) {
      this.mensaje = 'Completa todos los campos del servicio.';
      return;
    }
    const payload = {
      nombre: this.servicioForm.nombre,
      descripcion: this.servicioForm.descripcion,
      precio: Number(this.servicioForm.precio),
      duracion: Number(this.servicioForm.duracion)
    };
    if (this.editandoServicio && this.servicioForm.id) {
      this.http.put(`${this.apiUrl}/servicios/${this.servicioForm.id}/`, payload, { headers: this.getHeaders() }).subscribe({
        next: () => { this.mensaje = 'Servicio actualizado.'; this.limpiarServicio(); this.cargarServicios(); },
        error: (err) => console.error(err)
      });
    } else {
      this.http.post(`${this.apiUrl}/servicios/`, payload, { headers: this.getHeaders() }).subscribe({
        next: () => { this.mensaje = 'Servicio creado.'; this.limpiarServicio(); this.cargarServicios(); },
        error: (err) => console.error(err)
      });
    }
  }

  editarServicio(s: any): void {
    this.editandoServicio = true;
    this.servicioForm = { id: s.id, nombre: s.nombre, descripcion: s.descripcion, precio: s.precio, duracion: s.duracion };
  }

  eliminarServicio(id: number): void {
    if (confirm('¿Eliminar este servicio?')) {
      this.http.delete(`${this.apiUrl}/servicios/${id}/`, { headers: this.getHeaders() }).subscribe({
        next: () => { this.mensaje = 'Servicio eliminado.'; this.cargarServicios(); },
        error: (err) => console.error(err)
      });
    }
  }

  limpiarServicio(): void {
    this.editandoServicio = false;
    this.servicioForm = { id: null, nombre: '', descripcion: '', precio: '', duracion: '' };
    setTimeout(() => this.mensaje = '', 3000);
  }

  cargarBarberos(): void {
    this.http.get<any[]>(`${this.apiUrl}/usuarios/`, { headers: this.getHeaders() }).subscribe({
      next: (data) => this.listaBarberos = data,
      error: (err) => console.error('Error barberos:', err)
    });
  }

  guardarBarbero(): void {
    if (!this.barberoForm.username || !this.barberoForm.email) {
      this.mensaje = 'Completa nombre y email del barbero.';
      return;
    }
    const payload = {
      username: this.barberoForm.username,
      email: this.barberoForm.email,
      telefono: this.barberoForm.telefono
    };
    if (this.editandoBarbero && this.barberoForm.id) {
      this.http.put(`${this.apiUrl}/usuarios/${this.barberoForm.id}/`, payload, { headers: this.getHeaders() }).subscribe({
        next: () => { this.mensaje = 'Barbero actualizado.'; this.limpiarBarbero(); this.cargarBarberos(); },
        error: (err) => console.error(err)
      });
    } else {
      this.mensaje = 'Para crear barberos usa el panel de Django Admin.';
    }
  }

  editarBarbero(b: any): void {
    this.editandoBarbero = true;
    this.barberoForm = { id: b.id, username: b.username, email: b.email, telefono: b.telefono || '' };
  }

  eliminarBarbero(id: number): void {
    if (confirm('¿Eliminar este barbero?')) {
      this.http.delete(`${this.apiUrl}/usuarios/${id}/`, { headers: this.getHeaders() }).subscribe({
        next: () => { this.mensaje = 'Barbero eliminado.'; this.cargarBarberos(); },
        error: (err) => console.error(err)
      });
    }
  }

  limpiarBarbero(): void {
    this.editandoBarbero = false;
    this.barberoForm = { id: null, username: '', email: '', telefono: '' };
    setTimeout(() => this.mensaje = '', 3000);
  }

  logout(): void {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('username');
    this.router.navigate(['/login']);
  }
}