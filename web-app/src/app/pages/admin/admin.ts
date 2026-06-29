// admin.ts

import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { HttpClient, HttpHeaders } from '@angular/common/http';

interface Categoria {
  id: number;
  slug: string;
  nombre: string;
}

interface Servicio {
  id: number;
  nombre: string;
  descripcion: string;
  precio: string;
  disponible: boolean;
  categoria: number;
}

interface Barbero {
  id: number;
  username: string;
  email: string;
  telefono?: string;
  rol?: string;
}

@Component({
  selector: 'app-admin',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './admin.html',
  styleUrl: './admin.css'
})
export class AdminComponent implements OnInit {
  private http   = inject(HttpClient);
  private router = inject(Router);

  pestanaActiva: 'servicios' | 'barberos' = 'servicios';
  nombreUsuario = 'Admin';
  mensaje       = '';

  // Categorías
  categorias: Categoria[]    = [];
  categoriaSeleccionada      = '';

  // Servicios
  listaServicios: Servicio[] = [];
  serviciosFiltrados: Servicio[] = [];
  servicioForm = {
    id:          null as number | null,
    nombre:      '',
    descripcion: '',
    precio:      '',
    disponible:  true,
    categoria:   '' as string | number,
  };
  editandoServicio = false;

  // Barberos y Asignación
  listaBarberos: Barbero[] = [];
  listaUsuariosComunes: any[] = [];
  usuarioSeleccionadoId: string | number = '';
  
  barberoForm = { id: null as number | null, username: '', email: '', telefono: '' };
  editandoBarbero = false;

  private apiUrl = 'http://localhost:8000/api';

  private getHeaders(): HttpHeaders {
    const token = localStorage.getItem('access_token');
    return new HttpHeaders({
      'Content-Type':  'application/json',
      'Authorization': token ? `Bearer ${token}` : ''
    });
  }

  ngOnInit(): void {
    this.nombreUsuario = localStorage.getItem('username') || 'Admin';
    this.cargarCategorias();
    this.cargarServicios();
    this.cargarBarberos();
  }

  cambiarPestana(p: 'servicios' | 'barberos'): void {
    this.pestanaActiva = p;
    this.mensaje = '';
  }

  // ── Categorías ──────────────────────────────────────────
  cargarCategorias(): void {
    this.http.get<Categoria[]>(`${this.apiUrl}/categorias/`).subscribe({
      next: (data) => this.categorias = data,
      error: (err) => console.error('Error categorías:', err)
    });
  }

  filtrarPorCategoria(slug: string): void {
    this.categoriaSeleccionada = slug;
    if (slug === '') {
      this.serviciosFiltrados = this.listaServicios;
    } else {
      this.http.get<any>(`${this.apiUrl}/categorias/${slug}/`).subscribe({
        next: (data) => this.serviciosFiltrados = data.servicios,
        error: (err) => console.error(err)
      });
    }
  }

  // ── Servicios ────────────────────────────────────────────
  cargarServicios(): void {
    this.http.get<Servicio[]>(`${this.apiUrl}/admin/servicios/`, { headers: this.getHeaders() }).subscribe({
      next:  (data) => { this.listaServicios = data; this.serviciosFiltrados = data; },
      error: (err)  => console.error('Error servicios:', err)
    });
  }

  guardarServicio(): void {
    if (!this.servicioForm.nombre || !this.servicioForm.precio || !this.servicioForm.categoria) {
      this.mensaje = 'Completa nombre, precio y categoría.';
      return;
    }

    const payload = {
      nombre:      this.servicioForm.nombre,
      descripcion: this.servicioForm.descripcion,
      precio:      Number(this.servicioForm.precio),
      disponible:  this.servicioForm.disponible,
      categoria:   Number(this.servicioForm.categoria),
    };

    if (this.editandoServicio && this.servicioForm.id) {
      this.http.put(`${this.apiUrl}/admin/servicios/${this.servicioForm.id}/`, payload, { headers: this.getHeaders() }).subscribe({
        next:  () => { this.mensaje = '✓ Servicio actualizado.'; this.limpiarServicio(); this.cargarServicios(); },
        error: (err) => console.error(err)
      });
    } else {
      this.http.post(`${this.apiUrl}/admin/servicios/`, payload, { headers: this.getHeaders() }).subscribe({
        next:  () => { this.mensaje = '✓ Servicio creado.'; this.limpiarServicio(); this.cargarServicios(); },
        error: (err) => console.error(err)
      });
    }
  }

  editarServicio(s: Servicio): void {
    this.editandoServicio = true;
    this.servicioForm = {
      id:          s.id,
      nombre:      s.nombre,
      descripcion: s.descripcion,
      precio:      s.precio,
      disponible:  s.disponible,
      categoria:   s.categoria,
    };
  }

