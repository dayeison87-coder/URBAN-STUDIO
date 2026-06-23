import { Routes } from '@angular/router'; //  ¡ESTÁ BIEN!
import { HomeComponent } from './pages/home/home';
import { LoginComponent } from './pages/login/login';
import { RegisterComponent } from './pages/register/register';
import { authGuard } from './services/auth-guard';

export const routes: Routes = [
  // 1. Cuando entres a la app, te mandará directo al login por defecto
  { path: '', redirectTo: 'login', pathMatch: 'full' },

  // 2. Rutas Públicas (Cualquiera puede entrar sin registrarse)
  { path: 'login', component: LoginComponent },
  { path: 'register', component: RegisterComponent },

  // 3. Ruta Protegida (Solo entra el que tenga el Token JWT de Django válido)
  { path: 'home', component: HomeComponent, canActivate: [authGuard] },

  // 4. Comodín: Si escriben cualquier otra locura en la URL, los devuelve al login
  { path: '**', redirectTo: 'login' }
];