import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class GeminiService {
  // Ajusta la URL base según corresponda a tu API de Django
  private apiUrl = 'http://localhost:8000/api/servicios/analizar-rostro/';

  constructor(private http: HttpClient) {}

  analizarRostro(imagenFile: File): Observable<any> {
    const formData = new FormData();
    // OJO: el backend espera el campo "foto", no "imagen"
    formData.append('foto', imagenFile, imagenFile.name);

    const token = localStorage.getItem('access_token');
    const headers = new HttpHeaders({
      Authorization: `Bearer ${token}`,
    });

    return this.http.post<any>(this.apiUrl, formData, { headers });
  }
}