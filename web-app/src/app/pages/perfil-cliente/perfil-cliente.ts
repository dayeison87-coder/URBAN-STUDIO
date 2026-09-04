import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Router } from '@angular/router';

interface PerfilCliente {
  id: number;
  username: string;
  email: string;
  telefono: string;
  foto: string | null;
}

@Component({
  selector: 'app-perfil-cliente',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './perfil-cliente.html',
  styleUrl: './perfil-cliente.css'
})
export class PerfilClienteComponent implements OnInit {
  private http = inject(HttpClient);
  private router = inject(Router);
  private apiUrl = 'http://localhost:8000/api';
  perfil: PerfilCliente = { id: 0, username: '', email: '', telefono: '', foto: null };
  fotoArchivo: File | null = null;
  fotoPreview: string | null = null;
  mensaje = '';
  error = '';
  guardando = false;

  private headers(): HttpHeaders {
    const token = localStorage.getItem('access_token') || '';
    return new HttpHeaders({ Authorization: `Bearer ${token}` });
  }

  ngOnInit(): void { this.cargarPerfil(); }

  cargarPerfil(): void {
    this.http.get<PerfilCliente>(`${this.apiUrl}/perfil/cliente/`, { headers: this.headers() }).subscribe({
      next: perfil => {
        this.perfil = perfil;
        localStorage.setItem('username', perfil.username);
        this.fotoPreview = perfil.foto ? (perfil.foto.startsWith('http') ? perfil.foto : `http://localhost:8000${perfil.foto}`) : null;
      },
      error: () => this.error = 'No se pudo cargar tu perfil.'
    });
  }

  seleccionarFoto(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (!input.files?.length) return;
    this.fotoArchivo = input.files[0];
    const reader = new FileReader();
    reader.onload = () => this.fotoPreview = reader.result as string;
    reader.readAsDataURL(this.fotoArchivo);
  }

  guardarPerfil(): void {
    this.mensaje = '';
    this.error = '';
    const datos = new FormData();
    datos.append('username', this.perfil.username);
    datos.append('email', this.perfil.email);
    datos.append('telefono', this.perfil.telefono || '');
    if (this.fotoArchivo) datos.append('foto', this.fotoArchivo);
    this.guardando = true;
    this.http.patch<PerfilCliente>(`${this.apiUrl}/perfil/cliente/`, datos, { headers: this.headers() }).subscribe({
      next: perfil => {
        this.perfil = perfil;
        localStorage.setItem('username', perfil.username);
        this.fotoArchivo = null;
        this.mensaje = 'Perfil actualizado correctamente.';
        this.guardando = false;
      },
      error: () => { this.error = 'No se pudo actualizar el perfil.'; this.guardando = false; }
    });
  }

  volver(): void { this.router.navigate(['/home']); }
}
