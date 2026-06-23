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

  irAReservas() {
    this.router.navigate(['/reservas']); 
  }

  // 🔥 MODIFICADO: Ahora limpia el navegador antes de salir
  logout() {
    // 1. Eliminamos los tokens del localStorage
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');

    // 2. Redirigimos al login limpiecito
    this.router.navigate(['/login']);
  }
}