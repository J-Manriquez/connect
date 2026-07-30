# Mejoras de sensores del receptor — Plan para implementación

> Contexto: app Flutter + Android nativo (Kotlin). Dispositivo receptor: **ULTRA Ai 3**
> (Android 8.1, SDK 27, arm64-v8a). La brújula y el sensor de muñeca (proximidad)
> **ya fueron eliminados** del código. Este documento describe lo que queda por implementar.

---

## Estado actual del código (punto de partida)

### Archivos Kotlin relevantes

| Archivo | Ruta | Estado |
|---|---|---|
| `SensorForegroundService.kt` | `android/app/src/main/kotlin/com/example/connect/` | Existente — tiene HR y pedómetro. Brújula y proximidad ya eliminados. |
| `MainActivity.kt` | misma carpeta | Existente — registra canales EventChannel/MethodChannel |
| `BtClassicServerService.kt` | misma carpeta | Existente — envía JSON al emisor |

### Archivos Dart relevantes

| Archivo | Ruta | Estado |
|---|---|---|
| `sensor_service.dart` | `lib/services/` | Existente — streams `heartRateStream`, `stepsStream`, logs de debug |
| `receptor_salud_screen.dart` | `lib/screens/receptor/` | Existente — hub con tabs: Sensores, Corazón, Pasos |
| `receptor_hr_screen.dart` | `lib/screens/receptor/` | Existente — muestra BPM en vivo, zonas, calorías (sesión) |
| `receptor_pasos_screen.dart` | `lib/screens/receptor/` | Existente — contador circular con barra de progreso |
| `preferences_service.dart` | `lib/services/` | Existente — `getBodyProfile()` devuelve `age, weight_kg, sex, height_cm, steps_goal, fc_max, hr_alert_high, hr_alert_low` |
| `main.dart` | `lib/` | Rutas ya registradas: `/receptor_salud`, `/receptor_salud_hr`, `/receptor_salud_pasos`, `/receptor_salud_debug` |

### Canales nativos existentes

| Canal | Tipo | Descripción |
|---|---|---|
| `connect/heart_rate` | EventChannel | `{ bpm: int, confidence: int, timestamp: int }` |
| `connect/steps` | EventChannel | `{ steps: int, distancia_m: int, timestamp: int }` |
| `connect/sensor_debug` | EventChannel | `{ source: String, message: String, timestamp: int }` |
| `connect/rotary` | MethodChannel | `rotaryDelta` → double |
| `connect/sensor_service` | MethodChannel | `start` / `stop` |

---

## Cambio 1 — Algoritmo de pedómetro mejorado

**Problema:** El algoritmo actual cuenta cualquier movimiento de brazo como paso.
Detecta pico cuando `media_móvil(magnitud) > 10.5` — umbral demasiado bajo y sin
filtrado de frecuencia.

**Archivo a modificar:** `android/app/src/main/kotlin/com/example/connect/SensorForegroundService.kt`

**Algoritmo nuevo (reemplazar la lógica del `accelListener`):**

```
Paso 1 — Preprocesado
  magnitude_raw = sqrt(x²+y²+z²)
  Quitar gravedad: aplicar filtro paso-alto
    gravity[i] = 0.8 * gravity[i-1] + 0.2 * magnitude_raw
    linear = magnitude_raw - gravity_actual

Paso 2 — Suavizado
  Filtro de media móvil sobre `linear` con ventana de 5 muestras

Paso 3 — Detección de pico
  Un paso ocurre cuando:
    a) linear_suavizado supera THRESHOLD (= 2.0 m/s² sobre gravedad eliminada)
    b) Llevaba al menos MIN_STEP_INTERVAL ms desde el último paso (= 400 ms)
    c) La amplitud pico-a-valle en la ventana es ≥ AMPLITUDE_MIN (= 1.5 m/s²)

Paso 4 — Anti-rebote de frecuencia
  Ventana deslizante de 3 segundos: si se detectan > 6 pasos en 3 s
  → probablemente vibración, descartarlos y reiniciar ventana
```

