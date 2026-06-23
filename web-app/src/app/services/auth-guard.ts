import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';

export const authGuard: CanActivateFn = (route, state) => {
  const router = inject(Router);
  
  // Revisamos si el token de acceso real de Django está guardado
  const token = localStorage.getItem('access_token');

  if (token) {
    return true; // 🔓 ¡Pase libre! El usuario está logueado, lo deja entrar al Home
  } else {
    // 🔒 ¡Bloqueado! No hay token, lo mandamos de patitas a la calle (al Login)
    router.navigate(['/login']);
    return false;
  }
};