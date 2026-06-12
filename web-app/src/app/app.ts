import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';

@Component({
  selector: 'app-root',
  imports: [
    CommonModule,
    FormsModule
  ],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class App {

  username = '';
  password = '';
  mensaje = '';

  estaLogueado = false;

  private http = inject(HttpClient);

  constructor() {

    // Si existe un token, ingresar directamente al Home
    this.estaLogueado =
      !!localStorage.getItem('access');

    // Detectar cuando el usuario usa el botón Atrás
    window.addEventListener(
      'popstate',
      () => {

        if (
          !localStorage.getItem('access')
        ) {

          this.estaLogueado = false;

        }

      }
    );

  }

  login() {

    this.mensaje = '';

    this.http.post(
      'http://127.0.0.1:8000/api/login/',
      {
        username: this.username,
        password: this.password
      }
    ).subscribe({

      next: (response: any) => {

        // Guardar los tokens
        localStorage.setItem(
          'access',
          response.access
        );

        localStorage.setItem(
          'refresh',
          response.refresh
        );

        // Mostrar Home
        this.estaLogueado = true;

        // Mensaje profesional
        this.mensaje =
          `¡Bienvenido, ${this.username}!`;

        // Evitar volver al Login con el botón Atrás
        window.history.pushState(
          null,
          '',
          window.location.href
        );

      },

      error: () => {

        this.mensaje =
          'Usuario o contraseña incorrectos';

      }

    });

  }

  logout() {

    // Eliminar completamente la sesión
    localStorage.clear();

    // Mostrar nuevamente el Login
    this.estaLogueado = false;

    // Limpiar formulario
    this.username = '';

    this.password = '';

    this.mensaje = '';

    // Evitar volver al Home con el botón Atrás
    window.history.pushState(
      null,
      '',
      window.location.href
    );

  }

}