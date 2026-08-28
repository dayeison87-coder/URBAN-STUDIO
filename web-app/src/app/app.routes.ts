import { Routes } from '@angular/router';

import { authGuard } from './services/auth-guard';

// ==========================================
// COMPONENTES
// ==========================================

import { AdminComponent } from './pages/admin/admin';
import { HomeComponent } from './pages/home/home';
import { LoginComponent } from './pages/login/login';
import { RegisterComponent } from './pages/register/register';
import { CitasComponent } from './pages/citas/citas.component';
import { ServicioComponent } from './pages/servicios/servicio.component';
import { BarberoComponent } from './pages/barbero/barbero';
import { ChatComponent } from './pages/chat/chat';
import { AnalisisRostroComponent } from './pages/gemini/geminis';
import { PerfilClienteComponent } from './pages/perfil-cliente/perfil-cliente';
import { ConfiguracionCuentaComponent } from './pages/configuracion-cuenta/configuracion-cuenta';

// ==========================================
// RUTAS
// ==========================================

export const routes: Routes = [

  // ==========================================
  // RUTA PRINCIPAL
  // ==========================================

  {
    path: '',
    redirectTo: 'login',
    pathMatch: 'full'
  },

  // ==========================================
  // RUTAS PÚBLICAS
  // ==========================================

  {
    path: 'login',
    component: LoginComponent
  },

  {
    path: 'register',
    component: RegisterComponent
  },

  // ==========================================
  // RUTAS PROTEGIDAS
  // ==========================================

  {
    path: 'home',
    component: HomeComponent,
    canActivate: [authGuard]
  },

  {
    path: 'servicios',
    component: ServicioComponent,
    canActivate: [authGuard]
  },

  {
    path: 'citas',
    component: CitasComponent,
    canActivate: [authGuard]
  },

  {
    path: 'perfil',
    component: PerfilClienteComponent,
    canActivate: [authGuard]
  },

  {
    path: 'configuracion-cuenta',
    component: ConfiguracionCuentaComponent,
    canActivate: [authGuard]
  },

  // ==========================================
  // SOLO ADMIN
  // ==========================================

  {
    path: 'admin',
    component: AdminComponent,
    canActivate: [authGuard],
    data: {
      roles: ['Admin']
    }
  },

  // ==========================================
  // VISTA BARBERO
  // Panel individual del barbero
  // ==========================================

  {
    path: 'barbero',
    component: BarberoComponent,
    canActivate: [authGuard],
    data: {
      roles: ['Barbero', 'Admin']
    }
  },

  // ==========================================
  // VISTA BARBEROS
  // Lista / gestión de barberos
  // ==========================================

  {
    path: 'barberos',
    loadComponent: () =>
      import('./pages/barberos/barberos')
        .then(m => m.Barberos),
    canActivate: [authGuard],
   
  },

  // ==========================================
  // CHAT
  // ==========================================

  {
    path: 'chat',
    component: ChatComponent,
    canActivate: [authGuard]
  },

  // ==========================================
  // ANÁLISIS DE ROSTRO / GEMINI
  // ==========================================

  {
    path: 'gemini',
    component: AnalisisRostroComponent,
    canActivate: [authGuard]
  },

  // ==========================================
  // COMODÍN
  // Si la ruta no existe, vuelve al login
  // ==========================================

  {
    path: '**',
    redirectTo: 'login'
  }

];