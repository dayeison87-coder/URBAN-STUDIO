import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { CitasService } from '../../services/citas.service'; // Asegúrate de que la ruta apunte bien a tu servicio

@Component({
  selector: 'app-citas',
  standalone: true,
  imports: [CommonModule, FormsModule], // Módulos críticos cargados explícitamente
  templateUrl: './citas.component.html',
  styleUrl: './citas.component.css'
})
export class CitasComponent implements OnInit {
  private citasService = inject(CitasService);

  listaCitas: any[] = [];
  
  // Mocks locales para los barberos y servicios asignados a Urban Studio
  barberosDisponibles = [
    { id: 2, username: 'Olivera' },
    { id: 3, username: 'Larota' },
    { id: 4, username: 'Kevin' }
  ];
  
  serviciosDisponibles = [
    { id: 1, nombre: 'Corte Tradicional', precio: '20000' },
    { id: 2, nombre: 'Barba Premium', precio: '15000' },
    { id: 3, nombre: 'Combo Urban (Corte + Barba)', precio: '30000' }
  ];

  // Modelo del formulario tipado de forma segura para evitar conflictos en los selectores
  citaForm = {
    id: null as number | null,
    barbero: '' as any,
    servicio: '' as any,
    fecha: '',
    hora: '',
    estado: 'Pendiente'
  };

  editando: boolean = false;
  mensaje: string = '';

  ngOnInit(): void {
    this.cargarCitas();
  }

  cargarCitas(): void {
    this.citasService.obtenerCitas().subscribe({
      next: (data) => {
        this.listaCitas = data;
      },
      error: (err) => {
        console.error('Error al conectar con Django:', err);
        this.mensaje = 'Aviso: No se pudieron cargar los datos del servidor.';
      }
    });
  }

  guardarCita(): void {
    // Validación manual rápida antes de procesar
    if (!this.citaForm.barbero || !this.citaForm.servicio || !this.citaForm.fecha || !this.citaForm.hora) {
      this.mensaje = 'Por favor, llena todos los campos.';
      return;
    }

    if (this.editando && this.citaForm.id) {
      // Flujo para actualizar cita existente
      this.citasService.editarCita(this.citaForm.id, this.citaForm).subscribe({
        next: () => {
          this.mensaje = 'Cita actualizada con éxito.';
          this.limpiarFormulario();
          this.cargarCitas();
        },
        error: (err) => console.error('Error al editar:', err)
      });
    } else {
      // Flujo para crear nueva cita
      this.citasService.crearCita(this.citaForm).subscribe({
        next: () => {
          this.mensaje = '¡Cita agendada correctamente!';
          this.limpiarFormulario();
          this.cargarCitas();
        },
        error: (err) => console.error('Error al crear:', err)
      });
    }
  }

  seleccionarCita(cita: any): void {
    this.editando = true;
    this.citaForm = {
      id: cita.id,
      barbero: cita.barbero,
      servicio: cita.servicio,
      fecha: cita.fecha,
      hora: cita.hora,
      estado: cita.estado
    };
  }

  borrarCita(id: number): void {
    if (confirm('¿Estás seguro de que deseas cancelar esta cita?')) {
      this.citasService.eliminarCita(id).subscribe({
        next: () => {
          this.mensaje = 'Cita eliminada.';
          this.cargarCitas();
        },
        error: (err) => console.error(err)
      });
    }
  }

  limpiarFormulario(): void {
    this.editando = false;
    this.citaForm = {
      id: null,
      barbero: '',
      servicio: '',
      fecha: '',
      hora: '',
      estado: 'Pendiente'
    };
    setTimeout(() => this.mensaje = '', 4000);
  }
}