**Constantes nuevas a usar en Kotlin:**

```kotlin
private val STEP_THRESHOLD = 2.0f          // m/s² (sobre gravedad eliminada)
private val MIN_STEP_INTERVAL_MS = 400L    // ms mínimos entre pasos
private val AMPLITUDE_MIN = 1.5f           // m/s² amplitud mínima pico-valle
private val SMOOTHING_WINDOW = 5           // muestras para media móvil
private val ANTI_BOUNCE_WINDOW_MS = 3000L  // ventana anti-rebote
private val ANTI_BOUNCE_MAX_STEPS = 6      // máx pasos en la ventana

// Variables de estado a añadir
private var gravityEst = 9.8f
private val linearBuffer = FloatArray(5) { 0f }
private var linearIdx = 0
private var lastLinearPeak = 0f
private var lastLinearValley = Float.MAX_VALUE
private var antiBounceCount = 0
private var antiBounceWindowStart = 0L
```

**Lógica completa del listener (sustituir el body de `onSensorChanged` del accelListener):**

```kotlin
val x = event.values[0]; val y = event.values[1]; val z = event.values[2]
val raw = sqrt((x*x + y*y + z*z).toDouble()).toFloat()

// Eliminar gravedad con filtro paso-alto
gravityEst = 0.8f * gravityEst + 0.2f * raw
val linear = raw - gravityEst

// Suavizar
linearBuffer[linearIdx % SMOOTHING_WINDOW] = linear
linearIdx++
val smooth = linearBuffer.average().toFloat()

val nowMs = System.currentTimeMillis()
checkDayReset(nowMs)

// Rastrear amplitud pico-valle
if (smooth > lastLinearPeak) lastLinearPeak = smooth
if (smooth < lastLinearValley) lastLinearValley = smooth
val amplitude = lastLinearPeak - lastLinearValley

// Detectar paso: cruce descendente del umbral
if (wasAboveThreshold && smooth < STEP_THRESHOLD) {
    // Resetear tracking de amplitud para el próximo ciclo
    lastLinearPeak = smooth
    lastLinearValley = smooth
}

val isAbove = smooth > STEP_THRESHOLD
if (isAbove && !wasAboveThreshold
    && (nowMs - lastStepMs) > MIN_STEP_INTERVAL_MS
    && amplitude >= AMPLITUDE_MIN) {

    // Anti-rebote de frecuencia
    if (nowMs - antiBounceWindowStart > ANTI_BOUNCE_WINDOW_MS) {
        antiBounceWindowStart = nowMs
        antiBounceCount = 0
    }
    antiBounceCount++
    if (antiBounceCount <= ANTI_BOUNCE_MAX_STEPS) {
        stepsToday++
        lastStepMs = nowMs
        val dist = (stepsToday * 0.415 * getUserHeight() / 100.0).toInt()
        val payload = mapOf("steps" to stepsToday, "distancia_m" to dist, "timestamp" to nowMs)
        mainHandler.post { stepsSink?.success(payload) }
        log("step_counter", "paso=$stepsToday smooth=${"%.2f".format(smooth)} ampl=${"%.2f".format(amplitude)}")
        if (stepsToday % 100 == 0) sendSensorDataToBt(steps = stepsToday, distM = dist)
    } else {
        log("step_counter", "anti-rebote: descartando paso (${antiBounceCount} en 3s)")
    }
    lastLinearPeak = 0f
    lastLinearValley = Float.MAX_VALUE
}
wasAboveThreshold = isAbove
```

---

## Cambio 2 — Persistencia de datos HR en Hive + pantalla de historial

**Situación actual:** `receptor_hr_screen.dart` muestra BPM en tiempo real e historial
de la sesión en RAM (se pierde al cerrar). No guarda nada a disco.

**Lo que hay que implementar:**

### 2a. Guardar lecturas HR en Hive

**Archivo a modificar:** `lib/screens/receptor/receptor_hr_screen.dart`

