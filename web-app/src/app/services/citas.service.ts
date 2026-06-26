import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class CitasService {
  private http = inject(HttpClient);
  private apiUrl = 'http://localhost:8000/api/citas/';

  // 🔐 Función privada para generar las cabeceras con el Token JWT de Django
  private getHeaders(): HttpHeaders {
    const token = localStorage.getItem('access_token');
    return new HttpHeaders({
      'Content-Type': 'application/json',
      // Adjuntamos el token usando el formato estándar Bearer que espera SimpleJWT
      'Authorization': token ? `Bearer ${token}` : ''
    });
  }

  obtenerCitas(): Observable<any[]> {
    return this.http.get<any[]>(this.apiUrl, { headers: this.getHeaders() });
  }

  crearCita(cita: any): Observable<any> {
    return this.http.post<any>(this.apiUrl, cita, { headers: this.getHeaders() });
  }

  editarCita(id: number, cita: any): Observable<any> {
    return this.http.put<any>(`${this.apiUrl}${id}/`, cita, { headers: this.getHeaders() });
  }

  eliminarCita(id: number): Observable<any> {
    return this.http.delete<any>(`${this.apiUrl}${id}/`, { headers: this.getHeaders() });
  }
}