  eliminarServicio(id: number): void {
    if (confirm('¿Eliminar este servicio?')) {
      this.http.delete(`${this.apiUrl}/admin/servicios/${id}/`, { headers: this.getHeaders() }).subscribe({
        next:  () => { this.mensaje = '✓ Servicio eliminado.'; this.cargarServicios(); },
        error: (err) => console.error(err)
      });
    }
  }

  limpiarServicio(): void {
    this.editandoServicio = false;
    this.servicioForm = { id: null, nombre: '', descripcion: '', precio: '', disponible: true, categoria: '' };
    setTimeout(() => this.mensaje = '', 3000);
  }

  getNombreCategoria(id: number): string {
    return this.categorias.find(c => c.id === id)?.nombre ?? '—';
  }

  // ── Barberos ─────────────────────────────────────────────
  cargarBarberos(): void {
    this.http.get<Barbero[]>(`${this.apiUrl}/usuarios/barberos/`, { headers: this.getHeaders() }).subscribe({
      next:  (data) => {
        this.listaBarberos = data;
        // Cargamos y filtramos usuarios comunes una vez obtenidos los barberos
        this.cargarUsuariosComunes();
      },
      error: (err)  => console.error('Error barberos:', err)
    });
  }

  cargarUsuariosComunes(): void {
    this.http.get<any[]>(`${this.apiUrl}/usuarios/`, { headers: this.getHeaders() }).subscribe({
      next:  (data) => {
        // Excluye a barberos activos y al usuario administrador actual logueado
        this.listaUsuariosComunes = data.filter(u => 
          !this.listaBarberos.some(b => b.id === u.id) && 
          u.username.toLowerCase() !== this.nombreUsuario.toLowerCase()
        );
      },
      error: (err) => console.error('Error cargando usuarios:', err)
    });
  }

  guardarBarbero(): void {
    // Caso 1: Editar información básica de un barbero existente
    if (this.editandoBarbero && this.barberoForm.id) {
      const payload = {
        username: this.barberoForm.username,
        email:    this.barberoForm.email,
        telefono: this.barberoForm.telefono
      };
      this.http.put(`${this.apiUrl}/usuarios/${this.barberoForm.id}/`, payload, { headers: this.getHeaders() }).subscribe({
        next:  () => { this.mensaje = '✓ Barbero actualizado.'; this.limpiarBarbero(); this.cargarBarberos(); },
        error: (err) => console.error(err)
      });
    } 
    // Caso 2: Promover o asignar un nuevo usuario como barbero
    else {
      if (!this.usuarioSeleccionadoId) {
        this.mensaje = 'Selecciona un usuario para asignarlo como barbero.';
        return;
      }
      
      // ⬇️ CAMBIO AQUÍ: Enviamos el ID del Rol como número. 
      // Si el ID de Barbero en tu DB no es 3, cámbialo por el número correcto (ej: 2, 4)
      const payload = {
        rol: 2 // 👈 Cambia este número por el ID real de tu rol Barbero
      };

      this.http.patch(`${this.apiUrl}/usuarios/${this.usuarioSeleccionadoId}/`, payload, { headers: this.getHeaders() }).subscribe({
        next: () => {
          this.mensaje = '✓ Usuario asignado como Barbero con éxito.';
          this.limpiarBarbero();
          this.cargarBarberos(); 
        },
        error: (err) => {
          if (err.error && err.error.rol) {
            console.log('Mensaje exacto de Django:', err.error.rol[0]);
          } else {
            console.error('Error completo:', err.error);
          }
          this.mensaje = 'Error al asignar el rol en el servidor.';
        }
      });
    }
  }

  editarBarbero(b: Barbero): void {
    this.editandoBarbero = true;
    this.barberoForm = { id: b.id, username: b.username, email: b.email, telefono: b.telefono || '' };
  }

  eliminarBarbero(id: number): void {
    if (confirm('¿Quitar el rol de barbero a este usuario?')) {
      
      // ⬇️ CAMBIO AQUÍ: Coloca el ID correspondiente al rol de Cliente común (suele ser 1 o 2)
      const payload = { 
        rol: 1 
      };

      this.http.patch(`${this.apiUrl}/usuarios/${id}/`, payload, { headers: this.getHeaders() }).subscribe({
        next:  () => { 
          this.mensaje = '✓ Rol de barbero removido.'; 
          this.cargarBarberos(); 
        },
        error: (err) => {
          if (err.error && err.error.rol) {
            console.log('Mensaje exacto de Django al remover:', err.error.rol[0]);
          } else {
            console.error('Error completo al remover:', err.error);
          }
          this.mensaje = 'Error al remover el rol en el servidor.';
        }
      });
    }
  }

  limpiarBarbero(): void {
    this.editandoBarbero = false;
    this.usuarioSeleccionadoId = '';
    this.barberoForm = { id: null, username: '', email: '', telefono: '' };
    setTimeout(() => this.mensaje = '', 3000);
  }

  logout(): void {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('username');
    this.router.navigate(['/login']);
  }
}