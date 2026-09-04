import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Router } from '@angular/router';

@Component({
  selector: 'app-configuracion-cuenta',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './configuracion-cuenta.html',
  styleUrl: './configuracion-cuenta.css'
})
export class ConfiguracionCuentaComponent {
  private http = inject(HttpClient);
  private router = inject(Router);
  private apiUrl = 'http://localhost:8000/api';
  passwordActual = '';
  passwordNueva = '';
  passwordConfirmacion = '';
  mostrarActual = false;
  mostrarNueva = false;
  mostrarConfirmacion = false;
  notificaciones = true;
  recordatorios = true;
  perfilVisible = true;
  mensaje = '';
  error = '';
  guardando = false;

  constructor() {
    this.notificaciones = localStorage.getItem('preferencias_notificaciones') !== 'false';
    this.recordatorios = localStorage.getItem('preferencias_recordatorios') !== 'false';
    this.perfilVisible = localStorage.getItem('preferencias_perfil_visible') !== 'false';
  }

  private headers(): HttpHeaders {
    return new HttpHeaders({ Authorization: `Bearer ${localStorage.getItem('access_token') || ''}` });
  }

  guardarPreferencias(): void {
    localStorage.setItem('preferencias_notificaciones', String(this.notificaciones));
    localStorage.setItem('preferencias_recordatorios', String(this.recordatorios));
    localStorage.setItem('preferencias_perfil_visible', String(this.perfilVisible));
    this.mensaje = 'Preferencias guardadas correctamente.';
    setTimeout(() => this.mensaje = '', 3000);
  }

  cambiarPassword(): void {
    this.mensaje = '';
    this.error = '';
    if (!this.passwordActual || !this.passwordNueva || !this.passwordConfirmacion) {
      this.error = 'Completa los tres campos de contraseña.';
      return;
    }
    if (this.passwordNueva !== this.passwordConfirmacion) {
      this.error = 'La nueva contraseña y su confirmación no coinciden.';
      return;
    }
    if (this.passwordNueva.length < 8) {
      this.error = 'La nueva contraseña debe tener mínimo 8 caracteres.';
      return;
    }
    this.guardando = true;
    this.http.patch(`${this.apiUrl}/configuracion/cuenta/`, {
      password_actual: this.passwordActual,
      password_nueva: this.passwordNueva
    }, { headers: this.headers() }).subscribe({
      next: () => {
        this.passwordActual = '';
        this.passwordNueva = '';
        this.passwordConfirmacion = '';
        this.mensaje = 'Contraseña actualizada correctamente.';
        this.guardando = false;
      },
      error: err => {
        this.error = err.error?.password_actual?.[0] || 'No se pudo actualizar la contraseña.';
        this.guardando = false;
      }
    });
  }

  cerrarSesion(): void {
    localStorage.clear();
    this.router.navigate(['/login']);
  }

  volver(): void { this.router.navigate(['/home']); }
}
