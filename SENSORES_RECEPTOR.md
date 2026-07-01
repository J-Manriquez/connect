# Sensores del dispositivo receptor — Plan de implementación

> Basado en diagnóstico del 2026-06-28 del dispositivo **ULTRA Ai 3** (hesc/sl8541e_1h10)
> Android 8.1 · SDK 27 · ABI: arm64-v8a, armeabi-v7a, armeabi · 4 núcleos ARMv8 Cortex-A53

---

## Nota sobre el hardware

El fingerprint indica `Lanix/Ilium_LT510` rebrandeado como *ULTRA Ai 3*. Es un Android completo
(no un RTOS como los relojes baratos), lo que significa que **todos los sensores son accesibles
vía la API estándar de Android** (`SensorManager`, `SensorEventListener`).

La presencia del `rotary encoder` (tipo 36) confirma que tiene **corona giratoria física**.

---

## Inventario de sensores detectados

| # | Tipo Android | Nombre | Vendor | wakeUp | minDelay | Rango | ¿Implementar? |
|---|---|---|---|---|---|---|---|
| 1 | type=1 `ACCELEROMETER` | ST Xr 3-axis Accelerometer | ST | No | 10 ms | 9.8 m/s² | ✅ Sí |
| 2 | type=2 `MAGNETIC_FIELD` | AFx133 Magnetic field sensor | Voltafield | No | 10 ms | 1600 µT | ✅ Sí (brújula) |
| 3 | type=3 `ORIENTATION` | VTC Orientation sensor | Voltafield | No | 10 ms | 360° | ❌ No (deprecado, usar type=20) |
| 4 | type=5 `LIGHT` | Light Sensor | NULL | No | on-change | — | ❌ No (Android lo maneja) |
| 5 | type=8 `PROXIMITY` | Proximity Sensor | NULL | **Sí** | on-change | — | ✅ Sí (wrist on/off) |
| 6 | type=20 `GEOMAGNETIC_ROTATION_VECTOR` | GeoMag Rotation Vector | AOSP | No | 10 ms | 1.0 | ✅ Sí (brújula) |
| 7 | type=21 `HEART_RATE` | bd1688 HeartrateSensor | ZH Sensortec | No | 20 ms | 237 BPM | ✅ Sí |
| 8 | type=36 `ROTARY_ENCODER` | rotary encoder | HSC encoder | No | 5 ms | 34.9 rad | ✅ Sí (corona) |

---

## Funcionalidades a implementar

### ✅ 1. Monitor de frecuencia cardíaca (HR)

> **Pantalla:** `SaludScreen` → card HR con gráfica de historial

**Sensor:** `bd1688 HeartrateSensor` (type=21)

**Qué implementar:**
- Leer BPM en tiempo real y mostrarlo en la pantalla de salud del receptor
- Historial de HR durante el día (gráfica por horas con `fl_chart`)
- Alertas de taquicardia (>X BPM) o bradicardia (<Y BPM) configurables por el usuario
- Calcular zona de entrenamiento activa según BPM + FCmáx del perfil corporal
- Estimar calorías en tiempo real usando HR + datos del perfil (fórmula Keytel)
- Enviar BPM al emisor por BT: `HR:85`

**Qué NO implementar:**
- HRV/RMSSD — el sensor `bd1688` entrega BPM, no intervalos RR crudos. Sin latidos
  crudos el HRV es una estimación sin valor real. Omitir completamente.

**Android (Kotlin) — `SensorForegroundService.kt`:**
```kotlin
val hrSensor = sensorManager.getDefaultSensor(Sensor.TYPE_HEART_RATE)
sensorManager.registerListener(listener, hrSensor, SensorManager.SENSOR_DELAY_NORMAL)
// event.values[0] = BPM, event.values[1] = confidence (0=no contact, 1=unreliable, 2=ok, 3=high)
// Solo emitir al canal si values[1] >= 2
```

**Permisos en `AndroidManifest.xml`:**
```xml
<uses-permission android:name="android.permission.BODY_SENSORS" />
```

**EventChannel:** `connect/heart_rate` → `Stream<Map>` con `{ bpm, confidence, timestamp }`

**Almacenamiento:** Hive box `'hr_log'` — `{ timestamp: int, bpm: int, zona: String }`

**Limitación:** `wakeUp=false` — requiere `ForegroundService` con notificación persistente
para recibir datos con la pantalla apagada.

