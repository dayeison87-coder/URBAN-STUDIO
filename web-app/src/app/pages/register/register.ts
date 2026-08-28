import { Component, inject } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';

@Component({
  selector: 'app-register',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './register.html',
  styleUrl: './register.css'
})
export class RegisterComponent {

  username = '';
  email = '';
  telefono = '';
  password = '';
  mensaje = '';
  errorCorreo = '';
  errorTelefono = '';

  get passwordChecks() {
    return {
      minLength:  this.password.length >= 8,
      hasUpper:   /[A-Z]/.test(this.password),
      hasNumber:  /[0-9]/.test(this.password),
      hasSymbol:  /[!@#$%^&*(),.?":{}|<>_\-]/.test(this.password),
    };
  }

  get passwordValida(): boolean {
    const c = this.passwordChecks;
    return c.minLength && c.hasUpper && c.hasNumber && c.hasSymbol;
  }

    validarTelefono() {
    if (!/^[0-9]*$/.test(this.telefono)) {
      this.errorTelefono = 'El teléfono solo puede contener números.';
    } else if (this.telefono.length > 10) {
      this.errorTelefono = 'El teléfono debe tener máximo 10 números.';
    } else if (this.telefono.length > 0 && this.telefono.length < 10) {
      this.errorTelefono = 'El teléfono debe tener 10 números.';
    } else {
      this.errorTelefono = '';
    }
  }

  private http = inject(HttpClient);
  private router = inject(Router);

  registrar() {
    this.mensaje = '';
    this.errorCorreo = '';

    this.validarTelefono();

    if (this.errorTelefono) {
      return;
    }

    if (!this.passwordValida) {
      this.mensaje = 'La contraseña no cumple los requisitos de seguridad.';
      return;
    }

    this.http.post(
      'http://127.0.0.1:8000/api/register/',
      {
        username: this.username,
        email: this.email,
        telefono: this.telefono,
        password: this.password
      }
      
    ).subscribe({
      next: () => {
        this.mensaje = 'Cuenta creada correctamente';
        setTimeout(() => {
          this.router.navigate(['/login']);
        }, 1500);
      },
      error: (err) => {
        console.error('Error en el registro:', err);

        this.errorCorreo = '';

        if (err.error?.email) {
          this.errorCorreo = err.error.email[0];
        } else {
          this.mensaje = 'Error al crear la cuenta. Inténtalo de nuevo.';
        }
      }
    });
  }

  volverLogin() {
    this.router.navigate(['/login']);
  }
}