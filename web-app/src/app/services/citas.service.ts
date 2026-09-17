import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { apiConfig } from '../config/api.config';

@Injectable({
  providedIn: 'root'
})
export class CitasService {
  private http = inject(HttpClient);
  
  // Endpoints del backend sincronizados con Django
  private apiUrlCitas = `${apiConfig.apiUrl}/citas/`;
  private apiUrlServicios = `${apiConfig.apiUrl}/categorias/`;
  private apiUrlBarberos = `${apiConfig.apiUrl}/usuarios/barberos/`;

  private getHeaders(): HttpHeaders {
    const token = localStorage.getItem('access_token') || 
                  localStorage.getItem('token') || 
                  localStorage.getItem('access');

    return new HttpHeaders({
      'Content-Type': 'application/json',
      'Authorization': token ? `Bearer ${token}` : ''
    });
  }

  // --- MÉTODOS DE SERVICIOS ---
  obtenerServicios(): Observable<any[]> {
    return this.http.get<any[]>(this.apiUrlServicios, { headers: this.getHeaders() });
  }

  // --- MÉTODOS DE BARBEROS ---
  obtenerUsuarios(): Observable<any[]> { 
    // Ahora apunta directo al filtro exclusivo de barberos que creamos en views.py
    return this.http.get<any[]>(this.apiUrlBarberos, { headers: this.getHeaders() });
  }

  // --- MÉTODOS DE CITAS ---
  obtenerCitas(): Observable<any[]> {
    return this.http.get<any[]>(this.apiUrlCitas, { headers: this.getHeaders() });
  }

  crearCita(cita: any): Observable<any> {
    return this.http.post<any>(this.apiUrlCitas, cita, { headers: this.getHeaders() });
  }

  editarCita(id: number, cita: any): Observable<any> {
    return this.http.put<any>(`${this.apiUrlCitas}${id}/`, cita, { headers: this.getHeaders() });
  }

  eliminarCita(id: number): Observable<any> {
    return this.http.delete<any>(`${this.apiUrlCitas}${id}/`, { headers: this.getHeaders() });
  }
}
