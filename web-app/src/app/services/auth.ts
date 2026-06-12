import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Injectable({
  providedIn: 'root'
})
export class AuthService {

  private http = inject(HttpClient);

  private apiUrl = 'http://127.0.0.1:8000/api';

  login(data: any) {
    return this.http.post(
      `${this.apiUrl}/login/`,
      data
    );
  }

  register(data: any) {
    return this.http.post(
      `${this.apiUrl}/register/`,
      data
    );
  }
}