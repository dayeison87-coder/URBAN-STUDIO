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

export const routes: Routes = [
  { path: '', redirectTo: 'login', pathMatch: 'full' },

  // Rutas públicas
  { path: 'login',    component: LoginComponent },
  { path: 'register', component: RegisterComponent },

  // Rutas protegidas
  { path: 'home',      component: HomeComponent,      canActivate: [authGuard] },
  { path: 'servicios', component: ServicioComponent,  canActivate: [authGuard] },
  { path: 'citas',     component: CitasComponent,     canActivate: [authGuard] },
  { path: 'admin',     component: AdminComponent,     canActivate: [authGuard] },
  { path: 'barbero',   component: BarberoComponent,   canActivate: [authGuard] },
  { path: 'chat',      component: ChatComponent,      canActivate: [authGuard] },
  
  // Ruta con Lazy Loading
  { 
    path: 'barberos', 
    loadComponent: () => import('./pages/barberos/barberos').then(m => m.Barberos), 
    canActivate: [authGuard] 
  },

  // Comodín para rutas no existentes
  { path: '**', redirectTo: 'login' },
];