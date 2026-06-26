import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink
  ],
  templateUrl: './home.html',
  styleUrl: './home.css'
})
export class HomeComponent {

  private router = inject(Router);
  
  // Variable para pintar el nombre en el HTML
  nombreUsuario: string = 'Usuario';

  constructor() {
    // Traemos el string que guardaste en el login
    const usuarioGuardado = localStorage.getItem('username'); 
    
    if (usuarioGuardado) {
      this.nombreUsuario = usuarioGuardado;
    }
  }

  irAReservas() {
    this.router.navigate(['/reservas']); 
  }

  // 🔥 MODIFICADO: Ahora limpia el navegador antes de salir
  logout() {
    // 1. Eliminamos los tokens y los datos del usuario del localStorage
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('username'); // Limpiamos también el nombre al salir

    // 2. Redirigimos al login limpiecito
    this.router.navigate(['/login']);
  }

  // 🔥 AQUÍ ESTÁ LA SOLUCIÓN: Declarar exactamente la función que pusiste en el HTML
  irACitas() {
    this.router.navigate(['/citas']);
  }
}