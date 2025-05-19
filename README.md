# auth_app

App móvil desarrollada con Flutter que implementa un sistema Kanban para la gestión de tareas, con autenticación de usuarios mediante Supabase. Permite a los usuarios registrarse, iniciar sesión, y gestionar sus tareas personales en un tablero Kanban con tres columnas: Por Hacer, En Progreso y Hecho.


# TECNOLOGÍAS USADAS:

Supabase (^2.9.0): 
    -   Encargada de almacenar los datos de forma persistente en la nube.
    -   Autenticación de usuarios (registro, inicio de sesión)

Flutter Riverpod (^2.6.1):
    -   Manejo de estados de las distintas pantallas de la app.
    
Flutter Boardview (^0.2.1):
    -   Implementa la interfaz Kanban con funcionalidad de arrastrar y soltar las tareas entre columnas.

Go Router (^15.1.2):
    -   Manejar rutas con y sin envio de parametros

Flutter Dotenv (^5.2.1):
    -   Manejo variables de entorno sensibles sin exponerlas en el código.

Intl (^0.20.2):
    -   Usada para formateo de fechas.

# CONFIGURACIÓN DEL PROYECTO

1.    Clona este repositorio
2.    Ejecuta flutter pub get para instalar las dependencias
3.    Crea un archivo .env en la raíz del proyecto con las siguientes variables:
4.    SUPABASE_URL=tu_url_de_supabase
5.    SUPABASE_ANON_KEY=tu_clave_anonima_de_supabase

Ejecuta la aplicación con flutter run

# ESTRUCTURA DE LA BASE DE DATOS

La aplicación utiliza una tabla tasks en Supabase con la siguiente estructura:

id: Identificador único de la tarea
title: Título de la tarea
description: Descripción detallada de la tarea
status: Estado actual de la tarea (pending, inProgress, done)
user_id: ID del usuario propietario de la tarea
created_at: Fecha de creación
updated_at: Fecha de última actualización