---

### ✅ 2. Zonas de entrenamiento por HR

> **Pantalla:** integrado en card HR de `SaludScreen`

**Lógica pura en Dart** — no requiere canal nativo adicional.

**Qué implementar:**
- Leer FCmáx del perfil corporal (`220 - edad` o valor manual)
- Clasificar el BPM recibido en zona y mostrar con color:
  - Zona 1 — Reposo: < 50% → azul
  - Zona 2 — Fat-burn: 50–60% → verde
  - Zona 3 — Cardio: 60–70% → amarillo
  - Zona 4 — Aeróbico: 70–80% → naranja
  - Zona 5 — Peak: > 80% → rojo
- Tiempo acumulado por zona durante una sesión activa

**Qué NO implementar:**
- Pantalla separada de zonas — se muestra inline en la card HR.

**Persistencia:** `PreferencesService` para FCmáx; Hive box `'hr_zones_log'` para historial de zonas por sesión.

---

### ✅ 3. Estimación de calorías

> **Pantalla:** integrado en card HR de `SaludScreen`

**Lógica pura en Dart** — no requiere canal nativo adicional.

**Fórmula (Keytel et al.):**
```
Hombres: kcal/min = (−55.0969 + 0.6309×HR + 0.1988×peso + 0.2017×edad) / 4.184
Mujeres: kcal/min = (−20.4022 + 0.4472×HR − 0.1263×peso + 0.074×edad) / 4.184
```

**Qué implementar:**
- Acumular kcal durante sesión activa (HR > 50% FCmáx)
- Mostrar kcal totales del día y de la sesión actual

**Qué NO implementar:**
- Historial extendido de calorías por semana/mes — fuera de alcance inicial.

**Requiere:** datos de peso, edad y sexo del perfil corporal del usuario.

---

### ✅ 4. Pedómetro por software

> **Pantalla:** `PasosScreen` — pantalla propia dentro de Salud

**Sensor:** `ACCELEROMETER` type=1 — no hay sensor de pasos hardware.

**Qué implementar:**
```
Algoritmo de detección de pasos:
1. magnitude = sqrt(x² + y² + z²)
2. Filtrar con media móvil (ventana 10 muestras)
3. Detectar pico: magnitude > THRESHOLD y luego baja
4. Tiempo mínimo entre pasos: 250 ms (anti-rebote)
5. Contar pico como paso
```
- Servicio nativo con `ForegroundService` — mismo `SensorForegroundService`
- EventChannel `connect/steps` → `Stream<int>` pasos acumulados del día
- Reset automático a medianoche
- Meta de pasos configurable (default 10,000) desde perfil corporal
- Mostrar: pasos, distancia estimada (altura × 0.415), kcal aproximadas
- Enviar al emisor: `STEPS:4231`

**Qué NO implementar:**
- Detección de actividad (caminar/correr/vehículo) — demasiado complejo para el valor
  que aporta sin giroscopio. El pedómetro básico es suficiente.
- Velocidad en tiempo real — poco útil sin GPS para validar.

**Parámetros ajustables (calibrar en el dispositivo):**
```
THRESHOLD = 10.5    // m/s²
MIN_STEP_INTERVAL = 250ms
SMOOTHING_WINDOW = 10 muestras
```

**Almacenamiento:** Hive box `'steps_log'` — `{ fecha: String, pasos: int, distancia_m: double }`

---

### ✅ 5. Brújula

> **Pantalla:** `BrujulaScreen` — pantalla propia

**Sensor:** `GEOMAGNETIC_ROTATION_VECTOR` (type=20, AOSP) — preferido sobre
`MAGNETIC_FIELD` solo porque ya fusiona acelerómetro + magnetómetro.

**Qué implementar:**
- Aguja animada con `CustomPainter` que rota según azimuth (0–360°)
- Mostrar grados y cardinal (N/NE/E/SE/S/SO/O/NO)
- Aviso de calibración si la precisión del sensor es baja (`SensorAccuracy < MEDIUM`)

**Qué NO implementar:**
- Integración con rutas o navegación al emisor — sin GPS no tiene valor real.
- Orientación 3D (pitch/roll) — no aporta en este caso de uso.

