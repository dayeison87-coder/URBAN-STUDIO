import { AdminComponent } from './pages/admin/admin';
import { Routes } from '@angular/router';
import { HomeComponent } from './pages/home/home';
import { LoginComponent } from './pages/login/login';
import { RegisterComponent } from './pages/register/register';
import { authGuard } from './services/auth-guard';
import { CitasComponent } from './pages/citas/citas.component';
import { ServicioComponent } from './pages/servicios/servicio.component';
import { BarberoComponent } from './pages/barbero/barbero';
import { ChatComponent } from './pages/chat/chat'; // ← agregar

export const routes: Routes = [
  { path: '', redirectTo: 'login', pathMatch: 'full' },

  { path: 'login',    component: LoginComponent },
  { path: 'register', component: RegisterComponent },
  { path: 'servicios', component: ServicioComponent },

  { path: 'home',    component: HomeComponent,    canActivate: [authGuard] },
  { path: 'citas',   component: CitasComponent,   canActivate: [authGuard] },
  { path: 'admin',   component: AdminComponent,   canActivate: [authGuard] },
  { path: 'barbero', component: BarberoComponent, canActivate: [authGuard] },
  { path: 'chat',    component: ChatComponent,    canActivate: [authGuard] }, // ← agregar

  { path: '**', redirectTo: 'login' },
];