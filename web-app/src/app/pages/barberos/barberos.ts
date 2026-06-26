import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { BarberosService } from '../../services/barberos';

@Component({
  selector: 'app-barberos',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './barberos.html',
  styleUrl: './barberos.css'
})
export class Barberos implements OnInit {

  private barberosService = inject(BarberosService);

  barberos: any[] = [];

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

}