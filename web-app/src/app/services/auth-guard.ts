import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';

export const authGuard: CanActivateFn = (route, state) => {
  const router = inject(Router);
  // Comprobar que el usuario haya iniciado sesión
  const token = localStorage.getItem('access_token');
  if (!token) {
    router.navigate(['/login']);
    return false;
  }

  // Obtener el rol guardado durante el login
  const rol = localStorage.getItem('rol');

  // Obtener los roles permitidos para esta ruta
  const rolesPermitidos = route.data['roles'];

  // Si la ruta no tiene restricción de rol,
  // dejamos entrar a cualquier usuario autenticado.
  if (!rolesPermitidos) {
    return true;
  }

  // Comprobar si el rol del usuario está permitido
  if (rolesPermitidos.includes(rol)) {
    return true;
  }

  // Si no tiene permiso, lo mandamos al Home
  router.navigate(['/home']);
  return false;
};