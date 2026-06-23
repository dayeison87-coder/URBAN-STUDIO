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
  // Verificar que los campos no estén vacíos
if (!this.username.trim() || !this.password.trim()) {
  this.mensaje = 'Todos los campos son obligatorios.';
  return;
}

    // Cambia esta URL por la de tu endpoint real de login en Django (ej. /api/token/ o /api/login/)
    this.http.post<any>(
      'http://127.0.0.1:8000/api/login/', 
      {
        username: this.username,
        password: this.password
      }
    ).subscribe({
      next: (response) => {
        this.mensaje = 'Acceso correcto. Entrando...';

        // Opcional: Si tu backend devuelve un token JWT, lo guardas así:
        // if (response.token) {
        //   localStorage.setItem('token', response.token);
        // }

        // Esperamos un segundo para que el usuario experimente la transición visual
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