**Android (Kotlin):**
```kotlin
// Usar getRotationMatrix + getOrientation, NO el sensor type=3 (deprecado)
val rotVec = sensorManager.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
// En onSensorChanged:
val rotMatrix = FloatArray(9)
SensorManager.getRotationMatrixFromVector(rotMatrix, event.values)
val orientation = FloatArray(3)
SensorManager.getOrientation(rotMatrix, orientation)
val azimuthDeg = Math.toDegrees(orientation[0].toDouble()).toFloat()
// Enviar azimuthDeg al canal Flutter
```

**EventChannel:** `connect/compass` → `Stream<double>` azimuth en grados

---

### ✅ 6. Detección de muñeca puesta/quitada

> **Lógica de fondo** — no tiene pantalla propia, afecta a todas las funcionalidades

**Sensor:** `PROXIMITY` (type=8, **wakeUp=true**)

**Qué implementar:**
- Registrar el sensor en `SensorForegroundService`
- Al ponerse (proximidad cubierta): llamar a `wakeUpScreenConservative()` + reanudar sensores HR/pasos
- Al quitarse: pausar sensores HR/pasos (ahorra batería) + enviar `WRIST:OFF` al emisor

**Qué NO implementar:**
- Pantalla de diagnóstico de proximidad — se cubre con la pantalla debug general.

**Reutilización del wake-up existente (cambio mínimo, 1 línea):**

