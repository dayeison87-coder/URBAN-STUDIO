import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { apiConfig } from '../config/api.config';

@Injectable({
  providedIn: 'root'
})
export class BarberosService {

  private http = inject(HttpClient);

  // Ahora consulta únicamente los usuarios con rol Barbero
  private apiUrl = `${apiConfig.apiUrl}/usuarios/barberos/`;

  private getHeaders(): HttpHeaders {
    const token = localStorage.getItem('access_token');

    return new HttpHeaders({
      Authorization: `Bearer ${token}`
    });
  }

  obtenerBarberos(): Observable<any[]> {
    return this.http.get<any[]>(this.apiUrl, {
      headers: this.getHeaders()
    });
  }

}
