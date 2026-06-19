import { Routes } from '@angular/router';
import { HomeComponent } from './pages/home/home';
import { LoginComponent } from './pages/login/login';
import { RegisterComponent } from './pages/register/register';

export const routes: Routes = [
  // 1. Cuando entres a la app, te mandará directo al login por defecto
  { path: '', redirectTo: 'login', pathMatch: 'full' },

  // 2. Aquí declaramos las direcciones de tus carpetas
  { path: 'home', component: HomeComponent },
  { path: 'login', component: LoginComponent },
  { path: 'register', component: RegisterComponent },

  // 3. Si escriben cualquier otra cosa en la URL, los devuelve al login
  { path: '**', redirectTo: 'login' }
];