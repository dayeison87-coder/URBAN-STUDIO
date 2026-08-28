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
  codigo = '';
  pasoVerificacion = false;
  enviando = false;

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

    this.enviando = true;
    this.http.post(
      'http://127.0.0.1:8000/api/register/request-code/',
      {
        username: this.username,
        email: this.email,
        telefono: this.telefono,
        password: this.password
      }
      
    ).subscribe({
      next: () => {
        this.pasoVerificacion = true;
        this.enviando = false;
        this.mensaje = 'Te enviamos un código de 4 dígitos a tu correo.';
      },
      error: (err) => {
        console.error('Error en el registro:', err);

        this.errorCorreo = '';

        if (err.error?.email) {
          this.errorCorreo = err.error.email[0];
        } else {
          this.mensaje = err.error?.detail || 'No se pudo enviar el código. Inténtalo de nuevo.';
        }
        this.enviando = false;
      }
    });
  }

  verificarCodigo() {
    if (!/^\d{4}$/.test(this.codigo)) {
      this.mensaje = 'Escribe un código válido de 4 dígitos.';
      return;
    }
    this.enviando = true;
    this.http.post('http://127.0.0.1:8000/api/register/verify/', { email: this.email, codigo: this.codigo }).subscribe({
      next: () => {
        this.mensaje = 'Cuenta creada correctamente.';
        this.enviando = false;
        setTimeout(() => this.router.navigate(['/login']), 1200);
      },
      error: err => {
        this.mensaje = err.error?.detail || 'Código incorrecto.';
        this.enviando = false;
      }
    });
  }

  volverDatos() {
    this.pasoVerificacion = false;
    this.codigo = '';
    this.mensaje = '';
  }

  accesoSocial(proveedor: string) {
    if (proveedor === 'Google') {
      window.location.href = 'http://localhost:8000/api/auth/google/';
      return;
    }
    this.mensaje = 'El acceso con Facebook necesita configurar sus credenciales OAuth.';
  }

  volverLogin() {
    this.router.navigate(['/login']);
  }
}