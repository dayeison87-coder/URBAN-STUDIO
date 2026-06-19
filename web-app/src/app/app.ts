import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router'; // 1. Importas esto

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [
    RouterOutlet // 2. Lo agregas aquí
  ],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class AppComponent {
  title = 'web-app';
}