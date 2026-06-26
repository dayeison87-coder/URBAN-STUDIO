import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, tap } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  // URL de tu API de Django (recuerda levantar el servidor en el puerto 8000)
  private apiUrl = 'http://localhost:8000/api';

  constructor(private http: HttpClient) {}

  // 1. Método para Iniciar Sesión (Login)
  login(credentials: { username: string; password: string }): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/login/`, credentials).pipe(
      tap(res => {
        if (res.access && res.refresh) {
          localStorage.setItem('access_token', res.access);
          localStorage.setItem('refresh_token', res.refresh);
        }
      })
    );
  }

  // 2. Método para Registrar Clientes (Por si crean la vista en register.ts)
  register(userData: any): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/register/`, userData);
  }

  // 3. Cerrar sesión
  logout() {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
  }

  // 4. Saber si está logueado
  isLoggedIn(): boolean {
    return !!localStorage.getItem('access_token');
  }

  // Agrega esto dentro de tu clase AuthService en auth.ts
obtenerUsuarioActual() {
  const user = localStorage.getItem('user'); // O como hayas guardado el objeto al loguearte
  return user ? JSON.parse(user) : null;
}
}