Cambiar en [LocalNotificationManager.kt:820](android/app/src/main/kotlin/com/example/connect/LocalNotificationManager.kt#L820):
```kotlin
// Antes:
private fun wakeUpScreenConservative(allowActivityLaunch: Boolean = true)
// Después:
internal fun wakeUpScreenConservative(allowActivityLaunch: Boolean = true)
```

Esto **no rompe nada** del flujo de notificaciones. El `SensorForegroundService` llama al
mismo método con `allowActivityLaunch = false` (apropiado para Android 8.0).

**EventChannel:** `connect/wrist_state` → `Stream<String>` `"on_wrist"` / `"off_wrist"`

---

### ✅ 7. Control por corona giratoria (Rotary Encoder)

> **Lógica transversal** — actúa sobre la pantalla activa del receptor

**Sensor:** `rotary encoder` (type=36) — no está en la API pública de Android.

**Qué implementar:**
- Scroll en la lista de notificaciones del receptor
- Control de volumen: enviar `ROTARY:+0.15` al emisor
- En `PasosScreen`: girar = ajustar meta de pasos

**Qué NO implementar:**
- Control de música desde la corona — el emisor ya tiene su pantalla de reproducción
  y añadir este control desde el receptor complica la sincronización de estado.
- Contador de series de ejercicio — demasiado de nicho para esta fase.

**Android (Kotlin) — canal nativo obligatorio:**
```kotlin
val SENSOR_TYPE_ROTARY_ENCODER = 36
val rotarySensor = sensorManager.getDefaultSensor(SENSOR_TYPE_ROTARY_ENCODER)
// event.values[0] = delta en radianes (positivo = horario, negativo = antihorario)
```

**MethodChannel:** `connect/rotary` — el receptor llama al canal para registrar/cancelar
escucha según la pantalla activa.

---

## Funcionalidades descartadas

| Funcionalidad | Razón |
|---|---|
| HRV / variabilidad cardíaca | El sensor `bd1688` entrega BPM, no latidos crudos. Sin intervalos RR el cálculo es inútil. |
| Detección de actividad (caminar/correr/vehículo) | Requiere giroscopio para ser preciso. Sin él hay demasiados falsos positivos. |
| Detección de caída | Útil pero alta complejidad y muchos falsos positivos. Posponer a fase 2. |
| Detección de sueño | Sin sensor dedicado la precisión es baja. La heurística da una mala experiencia. |
| Brillo automático por sensor de luz | Android 8.1 ya lo gestiona nativamente. |
| Sensor de orientación (type=3) | Deprecado desde Android 2.2. Se reemplaza con type=20. |
| Estimación de velocidad en tiempo real | Sin GPS no se puede validar. El pedómetro básico es suficiente. |
| Detección de actividad avanzada | Sin giroscopio, demasiados falsos positivos. |

---

## Pantalla de perfil corporal del usuario

> **Ruta:** `/user_body_profile`
> **Archivo:** `lib/screens/shared/user_body_profile_screen.dart`
> **Acceso:** desde ajustes del emisor Y del receptor (ambos necesitan los datos)

**Datos a capturar:**

| Campo | Tipo | Usado por |
|---|---|---|
| Nombre | String | Perfil general |
| Edad | int | FCmáx, calorías, zonas HR |
| Sexo | enum (M/F) | Fórmula de calorías (Keytel) |
| Peso (kg) | double | Fórmula de calorías |
| Altura (cm) | double | Longitud de zancada (pasos → distancia) |
| FCmáx manual | int? | Zonas HR (si el usuario la sabe; sino 220−edad) |
| Meta de pasos diaria | int | Pedómetro (default 10,000) |
| Alertas HR: umbral alto | int | Alerta taquicardia (default 120 BPM) |
| Alertas HR: umbral bajo | int | Alerta bradicardia (default 50 BPM) |

**Persistencia:** `PreferencesService` (claves prefijadas con `bodyProfile_`).
No necesita Hive ni Firebase — son datos de configuración, no historial.

**Diseño:** pantalla con `TabBar` de 2 pestañas:
- **Perfil** — datos personales (edad, sexo, peso, altura)
- **Salud** — FCmáx, metas de pasos, umbrales de alerta HR

---

## Nueva opción en el Bottom Navigation

### Emisor — `emisor_screen.dart`
**Índices actuales:** 0=Configuración · 1=Emisor · 2=Aplicaciones
**Añadir:** índice 3 → `Salud` (icono: `Icons.monitor_heart`)

```dart
// En el switch onTap del emisor:
case 3:
  Navigator.pushReplacementNamed(context, '/emisor_salud');
  break;

// En los items:
BottomNavigationBarItem(icon: Icon(Icons.monitor_heart), label: 'Salud'),
```

**Pantalla emisor salud** (`/emisor_salud` → `EmisorSaludScreen`):
- Solo **muestra datos** recibidos del receptor por BT
- No ejecuta sensores ni tiene lógica nativa
- Navega a sub-pantallas de solo lectura (ver más abajo)

### Receptor — `conexion_screen.dart`
**Índices actuales:** 0=Configuración · 1=Conexión · 2=Notificaciones
**Añadir:** índice 3 → `Salud` (icono: `Icons.monitor_heart`)

```dart
// En el switch onTap del receptor:
case 3:
  Navigator.pushReplacementNamed(context, '/receptor_salud');
  break;

// En los items:
BottomNavigationBarItem(icon: Icon(Icons.monitor_heart), label: 'Salud'),
```

**Pantalla receptor salud** (`/receptor_salud` → `ReceptorSaludScreen`):
- **Ejecuta** los sensores y muestra datos en tiempo real
- Navega a sub-pantallas de cada funcionalidad
- Botón de Debug en el AppBar (igual que control remoto)

---

## Mapa de pantallas nuevas

```
/emisor_salud          → EmisorSaludScreen         (hub de tarjetas de datos recibidos)
  /emisor_salud_hr     → EmisorHrScreen             (historial HR + zona + calorías)
  /emisor_salud_pasos  → EmisorPasosScreen          (pasos del día del receptor)
  /emisor_salud_debug  → SaludDebugScreen           (logs compartido emisor/receptor)

/receptor_salud        → ReceptorSaludScreen        (hub de tarjetas + control de sensores)
  /receptor_salud_hr   → ReceptorHrScreen           (HR en vivo + historial + zonas + calorías)
  /receptor_salud_pasos→ ReceptorPasosScreen        (pasos del día, meta, distancia)
  /receptor_brujula    → BrujulaScreen              (aguja animada + grados)
  /receptor_salud_debug→ SaludDebugScreen           (logs compartido emisor/receptor)

/user_body_profile     → UserBodyProfileScreen      (perfil corporal, accesible desde ambos lados)
```

---

## Estructura de cada pantalla hub (Salud)

Ambas pantallas hub (`EmisorSaludScreen` y `ReceptorSaludScreen`) siguen el patrón
de `receptor_settings_screen.dart` — **TabBar desplazable** con la skill `receptor-screen-tabs`.

**Pestañas del receptor:**
- **Corazón** — card HR en vivo + zona + calorías → navega a `/receptor_salud_hr`
- **Pasos** — card pasos del día + barra de progreso → navega a `/receptor_salud_pasos`
- **Brújula** — aguja en miniatura → navega a `/receptor_brujula`
- **Sensores** — estado de cada sensor (activo/pausado), toggle de ForegroundService
- **Perfil** — acceso directo a `/user_body_profile`

**Pestañas del emisor:**
- **Corazón** — última lectura HR recibida → navega a `/emisor_salud_hr`
- **Pasos** — pasos del receptor hoy → navega a `/emisor_salud_pasos`
- **Historial** — resumen del día (total pasos, kcal, tiempo activo)

---

## Pantalla Debug de Salud (`SaludDebugScreen`)

> Patrón idéntico a `remote_debug_screen.dart` — misma estructura, diferente fuente de logs.

**Características obligatorias (igual que el control remoto):**
- Lista de logs en tiempo real con `StreamSubscription`
- Auto-scroll al último log (toggle on/off)
- Filtro de texto en tiempo real
- Botón **Copiar todo** al portapapeles (`Clipboard.setData`)
- Botón **Descargar** como `.txt` con timestamp en el nombre
- Cada log muestra: timestamp · fuente (`hr_monitor`, `step_counter`, `compass`, `proximity`) · mensaje
- Los mismos logs se imprimen por `print()` en la consola de la terminal (visibles en `flutter run`)

**Acceso:**
- Botón de bug (`Icons.bug_report`) en el `AppBar` de `ReceptorSaludScreen` y `EmisorSaludScreen`
- Ruta: `/receptor_salud_debug` y `/emisor_salud_debug` (pueden compartir la misma clase con parámetro)

**Fuente de logs:** `SensorService.debugLogStream` — stream equivalente a
`RemoteControlService.debugLogStream` pero para sensores corporales.

---

## Logs en consola (terminal)

Cada evento relevante de sensores debe imprimirse con `print()` con prefijo de fuente:
```
[sensor][hr_monitor] BPM=72 confidence=3 zona=fat_burn kcal_acum=12.4
[sensor][step_counter] pasos=1423 magnitude=11.2 threshold=10.5 paso_detectado=true
[sensor][compass] azimuth=247.3° cardinal=SO precision=MEDIUM
[sensor][proximity] covered=true → wrist ON → reanudando sensores
[sensor][rotary] delta=+0.31rad accion=scroll
[sensor][foreground_svc] iniciado notif_id=9001
[sensor][foreground_svc] detenido
```

---

## Arquitectura de implementación

```
Android (Kotlin) — archivos a crear/modificar
│
├── LocalNotificationManager.kt          [MODIFICAR — 1 línea]
│   └── private → internal fun wakeUpScreenConservative()
│
├── SensorForegroundService.kt           [CREAR]
│   ├── HeartRateManager      → EventChannel connect/heart_rate
│   ├── StepCounterManager    → EventChannel connect/steps
│   ├── CompassManager        → EventChannel connect/compass
│   ├── ProximityManager      → EventChannel connect/wrist_state
│   └── RotaryEncoderManager  → MethodChannel connect/rotary
│
└── AndroidManifest.xml                  [MODIFICAR]
    └── <uses-permission android:name="android.permission.BODY_SENSORS" />
    └── <service android:name=".SensorForegroundService" android:foregroundServiceType="health" />

Flutter (Dart) — archivos a crear
│
├── services/sensor_service.dart         [CREAR]
│   ├── Abstrae todos los EventChannels de sensores
│   ├── debugLogStream (StreamController broadcast)
│   └── debugLogBuffer (últimos 500 logs)
│
├── screens/shared/user_body_profile_screen.dart  [CREAR]
│
├── screens/receptor/
│   ├── receptor_salud_screen.dart       [CREAR — hub receptor]
│   ├── receptor_hr_screen.dart          [CREAR]
│   ├── receptor_pasos_screen.dart       [CREAR]
│   ├── brujula_screen.dart              [CREAR]
│   └── salud_debug_screen.dart          [CREAR]
│
└── screens/emisor/
    ├── emisor_salud_screen.dart         [CREAR — hub emisor]
    ├── emisor_hr_screen.dart            [CREAR]
    └── emisor_pasos_screen.dart         [CREAR]

Rutas a añadir en main.dart
│
├── '/emisor_salud'          → EmisorSaludScreen
├── '/emisor_salud_hr'       → EmisorHrScreen
├── '/emisor_salud_pasos'    → EmisorPasosScreen
├── '/emisor_salud_debug'    → SaludDebugScreen(side: 'emisor')
├── '/receptor_salud'        → ReceptorSaludScreen
├── '/receptor_salud_hr'     → ReceptorHrScreen
├── '/receptor_salud_pasos'  → ReceptorPasosScreen
├── '/receptor_brujula'      → BrujulaScreen
├── '/receptor_salud_debug'  → SaludDebugScreen(side: 'receptor')
└── '/user_body_profile'     → UserBodyProfileScreen

Modificaciones en archivos existentes
│
├── emisor_screen.dart       → añadir ítem Salud al BottomNavigationBar (índice 3)
├── conexion_screen.dart     → añadir ítem Salud al BottomNavigationBar (índice 3)
├── settings_screen.dart     → añadir acceso a /user_body_profile
├── receptor_settings_screen.dart → añadir acceso a /user_body_profile
└── main.dart                → registrar todas las rutas nuevas
```

---

## Protocolo BT emisor ↔ receptor (sensor data)

Añadir al canal BT existente (`BtClassicServerService`) los prefijos:

```
HR:85             → frecuencia cardíaca 85 BPM
HR_ZONA:fat_burn  → zona de entrenamiento activa
KCAL:12.4         → calorías acumuladas en la sesión
STEPS:4231        → pasos acumulados hoy
DIST:1842         → distancia en metros
WRIST:ON          → reloj puesto en muñeca
WRIST:OFF         → reloj quitado
ROTARY:+0.31      → delta corona giratoria en radianes
HR_ALERT:HIGH:134 → alerta BPM alto (134 BPM)
HR_ALERT:LOW:44   → alerta BPM bajo
```

---

## Dependencias Flutter a añadir

| Paquete | Estado | Para qué |
|---|---|---|
| `hive` + `hive_flutter` | ✅ Ya en el proyecto | Historial HR, pasos, zonas |
| `firebase_firestore` | ✅ Ya en el proyecto | Sincronización opcional |
| `sensors_plus` | ➕ Evaluar | Acelerómetro/magnetómetro desde Dart (alternativa al canal nativo) |
| `fl_chart` | ➕ Añadir | Gráficas de HR y pasos |
| Canal nativo propio | ✅ Infraestructura ya existe | HEART_RATE, PROXIMITY, ROTARY (no en `sensors_plus`) |

> `sensors_plus` cubre acelerómetro y magnetómetro, pero **no** type=8, type=21 ni type=36.
> Esos tres requieren canal nativo sin excepción.

---

## Checklist de implementación

### Fase 1 — Base
- [ ] Cambiar `private → internal` en `LocalNotificationManager.wakeUpScreenConservative`
- [ ] Crear `SensorForegroundService.kt` con `HeartRateManager` y `ProximityManager`
- [ ] Crear `sensor_service.dart` con stream de debug
- [ ] Crear `UserBodyProfileScreen` y ruta `/user_body_profile`
- [ ] Añadir `BODY_SENSORS` en `AndroidManifest.xml`
- [ ] Añadir ítem Salud al `BottomNavigationBar` del emisor y receptor
- [ ] Registrar todas las rutas en `main.dart`

### Fase 2 — Pantallas hub y HR
- [ ] Crear `ReceptorSaludScreen` (hub con TabBar)
- [ ] Crear `EmisorSaludScreen` (hub con TabBar, solo lectura)
- [ ] Crear `ReceptorHrScreen` con gráfica HR + zonas + calorías
- [ ] Crear `EmisorHrScreen` con datos recibidos por BT
- [ ] Añadir protocolo BT `HR:xx` y `HR_ZONA:xx` en `BtClassicServerService`

### Fase 3 — Pasos y brújula
- [ ] Añadir `StepCounterManager` al `SensorForegroundService`
- [ ] Crear `ReceptorPasosScreen` con contador, barra de progreso y distancia
- [ ] Crear `EmisorPasosScreen` con datos recibidos por BT
- [ ] Añadir `CompassManager` y crear `BrujulaScreen`

### Fase 4 — Corona y debug
- [ ] Añadir `RotaryEncoderManager` (scroll en lista de notificaciones)
- [ ] Crear `SaludDebugScreen` (patrón `RemoteDebugScreen`)
- [ ] Verificar logs en terminal con prefijos `[sensor][*]`
- [ ] `flutter analyze` → 0 errores en todos los archivos nuevos
