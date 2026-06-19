import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';

@Component({
  selector: 'app-register',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule
  ],
  templateUrl: './register.html',
  styleUrl: './register.css'
})
export class RegisterComponent {

  username = '';
  email = '';
  password = '';
  mensaje = '';

  private http = inject(HttpClient);
  private router = inject(Router);

  registrar() {
    // Limpiamos el mensaje al iniciar un nuevo intento de registro
    this.mensaje = '';

    this.http.post(
      'http://127.0.0.1:8000/api/register/',
      {
        username: this.username,
        email: this.email,
        password: this.password
      }
    ).subscribe({
      next: () => {
        // Asignamos el mensaje de éxito (el CSS detectará la palabra 'correctamente' para ponerse verde)
        this.mensaje = 'Cuenta creada correctamente';

        // Retardamos un segundo la redirección para que el usuario alcance a ver la alerta verde
        setTimeout(() => {
          this.router.navigate(['/login']);
        }, 1500);
      },
      error: (err) => {
        console.error('Error en el registro:', err);
        
        this.mensaje = 'Error al crear la cuenta. Inténtalo de nuevo.';
      }
    });
  }

  volverLogin() {
    this.router.navigate(['/login']);
  }
}