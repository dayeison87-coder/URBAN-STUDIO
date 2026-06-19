import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { AppComponent } from './app/app'; // <-- Cambiar 'App' por 'AppComponent'

bootstrapApplication(AppComponent, appConfig) // <-- Asegúrate de que aquí también diga AppComponent
  .catch((err) => console.error(err));