import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Router } from '@angular/router';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './login.html',
  styleUrl: './login.css'
})
export class LoginComponent {
  username = '';
  password = '';
  mensaje = '';

  private http = inject(HttpClient);
  private router = inject(Router);

  login() {
    this.mensaje = '';

    if (!this.username.trim() || !this.password.trim()) {
      this.mensaje = 'Debes completar todos los campos.';
      return;
    }

    this.http.post<any>('http://127.0.0.1:8000/api/login/', {
      username: this.username,
      password: this.password
    }).subscribe({
      next: (response) => {

        // Guardar tokens
        localStorage.setItem('access_token', response.access);
        localStorage.setItem('refresh_token', response.refresh);
        localStorage.setItem('username', this.username);

        // Crear headers con el token
        const headers = new HttpHeaders({
          Authorization: `Bearer ${response.access}`
        });

        // Obtener el perfil del usuario
        this.http.get<any>('http://127.0.0.1:8000/api/perfil/', { headers }).subscribe({

          next: (perfil) => {

            // Guardar datos del usuario
            localStorage.setItem('user_id', String(perfil.id));

            const rol = perfil.rol?.nombre || '';
            localStorage.setItem('rol', rol);

            this.mensaje = 'Acceso correcto. Entrando...';

            setTimeout(() => {

              if (rol === 'Admin') {
                this.router.navigate(['/admin']);

              } else if (rol === 'Barbero') {
                this.router.navigate(['/barbero']);

              } else {
                this.router.navigate(['/home']);
              }

            }, 1000);
          },

          error: (err) => {
            console.error('Error obteniendo perfil:', err);
            this.router.navigate(['/home']);
          }

        });

      },

      error: (err) => {
        console.error('Error en el login:', err);
        this.mensaje = 'Usuario o contraseña incorrectos.';
      }

    });
  }

  irRegistro() {
    this.router.navigate(['/register']);
  }
}