Hive ya está en el proyecto. En el `_onHr()` existente, tras actualizar el estado,
guardar en la box `'hr_log'`:

```dart
// Añadir imports
import 'package:hive_flutter/hive_flutter.dart';

// En initState / _load(), abrir la box:
await Hive.openBox('hr_log');

// En _onHr(), al final:
final box = Hive.box('hr_log');
box.add({
  'timestamp': DateTime.now().millisecondsSinceEpoch,
  'bpm': data.bpm,
  'zona': zona,
  'kcal_acum': _kcalSession,
});
// Limitar a 1440 entradas (≈ 24 h a 1 lectura/min)
if (box.length > 1440) box.deleteAt(0);
```

### 2b. Pantalla de historial del día

**Archivo nuevo:** `lib/screens/receptor/receptor_hr_history_screen.dart`

**Ruta nueva a registrar en `main.dart`:** `/receptor_hr_history`

**Acceso:** botón de historial (`Icons.history`) en el `AppBar` de `receptor_hr_screen.dart`

**Contenido de la pantalla:**
- Título: "Historial HR — hoy"
- Card superior: BPM mínimo, máximo y promedio del día (calcular desde la box)
- Gráfica de barras simple (igual al histograma de sesión actual en `receptor_hr_screen.dart`
  pero leyendo todas las entradas de la box de hoy, agrupadas por hora)
- Lista scrolleable de entradas: hora · BPM · zona (dot de color) · kcal acumuladas
- Botón "Borrar historial del día" con confirmación `showDialog`

**Leer datos:**
```dart
final box = Hive.box('hr_log');
final hoy = DateTime.now();
final entradas = box.values
    .cast<Map>()
    .where((e) {
      final ts = DateTime.fromMillisecondsSinceEpoch(e['timestamp'] as int);
      return ts.year == hoy.year && ts.month == hoy.month && ts.day == hoy.day;
    })
    .toList()
  ..sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));
```

**También guardar pasos en Hive** (modificar `receptor_pasos_screen.dart`):
En el listener de `stepsStream`, al recibir datos:
```dart
final box = Hive.box('steps_log');
// Guardar solo 1 vez por minuto (comparar timestamp con última entrada)
final ultima = box.isNotEmpty ? box.getAt(box.length - 1) as Map : null;
final ahora = DateTime.now().millisecondsSinceEpoch;
if (ultima == null || ahora - (ultima['timestamp'] as int) > 60000) {
  box.add({ 'timestamp': ahora, 'steps': data.steps, 'distancia_m': data.distanciaM });
}
```
Y abrir la box en `_load()`: `await Hive.openBox('steps_log');`

---

## Cambio 3 — Calorías estimadas a partir de los pasos

**Archivo a modificar:** `lib/screens/receptor/receptor_pasos_screen.dart`

**Fórmula:** `kcal ≈ pasos × MET_factor`

```
MET por pasos (aproximación):
  kcal = pasos × 0.0005 × peso_kg
  (equivale a caminar a ritmo normal: ~0.04 kcal/paso para 80 kg)
```

**Qué añadir:**
1. En `_load()`, leer también `weight_kg` del perfil corporal.
2. Calcular `_kcalSteps = _steps * 0.0005 * _pesoKg` cada vez que se actualicen los pasos.
3. Añadir una card de calorías bajo la card de distancia/zancada existente:

```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
        const SizedBox(height: 4),
        const Text('Calorías estimadas',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        Text(
          '${_kcalSteps.toStringAsFixed(1)} kcal',
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        const Text('(basado en pasos y peso)',
            style: TextStyle(fontSize: 11, color: Colors.black45)),
      ],
    ),
  ),
),
```

---

## Cambio 4 — Sección de ejercicios

### 4a. Pantalla hub de ejercicios

**Archivo nuevo:** `lib/screens/receptor/receptor_ejercicios_screen.dart`

**Ruta nueva en `main.dart`:** `/receptor_ejercicios`

**Acceso:** añadir una card/botón en `receptor_salud_screen.dart` tab "Sensores"
(después del OutlinedButton de "Perfil corporal"):

