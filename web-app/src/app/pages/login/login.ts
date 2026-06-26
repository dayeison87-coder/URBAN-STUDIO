import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule
  ],
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

    
    
    if (!this.username || !this.password) {
      this.mensaje = 'Debes completar todos los campos.';
      return;
    }
    
    if (!this.username.trim() || !this.password.trim()) {
      this.mensaje = 'Todos los campos son obligatorios.';
      return;
    }

    // Petición POST al backend de Django
    this.http.post<any>(
      'http://127.0.0.1:8000/api/login/', 
      {
        username: this.username,
        password: this.password
      }
    ).subscribe({
      next: (response) => {
        this.mensaje = 'Acceso correcto. Entrando...';

        // 🔥 MODIFICACIÓN CLAVE: Guardar los tokens reales de Django SimpleJWT
        if (response.access && response.refresh) {
          localStorage.setItem('access_token', response.access);
          localStorage.setItem('refresh_token', response.refresh);
        }

        localStorage.setItem('username', this.username);

        setTimeout(() => {
          this.router.navigate(['/home']);
        }, 1000);
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