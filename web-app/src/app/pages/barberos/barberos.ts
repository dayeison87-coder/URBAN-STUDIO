import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { BarberosService } from '../../services/barberos';

@Component({
  selector: 'app-barberos',
  standalone: true,
  imports: [
    CommonModule,
    RouterLink
  ],
  templateUrl: './barberos.html',
  styleUrl: './barberos.css'
})
export class Barberos implements OnInit {

  private barberosService = inject(BarberosService);
  private router = inject(Router);

  barberos: any[] = [];

  // Para mostrar el nombre en el navbar
  nombreUsuario: string = 'Usuario';

  constructor() {
    const usuarioGuardado = localStorage.getItem('username');

    if (usuarioGuardado) {
      this.nombreUsuario = usuarioGuardado;
    }
  }

  ngOnInit(): void {
    this.cargarBarberos();
  }

  cargarBarberos() {
    this.barberosService.obtenerBarberos().subscribe({
      next: (data) => {
        console.log(data);
        this.barberos = data;
      },
      error: (err) => {
        console.error(err);
      }
    });
  }

  // Cuando el usuario pulse "Agendar cita"
  irACitas() {
    this.router.navigate(['/citas']);
  }

  // Cerrar sesión
  logout() {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('username');

    this.router.navigate(['/login']);
  }
}