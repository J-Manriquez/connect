# CLAUDE.md

Guía para Claude al trabajar en este proyecto (Flutter, app Android `connect`).

## Reglas de flujo

- **Al terminar una tarea que modifique código o comportamiento de la app**,
  preguntar al usuario si quiere que dejen listas las **tres versiones de APK**
  en la carpeta `releases/` para subirlas a git.
  - Compilar con un solo comando: `flutter build apk --split-per-abi`.
  - Esto genera en `build/app/outputs/flutter-apk/`:
    - `app-armeabi-v7a-release.apk` (relojes / 32-bit ARM)
    - `app-arm64-v8a-release.apk` (teléfonos modernos / 64-bit ARM)
    - `app-x86_64-release.apk` (emuladores / x86 64-bit)
  - Si el usuario acepta, copiar los tres APK a `releases/` (renombrándolos con
    la versión de `pubspec.yaml`, p. ej. `connect-vX.Y.Z-armeabi-v7a.apk`) y
    dejarlos listos para el commit / Release de GitHub.
  - No compilar ni mover nada sin confirmación previa del usuario.
