import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { apiConfig } from '../config/api.config';

@Injectable({
  providedIn: 'root'
})
export class GeminiService {

  private apiUrl = `${apiConfig.apiUrl}/servicios/analizar-rostro/`;
  private solicitarCodigoUrl = `${apiConfig.apiUrl}/solicitar-codigo-ia/`;
  private validarCodigoUrl = `${apiConfig.apiUrl}/validar-codigo-ia/`;
  private barberosUrl = `${apiConfig.apiUrl}/usuarios/barberos/`;

  constructor(private http: HttpClient) {}

  // Analizar rostro
  analizarRostro(imagenFile: File): Observable<any> {
    const formData = new FormData();

    // El backend espera el campo "foto"
    formData.append('foto', imagenFile, imagenFile.name);

    const token = localStorage.getItem('access_token');

    const headers = new HttpHeaders({
      Authorization: `Bearer ${token}`,
    });

    return this.http.post<any>(
      this.apiUrl,
      formData,
      { headers }
    );
  }

  // Solicitar código para utilizar la IA
  obtenerBarberos(): Observable<any[]> {
    const token = localStorage.getItem('access_token');
    const headers = new HttpHeaders({ Authorization: `Bearer ${token}` });
    return this.http.get<any[]>(this.barberosUrl, { headers });
  }

  solicitarCodigoIA(barberoId: number): Observable<any> {
    const token = localStorage.getItem('access_token');

    const headers = new HttpHeaders({
      Authorization: `Bearer ${token}`,
    });

    return this.http.post<any>(
      this.solicitarCodigoUrl,
      { barbero_id: barberoId },
      { headers }
    );
  }

  // Validar código de seguridad
  validarCodigoIA(codigo: string, barberoId: number): Observable<any> {
    const token = localStorage.getItem('access_token');

    const headers = new HttpHeaders({
      Authorization: `Bearer ${token}`,
    });

    return this.http.post<any>(
      this.validarCodigoUrl,
      { codigo, barbero_id: barberoId },
      { headers }
    );
  }
}
