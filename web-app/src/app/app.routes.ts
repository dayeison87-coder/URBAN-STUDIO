import { Routes } from '@angular/router';
import { authGuard } from './services/auth-guard';

// Componentes
import { AdminComponent } from './pages/admin/admin';
import { HomeComponent } from './pages/home/home';
import { LoginComponent } from './pages/login/login';
import { RegisterComponent } from './pages/register/register';
import { CitasComponent } from './pages/citas/citas.component';
import { ServicioComponent } from './pages/servicios/servicio.component';
import { BarberoComponent } from './pages/barbero/barbero';
import { ChatComponent } from './pages/chat/chat';
import { AnalisisRostroComponent } from './pages/gemini/geminis';

export const routes: Routes = [
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
  // VISTA BARBERO (SINGULAR - Panel del Barbero)
  // ==========================================
  { 
    path: 'barbero', 
    component: BarberoComponent, 
    canActivate: [authGuard],
    data: {
      roles: ['Barbero', 'Admin']
    }
  },
  { 
    path: 'chat', 
    component: ChatComponent, 
    canActivate: [authGuard] 
  },
  { 
    path: 'gemini', 
    component: AnalisisRostroComponent, 
    canActivate: [authGuard] 
  },
  // ==========================================
  // VISTA BARBEROS (PLURAL - Lista/Gestión)
  // ==========================================
  { 
    path: 'barberos', 
    loadComponent: () => 
      import('./pages/barberos/barberos')
        .then(m => m.Barberos), 
    canActivate: [authGuard],
    data: {
      roles: ['Barbero', 'Admin']
    }
  },
  // ==========================================
  // COMODÍN
  // ==========================================
  { 
    path: '**', 
    redirectTo: 'login' 
  }
];