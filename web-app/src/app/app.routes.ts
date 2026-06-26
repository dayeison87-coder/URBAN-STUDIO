import { Routes } from '@angular/router';
import { HomeComponent } from './pages/home/home';
import { LoginComponent } from './pages/login/login';
import { RegisterComponent } from './pages/register/register';
import { authGuard } from './services/auth-guard';
import { CitasComponent } from './pages/citas/citas.component';

export const routes: Routes = [

  // Redirección inicial
  { path: '', redirectTo: 'login', pathMatch: 'full' },

  // Rutas públicas
  { path: 'login', component: LoginComponent },
  { path: 'register', component: RegisterComponent },

  // Rutas protegidas
  { path: 'home', component: HomeComponent, canActivate: [authGuard] },
  { path: 'citas', component: CitasComponent, canActivate: [authGuard] },

  //  BARBEROS (IMPORTANTE: antes del wildcard)
  {
    path: 'barberos',
    loadComponent: () =>
      import('./pages/barberos/barberos')
        .then(m => m.Barberos),
    canActivate: [authGuard]
  },

  // Ruta comodín (SIEMPRE AL FINAL)
  { path: '**', redirectTo: 'login' }
];