```dart
const SizedBox(height: 8),
ElevatedButton.icon(
  icon: const Icon(Icons.fitness_center),
  label: const Text('Ejercicios'),
  onPressed: () => Navigator.pushNamed(context, '/receptor_ejercicios'),
),
```

**Contenido de la pantalla `receptor_ejercicios_screen.dart`:**

Layout: `ListView` con una card por ejercicio. Cada card tiene:
- Nombre del ejercicio e ícono
- Descripción breve (1 línea)
- Contador de series/repeticiones con botones `+` y `-`
- Calorías estimadas en tiempo real según las repeticiones ingresadas
- Botón "Guardar sesión"

**Lista de ejercicios base (hardcoded, no requiere backend):**

```dart
const _ejercicios = [
  _Ejercicio(
    nombre: 'Flexiones',
    icon: Icons.fitness_center,
    kcalPorRep: 0.35,   // kcal por repetición (persona 70 kg)
    descripcion: 'Brazos separados al ancho de hombros, bajar hasta 90°',
  ),
  _Ejercicio(
    nombre: 'Sentadillas',
    icon: Icons.accessibility_new,
    kcalPorRep: 0.32,
    descripcion: 'Pies al ancho de caderas, bajar hasta muslos paralelos al suelo',
  ),
  _Ejercicio(
    nombre: 'Abdominales',
    icon: Icons.self_improvement,
    kcalPorRep: 0.24,
    descripcion: 'Manos en la nuca, elevar el torso hasta 45°',
  ),
  _Ejercicio(
    nombre: 'Burpees',
    icon: Icons.directions_run,
    kcalPorRep: 0.90,
    descripcion: 'Desde parado: sentadilla → plancha → flexión → salto',
  ),
  _Ejercicio(
    nombre: 'Zancadas',
    icon: Icons.transfer_within_a_station,
    kcalPorRep: 0.30,
    descripcion: 'Un paso adelante, bajar la rodilla trasera sin tocar el suelo',
  ),
  _Ejercicio(
    nombre: 'Plancha',
    icon: Icons.horizontal_rule,
    kcalPorSegundo: 0.07,  // plancha se mide en segundos, no reps
    esTiempo: true,
    descripcion: 'Apoyar antebrazos y puntas de pies, mantener cuerpo recto',
  ),
  _Ejercicio(
    nombre: 'Mountain climbers',
    icon: Icons.terrain,
    kcalPorRep: 0.15,
    descripcion: 'Desde plancha, alternar rodillas al pecho rápidamente',
  ),
  _Ejercicio(
    nombre: 'Saltos de tijera',
    icon: Icons.open_with,
    kcalPorRep: 0.20,
    descripcion: 'Jumping jacks: salto separando piernas y juntando manos arriba',
  ),
];
```

**Modelo de datos:**

```dart
class _Ejercicio {
  final String nombre;
  final IconData icon;
  final String descripcion;
  final double kcalPorRep;     // 0 si esTiempo
  final double kcalPorSegundo; // 0 si no esTiempo
  final bool esTiempo;

  const _Ejercicio({
    required this.nombre,
    required this.icon,
    required this.descripcion,
    this.kcalPorRep = 0,
    this.kcalPorSegundo = 0,
    this.esTiempo = false,
  });
}
```

**Estado de cada ejercicio en pantalla:**

```dart
// Mapa de contadores: nombre → {series, reps, segundos}
final Map<String, Map<String, int>> _contadores = {};

// Inicializar en initState:
for (final e in _ejercicios) {
  _contadores[e.nombre] = {'series': 0, 'reps': 0, 'segundos': 0};
}

// Total de kcal de la sesión:
double get _totalKcal {
  double total = 0;
  for (final e in _ejercicios) {
    final c = _contadores[e.nombre]!;
    if (e.esTiempo) {
      total += e.kcalPorSegundo * (c['segundos'] ?? 0);
    } else {
      total += e.kcalPorRep * (c['series'] ?? 0) * (c['reps'] ?? 0);
    }
  }
  return total;
}
```

