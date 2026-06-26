import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { CitasService } from '../../services/citas.service';

@Component({
  selector: 'app-citas',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './citas.component.html',
  styleUrl: './citas.component.css'
})
export class CitasComponent implements OnInit {
  private citasService = inject(CitasService);

  listaCitas: any[] = [];
  serviciosDisponibles: any[] = []; 
  barberosDisponibles: any[] = []; // 🔥 CLAVE 1: Debe empezar vacía para limpiar los quemados viejos

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
    this.cargarServicios();
    this.cargarBarberos(); // 🔥 CLAVE 2: Ejecuta la petición al backend inmediatamente al cargar
  }

  cargarCitas(): void {
    this.citasService.obtenerCitas().subscribe({
      next: (data) => this.listaCitas = data,
      error: (err) => console.error('Error al cargar citas:', err)
    });
  }

  cargarServicios(): void {
    this.citasService.obtenerServicios().subscribe({
      next: (data) => this.serviciosDisponibles = data,
      error: (err) => console.error('Error al cargar servicios:', err)
    });
  }

  cargarBarberos(): void {
    this.citasService.obtenerUsuarios().subscribe({
      next: (data) => {
        this.barberosDisponibles = data; 
        console.log('✅ Barberos reales cargados desde la BD:', data);
      },
      error: (err) => {
        console.error('Error crítico al cargar barberos:', err);
        this.mensaje = 'Aviso: No se pudieron mapear los barberos del servidor.';
      }
    });
  }

  guardarCita(): void {
    if (!this.citaForm.barbero || !this.citaForm.servicio || !this.citaForm.fecha || !this.citaForm.hora) {
      this.mensaje = 'Por favor, llena todos los campos.';
      return;
    }

    const datosAEnviar = {
      ...this.citaForm,
      barbero: parseInt(this.citaForm.barbero, 10),
      servicio: parseInt(this.citaForm.servicio, 10)
    };

    if (this.editando && this.citaForm.id !== null) {
      this.citasService.editarCita(this.citaForm.id, datosAEnviar).subscribe({
        next: () => {
          this.mensaje = 'Cita actualizada con éxito.';
          this.limpiarFormulario();
          this.cargarCitas();
        },
        error: (err) => console.error('Error al editar:', err)
      });
    } else {
      console.log('✂️ Intentando CREAR una nueva cita dinámica...');
      const nuevaCita = { ...datosAEnviar };
      delete (nuevaCita as any).id;

      this.citasService.crearCita(nuevaCita).subscribe({
        next: () => {
          this.mensaje = '¡Cita agendada correctamente!';
          this.limpiarFormulario();
          this.cargarCitas();
        },
        error: (err) => {
          console.error('Error al crear:', err);
          this.mensaje = 'Error al registrar la cita en la base de datos.';
        }
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