**Card de ejercicio (widget helper `_EjercicioCard`):**

```dart
// Para ejercicios por repetición: mostrar "Series" y "Reps por serie"
// Para ejercicios por tiempo (plancha): mostrar "Segundos"
// Botones: [-] [valor] [+]  para cada campo
// Mostrar kcal del ejercicio: kcalPorRep * series * reps (o kcalPorSeg * segs)
```

**Botón "Guardar sesión"** (flotante, `FloatingActionButton`):
- Guardar en Hive box `'ejercicios_log'`:
  ```dart
  Hive.box('ejercicios_log').add({
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'kcal_total': _totalKcal,
    'detalle': _contadores,   // serializar como Map<String, dynamic>
  });
  ```
- Abrir box en `initState`: `await Hive.openBox('ejercicios_log');`
- Mostrar `SnackBar` de confirmación tras guardar
- Resetear todos los contadores a 0

**Header de la pantalla:** card fija (no scrolleable, fuera del ListView) que muestra
el total de kcal de la sesión actual, actualizado en tiempo real:

```dart
// Encima del ListView:
Card(
  color: Colors.orange.shade50,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.local_fire_department, color: Colors.orange),
        const SizedBox(width: 8),
        Text('Sesión actual: ${_totalKcal.toStringAsFixed(1)} kcal',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    ),
  ),
),
```

---

## Resumen de archivos a crear/modificar

### Crear (archivos nuevos)

| Archivo | Descripción |
|---|---|
| `lib/screens/receptor/receptor_hr_history_screen.dart` | Historial HR del día desde Hive |
| `lib/screens/receptor/receptor_ejercicios_screen.dart` | Sección de ejercicios con contador de kcal |

### Modificar (archivos existentes)

| Archivo | Qué cambiar |
|---|---|
| `android/app/src/main/kotlin/com/example/connect/SensorForegroundService.kt` | Reemplazar algoritmo del `accelListener` con el nuevo (Cambio 1) |
| `lib/screens/receptor/receptor_hr_screen.dart` | Añadir persistencia en Hive (Cambio 2a) + botón de historial en AppBar |
| `lib/screens/receptor/receptor_pasos_screen.dart` | Añadir kcal por pasos (Cambio 3) + persistencia en Hive (Cambio 2b) |
| `lib/screens/receptor/receptor_salud_screen.dart` | Añadir botón de acceso a ejercicios en tab Sensores (Cambio 4a) |
| `lib/main.dart` | Registrar rutas `/receptor_hr_history` y `/receptor_ejercicios` + imports |

### Rutas a añadir en `main.dart`

```dart
// Imports:
import 'package:connect/screens/receptor/receptor_hr_history_screen.dart';
import 'package:connect/screens/receptor/receptor_ejercicios_screen.dart';

// En el mapa de rutas:
'/receptor_hr_history':   (context) => const ReceptorHrHistoryScreen(),
'/receptor_ejercicios':   (context) => const ReceptorEjerciciosScreen(),
```

---

## Dependencias Flutter

`hive` y `hive_flutter` **ya están en el proyecto** — no agregar nada a `pubspec.yaml`.

---

## Notas de arquitectura

- Los factores `kcalPorRep` de los ejercicios están calibrados para una persona de ~70 kg.
  Para mayor precisión, multiplicar por `peso_real / 70.0` usando el perfil corporal
  (`PreferencesService.getBodyProfile()` → `weight_kg`). Esto es una mejora opcional.
- El historial de HR y pasos en Hive solo guarda el día actual. No implementar
  historial multi-día en esta fase — sería un Cambio 5 futuro.
- Los boxes de Hive (`hr_log`, `steps_log`, `ejercicios_log`) no requieren adaptadores
  TypeAdapter porque se usan como `Map<dynamic, dynamic>` sin clases generadas.
- No tocar `SensorService.dart` ni los canales EventChannel para ninguno de estos cambios.
