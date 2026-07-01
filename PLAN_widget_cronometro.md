# Plan de implementación — Widget Cronómetro + Temporizador

> Proyecto: **connect** · Rama sugerida: `feature/stopwatch-timer-widget`
> Nivel de producto: completo (no MVP). Sigue los estándares de
> `flutter-home-screen-widgets`, `customization-detail-standard` y
> `connect-widgets-integration`.

---

## 1. Resumen del producto

Se implementa un **widget de pantalla de inicio** que combina cronómetro y
temporizador. El cronómetro corre en un **ForegroundService** nativo y sigue
activo aunque la app esté cerrada. Hay **3 estilos de widget** (compacto, con
vueltas, circular). La configuración visual sigue el listón de la bola flotante:
cada color, tamaño, icono, espaciado y margen es ajustable por el usuario con
preview en vivo. El sonido y la vibración son configurables por separado para
el fin del temporizador y para cada vuelta del cronómetro, con posibilidad de
seleccionar un audio local.

---

## 2. Arquitectura

```
┌────────────────── Flutter ──────────────────────────────────────┐
│ StopwatchTimerScreen   StopwatchWidgetListScreen                 │
│    (UI en app)             → StopwatchWidgetEditorScreen         │
│       │  setState                  │ setState                    │
│       ▼                            ▼                             │
│ StopwatchTimerService      StopwatchWidgetConfigService          │
│  (lógica Flutter)            (persistencia de estilo)            │
│     MethodChannel                MethodChannel                   │
│   "stopwatch_start/              "updateStopwatchWidget"         │
│    pause/reset/lap/              → Style1/2/3.updateAll()        │
│    set_timer/getState"                                           │
└────────────────────────┬────────────────────────────────────────┘
    SharedPreferences     │  BroadcastIntent (acciones del widget)
  "FlutterSharedPrefs"   │
┌────────────────────────▼────────────────────────────────────────┐
│              Android Nativo                                      │
│  StopwatchTimerFgService   StopwatchWidgetProvider (base)        │
│   (ForegroundService)       + ProviderStyle1/2/3                 │
│   Handler ticks 50 ms       buildRemoteViews()                   │
│   ↕ escribe estado          readWidgetCfg() + readState()        │
│   ↕ SharedPreferences       PendingIntents → onReceive()         │
│   Notification con          → sendBroadcast a Service            │
│   play/pause action                                              │
│   MediaPlayer (sonido)      widget_stopwatch_style1/2/3.xml      │
│   Vibrator (vibración)      stopwatch_widget_info_style1/2/3.xml │
└─────────────────────────────────────────────────────────────────┘
```

### Decisiones de diseño

| Decisión | Justificación |
|---|---|
| ForegroundService nativo | El cronómetro debe seguir corriendo con la app cerrada; un servicio Flutter no garantiza esto en Android |
| Estado en SharedPreferences | Canal único de verdad entre servicio nativo, widget y Flutter |
| MethodChannel para acciones | Flutter controla el servicio pero no lo "posee"; el servicio vive en Kotlin |
| Sonido en el servicio | Cuando termina el temporizador la app puede estar cerrada; el servicio tiene contexto |
| 3 estilos independientes | Siguen el mismo patrón que los 3 estilos de música; cada uno tiene su `WidgetConfigSpec` |

---

## 3. Inventario completo de archivos

### Archivos a crear

#### Flutter
| # | Ruta | Descripción |
|---|---|---|
| F1 | `lib/services/stopwatch_timer_service.dart` | Lógica Flutter + puente MethodChannel |
| F2 | `lib/services/stopwatch_widget_config_service.dart` | Modelo + persistencia de estilos |
| F3 | `lib/widgets/stopwatch_widget_preview.dart` | Preview en vivo (replica RemoteViews) |
| F4 | `lib/screens/emisor/stopwatch_timer_screen.dart` | Pantalla principal en-app |
| F5 | `lib/screens/emisor/stopwatch_widget_list_screen.dart` | Lista de 3 estilos |
| F6 | `lib/screens/emisor/stopwatch_widget_editor_screen.dart` | Editor de estilo con tabs |

#### Android nativo (Kotlin)
| # | Ruta | Descripción |
|---|---|---|
| N1 | `android/.../StopwatchTimerFgService.kt` | ForegroundService principal |
| N2 | `android/.../StopwatchWidgetProvider.kt` | Base + 3 subclases de widget |

#### Android nativo (recursos)
| # | Ruta | Descripción |
|---|---|---|
| R1 | `res/layout/widget_stopwatch_style1.xml` | Estilo 1: compacto (2×1) |
| R2 | `res/layout/widget_stopwatch_style2.xml` | Estilo 2: con vueltas (2×3) |
| R3 | `res/layout/widget_stopwatch_style3.xml` | Estilo 3: circular (2×2) |
| R4 | `res/xml/stopwatch_widget_info_style1.xml` | AppWidget provider info estilo 1 |
| R5 | `res/xml/stopwatch_widget_info_style2.xml` | AppWidget provider info estilo 2 |
| R6 | `res/xml/stopwatch_widget_info_style3.xml` | AppWidget provider info estilo 3 |

### Archivos a modificar

| Archivo | Qué se añade |
|---|---|
| `android/app/src/main/AndroidManifest.xml` | Service `StopwatchTimerFgService` + 3 receivers de widget |
| `android/.../MainActivity.kt` | Nuevo canal `STOPWATCH_CHANNEL` + handlers de acciones |
| `lib/main.dart` | Rutas `/stopwatch_widget` y `/stopwatch_timer` |
| `lib/screens/emisor/settings_screen.dart` | Tile "Cronómetro y Temporizador" debajo de "Widgets" |

---

## 4. Fase 1 — Servicio de fondo nativo (N1)

**Archivo:** `StopwatchTimerFgService.kt`

### Responsabilidades
- Mantener el cronómetro/temporizador corriendo con Handler + Runnable (tick cada 50 ms)
- Escribir el estado en `SharedPreferences("FlutterSharedPreferences")` en cada tick
- Emitir `LocalBroadcast` con action `STOPWATCH_TICK` para que el widget se repinte
- Mostrar notificación persistente con el tiempo actual y botón Play/Pause
- Al finalizar el temporizador: reproducir sonido (MediaPlayer) + vibrar (Vibrator)
- Responder a intents de acción: `ACTION_START`, `ACTION_PAUSE`, `ACTION_RESET`,
  `ACTION_LAP`, `ACTION_SET_TIMER`, `ACTION_SET_MODE`

### Constantes (companion object)
```kotlin
const val ACTION_START          = "com.example.connect.stopwatch.START"
const val ACTION_PAUSE          = "com.example.connect.stopwatch.PAUSE"
const val ACTION_RESET          = "com.example.connect.stopwatch.RESET"
const val ACTION_LAP            = "com.example.connect.stopwatch.LAP"
const val ACTION_SET_TIMER      = "com.example.connect.stopwatch.SET_TIMER"
const val ACTION_SET_MODE       = "com.example.connect.stopwatch.SET_MODE"
const val ACTION_TICK_BROADCAST = "com.example.connect.stopwatch.TICK"
const val EXTRA_TIMER_DURATION  = "timer_duration_ms"
const val EXTRA_MODE            = "mode"           // "stopwatch" | "timer"
const val NOTIF_ID              = 9201
const val NOTIF_CHANNEL_ID      = "stopwatch_timer"
```

### Lógica de tick
```
state == "running", mode == "stopwatch":
  elapsed = accumulated + (System.currentTimeMillis() - startEpoch)
  writeState(elapsed)
  broadcastTick()

state == "running", mode == "timer":
  remaining = timerTarget - (System.currentTimeMillis() - startEpoch)
  if (remaining <= 0): finish()
  else: writeState(remaining)  // guarda como stopwatch_timer_remaining
  broadcastTick()
```

### Escritura en SharedPreferences
Clave con prefijo `flutter.` (patrón del proyecto):
```kotlin
val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
prefs.edit()
    .putString("flutter.stopwatch_state", state)
    .putString("flutter.stopwatch_mode", mode)
    .putLong("flutter.stopwatch_start_epoch", startEpoch)
    .putLong("flutter.stopwatch_accumulated", accumulated)
    .putString("flutter.stopwatch_laps_json", lapsJson)
    .putLong("flutter.stopwatch_timer_target", timerTarget)
    .putLong("flutter.stopwatch_timer_remaining", remaining)
    .apply()
```

### Sonido al terminar el temporizador
```kotlin
fun playFinishSound(context: Context) {
    val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
    val soundEnabled = readFlutterBool(prefs, "flutter.stopwatch_sound_enabled", true)
    if (!soundEnabled) return
    val uri = prefs.getString("flutter.stopwatch_sound_uri", "")
    val player = MediaPlayer()
    if (uri.isNullOrEmpty()) {
        // Sonido por defecto del sistema (EFFECT_TICK o un raw resource)
        player.setDataSource(context, android.provider.Settings.System.DEFAULT_RINGTONE_URI)
    } else {
        player.setDataSource(context, Uri.parse(uri))
    }
    player.setOnCompletionListener { it.release() }
    player.prepare()
    player.start()
}
```

### Vibración al terminar
```kotlin
fun vibrate(context: Context) {
    val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
    if (!readFlutterBool(prefs, "flutter.stopwatch_vibration_enabled", true)) return
    val vibrator = context.getSystemService(VIBRATOR_SERVICE) as Vibrator
    val patternJson = prefs.getString("flutter.stopwatch_vibration_pattern", "")
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val effect = if (!patternJson.isNullOrEmpty()) parseVibrationEffect(patternJson)
                     else VibrationEffect.createOneShot(600, VibrationEffect.DEFAULT_AMPLITUDE)
        vibrator.vibrate(effect)
    } else {
        vibrator.vibrate(600)
    }
}
```

### Vuelta (lap) — sonido/vibración opcional
```kotlin
fun onLap() {
    // añade lap al JSON
    val prefs = ...
    if (readFlutterBool(prefs, "flutter.stopwatch_lap_vibrate", false)) vibrateShort()
    if (readFlutterBool(prefs, "flutter.stopwatch_lap_sound",   false)) playLapSound()
}
```

---

## 5. Fase 2 — Widget nativo (N2 + R1-R6)

**Archivo:** `StopwatchWidgetProvider.kt`

### Estructura Kotlin

```kotlin
abstract class BaseStopwatchWidgetProvider : AppWidgetProvider() {
    protected abstract val layoutResId: Int

    override fun onUpdate(...) = updateAppWidgets(...)
    override fun onReceive(context, intent) {
        when (intent.action) {
            ACTION_START_PAUSE -> toggleStartPause(context)   // envía intent al service
            ACTION_RESET       -> resetService(context)
            ACTION_LAP         -> lapService(context)
            ACTION_OPEN_APP    -> openApp(context)
            ACTION_TOGGLE_MODE -> toggleMode(context)
        }
        updateAll(context)
    }

    companion object {
        fun readState(prefs): StopwatchState { ... }
        fun readWidgetCfg(prefs, id): StopwatchWidgetCfg { ... }   // defaults espejo
        fun buildRemoteViews(context, cfg, state, layoutResId): RemoteViews { ... }
        fun drawRing(radiusPx, trackArgb, fillArgb, thicknessPx, progress): Bitmap { ... }
    }
}

class StopwatchWidgetProviderStyle1 : BaseStopwatchWidgetProvider() {
    override val layoutResId = R.layout.widget_stopwatch_style1
    companion object { fun updateAll(context: Context) { ... } }
}
class StopwatchWidgetProviderStyle2 : BaseStopwatchWidgetProvider() {
    override val layoutResId = R.layout.widget_stopwatch_style2
    companion object { fun updateAll(context: Context) { ... } }
}
class StopwatchWidgetProviderStyle3 : BaseStopwatchWidgetProvider() {
    override val layoutResId = R.layout.widget_stopwatch_style3
    companion object { fun updateAll(context: Context) { ... } }
}
```

### Acciones de botones (PendingIntent broadcast)
```kotlin
// Cada botón en el RemoteViews:
val toggleIntent = Intent(context, StopwatchWidgetProviderStyle1::class.java).apply {
    action = ACTION_START_PAUSE
}
views.setOnClickPendingIntent(R.id.btn_start_pause,
    PendingIntent.getBroadcast(context, 0, toggleIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
```

### buildRemoteViews — lógica por estilo

**Style 1 (compacto):** Muestra solo el tiempo formateado + botón play/pause + botón reset.

**Style 2 (con vueltas):** Muestra tiempo + hasta N vueltas recientes (N configurable 1-5) +
botones play/pause/reset/lap + toggle de modo (cronómetro/temporizador) + si es timer
muestra barra de progreso lineal.

**Style 3 (circular):** Dibuja un `Bitmap` de anillo de progreso via `Canvas`:
- Para cronómetro: progreso = vuelta actual / media de vueltas (o lap actual / 60 s)
- Para temporizador: progreso = remaining / total
Muestra el tiempo centrado sobre el anillo con `setImageViewBitmap`.

### Layouts XML (RemoteViews — solo views permitidas)

**R1 — `widget_stopwatch_style1.xml`** (minWidth 110dp, minHeight 50dp)
```xml
LinearLayout (horizontal, fill)
  ├── TextView  id="sw_time"           (tiempo principal)
  ├── ImageButton id="btn_start_pause" (play/pause)
  └── ImageButton id="btn_reset"       (reset)
```

**R2 — `widget_stopwatch_style2.xml`** (minWidth 110dp, minHeight 200dp)
```xml
LinearLayout (vertical, fill)
  ├── TextView  id="sw_time"           (tiempo principal)
  ├── TextView  id="sw_mode_label"     ("CRONÓMETRO" | "TEMPORIZADOR")
  ├── ProgressBar id="sw_timer_bar"    (solo visible en modo timer)
  ├── LinearLayout id="sw_laps_container"
  │     ├── TextView id="sw_lap_1"
  │     ├── TextView id="sw_lap_2"
  │     └── TextView id="sw_lap_3"   (hasta 5, visibilidad controlada)
  └── LinearLayout (horizontal) - botones
        ├── ImageButton id="btn_start_pause"
        ├── ImageButton id="btn_reset"
        ├── ImageButton id="btn_lap"
        └── ImageButton id="btn_toggle_mode"
```

**R3 — `widget_stopwatch_style3.xml`** (minWidth 110dp, minHeight 110dp)
```xml
FrameLayout
  ├── ImageView id="sw_ring"       (Bitmap del anillo dibujado en Kotlin)
  ├── TextView  id="sw_time"       (centrado sobre el anillo)
  └── LinearLayout (botones abajo)
        ├── ImageButton id="btn_start_pause"
        └── ImageButton id="btn_reset"
```

### Info XMLs (R4-R6)
```xml
<!-- stopwatch_widget_info_style1.xml -->
<appwidget-provider
    android:initialLayout="@layout/widget_stopwatch_style1"
    android:minWidth="110dp"
    android:minHeight="50dp"
    android:minResizeWidth="80dp"
    android:minResizeHeight="40dp"
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="0"
    android:widgetCategory="home_screen" />

<!-- stopwatch_widget_info_style2.xml -->
<!-- minHeight="200dp", mismos demás atributos -->

<!-- stopwatch_widget_info_style3.xml -->
<!-- minWidth="110dp" minHeight="110dp" -->
```

---

## 6. Fase 3 — Servicios Flutter (F1, F2)

### F1 — `StopwatchTimerService` (Flutter)

Responsabilidades:
- Enviar acciones al servicio nativo via MethodChannel
- Leer el estado actual desde SharedPreferences (via `shared_preferences`)
- Exponer un `Stream<StopwatchState>` para que la UI se actualice
- Gestionar la configuración de sonido y vibración

```dart
// Canal
static const _channel = MethodChannel('com.example.connect/stopwatch');

// Métodos públicos
static Future<void> start()
static Future<void> pause()
static Future<void> reset()
static Future<void> lap()
static Future<void> setTimer(Duration duration)
static Future<void> setMode(StopwatchMode mode)  // stopwatch | timer
static Future<StopwatchState> getState()

// Stream de actualización (cada 50ms mientras corre)
static Stream<StopwatchState> get stateStream => _stateController.stream;

// Config de sonido/vibración
static Future<void> setSoundEnabled(bool value)
static Future<void> setSoundUri(String uri)
static Future<void> setVibrationEnabled(bool value)
static Future<void> setVibrationPattern(String patternJson)
static Future<void> setLapVibrate(bool value)
static Future<void> setLapSound(bool value)
```

La UI escucha el stream. El stream se alimenta de:
1. Un `Timer.periodic(50ms)` cuando el cronómetro está corriendo
2. Las respuestas del MethodChannel `stopwatch_state_update`

### F2 — `StopwatchWidgetConfigService`

Sigue exactamente el patrón de `WidgetConfigService`. Las diferencias:
- `WidgetConfigSpec` tiene campos: `hasRing` (bool), `hasLaps` (bool), `hasTimerBar` (bool)
- Canal: mismo `com.example.connect/ble` con método `"updateStopwatchWidget"`
- Claves con prefijo `stopwatch_cfg_<id>_`

```dart
class StopwatchWidgetConfigSpec {
  final String id;         // 'style1', 'style2', 'style3'
  final String name;
  final String description;
  final bool hasRing;
  final bool hasLaps;
  final bool hasTimerBar;
  final int maxLapsVisible; // 0 si no tiene

  static const List<StopwatchWidgetConfigSpec> widgets = [
    StopwatchWidgetConfigSpec(id: 'style1', name: 'Compacto', description: 'Tiempo + Play/Pause + Reset', hasRing: false, hasLaps: false, hasTimerBar: false, maxLapsVisible: 0),
    StopwatchWidgetConfigSpec(id: 'style2', name: 'Con vueltas', description: 'Tiempo + vueltas + todos los controles', hasRing: false, hasLaps: true, hasTimerBar: true, maxLapsVisible: 5),
    StopwatchWidgetConfigSpec(id: 'style3', name: 'Circular', description: 'Anillo de progreso + tiempo central', hasRing: true, hasLaps: false, hasTimerBar: false, maxLapsVisible: 0),
  ];
}
```

---

## 7. Fase 4 — Pantalla principal en app (F4)

**Archivo:** `lib/screens/emisor/stopwatch_timer_screen.dart`

### Layout

```
AppBar: "Cronómetro / Temporizador"  [icono ajustes → StopwatchWidgetListScreen]

┌──────────────────────────────────────────┐
│  Toggle: [CRONÓMETRO]  [TEMPORIZADOR]    │
├──────────────────────────────────────────┤
│                                          │
│         00 : 04 : 23 . 057              │  ← tiempo principal (grande)
│                                          │
│  [Solo en modo timer: wheel picker       │
│   HH / MM / SS  (visible solo en idle)] │
│                                          │
├──────────────────────────────────────────┤
│  [INICIAR]   [VUELTA]   [REINICIAR]      │
│  (o PAUSAR cuando corre)                 │
├──────────────────────────────────────────┤
│  Ajustes rápidos de audio/vibración:     │
│  🔔 Sonido: ON/OFF   📳 Vibración: ON/OFF│
│  Al terminar: [sinusoid.mp3 ▼ cambiar]  │
│  Al vuelta:   [🔔 ON] [📳 OFF]           │
├──────────────────────────────────────────┤
│  Lista de vueltas (scroll)               │
│  Vuelta 3  00:45.231  Δ+00:02.015       │
│  Vuelta 2  00:43.216  Δ-00:01.102       │
│  Vuelta 1  00:44.318                    │
└──────────────────────────────────────────┘
```

### Estado local
```dart
StopwatchState _state = StopwatchState.idle;
StopwatchMode  _mode  = StopwatchMode.stopwatch;
Duration _elapsed     = Duration.zero;
Duration _timerDuration = const Duration(minutes: 5);
List<Duration> _laps  = [];
Timer? _ticker;          // 50ms, solo cuando running
```

Escucha `StopwatchTimerService.stateStream` para actualizarse.

### Selector de sonido
Usa la ruta existente `/custom_sound_selection`:
```dart
Navigator.pushNamed(context, '/custom_sound_selection').then((uri) {
  if (uri != null) StopwatchTimerService.setSoundUri(uri as String);
});
```

### Selector de patrón de vibración
Usa la ruta existente `/vibration_patterns`.

---

## 8. Fase 5 — Editor de widget + Preview (F5, F6, F3)

### F5 — `StopwatchWidgetListScreen`

Igual que `WidgetsConfigScreen` pero para los 3 estilos de cronómetro.
Cada tarjeta muestra la preview en miniatura y un botón "Configurar".
Opcionalmente acepta `embedded: true` para incrustar en pestaña.

### F6 — `StopwatchWidgetEditorScreen`

**Estructura:** `NestedScrollView` + `SliverPersistentHeader` con `TabBar` + preview fija
arriba (igual que `WidgetEditorScreen`).

#### Tabs y controles

**Tab 1 — Pantalla**
| Control | Tipo | Rango |
|---|---|---|
| Formato de tiempo | Segmented (HH:MM:SS / MM:SS / SS.ms) | — |
| Mostrar milisegundos | Switch | — |
| Número de vueltas visibles | Slider | 1–5 (solo style2) |
| Mostrar número de vuelta | Switch | — |
| Mostrar tiempo delta por vuelta | Switch | — |
| Modo por defecto al añadir | Segmented (crono/timer) | — |
| Escala del contenido (%) | Slider | 50–150 |

**Tab 2 — Colores**
| Elemento | Controles |
|---|---|
| Fondo | color ARGB + slider de opacidad independiente |
| Tiempo principal | color ARGB |
| Texto de vueltas | color ARGB |
| Texto de etiqueta modo | color ARGB |
| Iconos de botones | color ARGB + toggle "sin tinte" |
| Barra de progreso (relleno) | color ARGB (style2 timer, style3) |
| Barra de progreso (pista) | color ARGB |
| Anillo exterior (relleno) | color ARGB (solo style3) |
| Anillo exterior (pista) | color ARGB (solo style3) |

**Tab 3 — Tamaños**
| Elemento | Tipo | Rango |
|---|---|---|
| Tamaño del tiempo principal (sp) | Slider | 8–80 |
| Negrita del tiempo | Switch | — |
| Tamaño de texto de vueltas (sp) | Slider | 8–40 |
| Negrita de vueltas | Switch | — |
| Tamaño de iconos de botones (dp) | Slider | 16–64 |
| Grosor de barra/anillo (dp) | Slider | 2–24 |
| Radio de esquinas del fondo (dp) | Slider | 0–32 |
| Espaciado entre filas (dp) | Slider | 0–32 (solo style2) |

**Tab 4 — Iconos**
| Botón | Acción asignada | Override PNG |
|---|---|---|
| Play | Iniciar | Sí |
| Pause | Pausar | Sí |
| Reset | Reiniciar | Sí |
| Lap | Vuelta | Sí |
| Toggle modo | Cambiar modo | Sí |

Cada icono usa `WidgetIconPicker` (reutilización del widget existente).

**Tab 5 — Textos**
| Control | Tipo |
|---|---|
| Etiqueta modo cronómetro | TextField |
| Etiqueta modo temporizador | TextField |
| Texto "sin actividad" (idle) | TextField |
| Texto "pausado" | TextField |
| Prefijo de vuelta ("Vuelta", "Lap", "V") | TextField |

**Tab 6 — Sonido y Vibración**
| Control | Tipo |
|---|---|
| Vibración al terminar | Switch |
| Sonido al terminar | Switch |
| Archivo de sonido (fin) | Tile → `/custom_sound_selection` |
| Patrón de vibración (fin) | Tile → `/vibration_patterns` |
| Preview vibración | IconButton |
| Preview sonido | IconButton |
| Vibración en cada vuelta | Switch |
| Sonido en cada vuelta | Switch |
| Archivo de sonido (vuelta) | Tile → `/custom_sound_selection` (si vuelta habilitada) |

### F3 — `StopwatchWidgetPreview`

Widget Dart puro que replica el layout del RemoteViews. Acepta `StopwatchWidgetCfg` +
`StopwatchState` (datos de ejemplo en el editor) y devuelve la misma apariencia visual
que el widget nativo.

```dart
class StopwatchWidgetPreview extends StatelessWidget {
  final StopwatchWidgetConfigSpec spec;
  final StopwatchWidgetCfg cfg;
  final StopwatchState previewState;  // datos de ejemplo para la preview
  ...
  @override
  Widget build(BuildContext context) {
    return switch (spec.id) {
      'style1' => _buildStyle1(),
      'style2' => _buildStyle2(),
      'style3' => _buildStyle3(),
      _ => const SizedBox.shrink(),
    };
  }
}
```

Para el anillo del style3 en Flutter: usa `CustomPaint` con un `Canvas` que dibuja arcos,
espejando la lógica `drawRing` de Kotlin.

---

## 9. Fase 6 — Integración (modificaciones)

### AndroidManifest.xml

Agregar dentro de `<application>`:

```xml
<!-- Servicio de fondo del cronómetro/temporizador -->
<service
    android:name=".StopwatchTimerFgService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="specialUse" />

<!-- Widget cronómetro: compacto -->
<receiver
    android:name=".StopwatchWidgetProviderStyle1"
    android:enabled="true"
    android:label="Connect - Cronómetro (compacto)"
    android:exported="false"
    android:permission="android.permission.BIND_APPWIDGET">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/stopwatch_widget_info_style1" />
</receiver>

<!-- Widget cronómetro: con vueltas -->
<receiver
    android:name=".StopwatchWidgetProviderStyle2"
    android:enabled="true"
    android:label="Connect - Cronómetro (con vueltas)"
    android:exported="false"
    android:permission="android.permission.BIND_APPWIDGET">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/stopwatch_widget_info_style2" />
</receiver>

<!-- Widget cronómetro: circular -->
<receiver
    android:name=".StopwatchWidgetProviderStyle3"
    android:enabled="true"
    android:label="Connect - Cronómetro (circular)"
    android:exported="false"
    android:permission="android.permission.BIND_APPWIDGET">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/stopwatch_widget_info_style3" />
</receiver>
```

Agregar permiso de foreground service type (si no existe):
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
```

### MainActivity.kt

Agregar canal:
```kotlin
private val STOPWATCH_CHANNEL = "com.example.connect/stopwatch"
private lateinit var stopwatchChannel: MethodChannel
```

En `configureFlutterEngine`:
```kotlin
stopwatchChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STOPWATCH_CHANNEL)
stopwatchChannel.setMethodCallHandler { call, result ->
    when (call.method) {
        "start"     -> { sendToService(ACTION_START); result.success(true) }
        "pause"     -> { sendToService(ACTION_PAUSE); result.success(true) }
        "reset"     -> { sendToService(ACTION_RESET); result.success(true) }
        "lap"       -> { sendToService(ACTION_LAP); result.success(true) }
        "set_timer" -> {
            val ms = call.argument<Long>("duration_ms") ?: 0L
            sendToService(ACTION_SET_TIMER, extras = mapOf(EXTRA_TIMER_DURATION to ms))
            result.success(true)
        }
        "set_mode"  -> {
            val mode = call.argument<String>("mode") ?: "stopwatch"
            sendToService(ACTION_SET_MODE, extras = mapOf(EXTRA_MODE to mode))
            result.success(true)
        }
        "get_state" -> {
            result.success(readStopwatchStateMap())
        }
        "updateStopwatchWidget" -> {
            StopwatchWidgetProviderStyle1.updateAll(applicationContext)
            StopwatchWidgetProviderStyle2.updateAll(applicationContext)
            StopwatchWidgetProviderStyle3.updateAll(applicationContext)
            result.success(true)
        }
        else -> result.notImplemented()
    }
}
```

También en el `MethodChannel` `com.example.connect/ble`, en el handler de `updateWidget`:
```kotlin
StopwatchWidgetProviderStyle1.updateAll(applicationContext)
StopwatchWidgetProviderStyle2.updateAll(applicationContext)
StopwatchWidgetProviderStyle3.updateAll(applicationContext)
```

### lib/main.dart

```dart
'/stopwatch_widget': (context) => const StopwatchWidgetListScreen(),
'/stopwatch_timer':  (context) => const StopwatchTimerScreen(),
```

### lib/screens/emisor/settings_screen.dart

Después del tile "Widgets" (~L561), añadir:
```dart
ListTile(
  contentPadding: EdgeInsets.zero,
  title: const Text('Cronómetro y Temporizador'),
  subtitle: const Text(
    'Widget de pantalla de inicio con cronómetro, temporizador y configuración de sonido',
  ),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const StopwatchWidgetListScreen()),
  ),
),
```

---

## 10. Mapa completo de SharedPreferences

### Estado del cronómetro (escribe el servicio nativo, lee Flutter + widget)

| Clave (sin prefijo `flutter.`) | Tipo | Valores |
|---|---|---|
| `stopwatch_mode` | String | `"stopwatch"` \| `"timer"` |
| `stopwatch_state` | String | `"idle"` \| `"running"` \| `"paused"` \| `"finished"` |
| `stopwatch_start_epoch` | Long | ms desde epoch al iniciar/reanudar |
| `stopwatch_accumulated` | Long | ms acumulados antes del último start |
| `stopwatch_laps_json` | String | JSON `[{"elapsed":12345,"delta":1234},...]` |
| `stopwatch_timer_target` | Long | duración total del timer en ms |
| `stopwatch_timer_remaining` | Long | ms restantes cuando se pausa el timer |

### Configuración de sonido/vibración (escribe Flutter, lee servicio nativo)

| Clave (sin prefijo `flutter.`) | Tipo | Default |
|---|---|---|
| `stopwatch_sound_enabled` | Bool | `true` |
| `stopwatch_sound_uri` | String | `""` (sonido del sistema) |
| `stopwatch_vibration_enabled` | Bool | `true` |
| `stopwatch_vibration_pattern` | String | `""` (vibración corta 600ms) |
| `stopwatch_lap_vibrate` | Bool | `false` |
| `stopwatch_lap_sound` | Bool | `false` |
| `stopwatch_lap_sound_uri` | String | `""` |

### Configuración de estilo del widget (escribe Flutter, lee widget nativo)

Prefijo de clave: `stopwatch_cfg_<id>_` (ej: `stopwatch_cfg_style1_bgArgb`)

| Sufijo | Tipo | Default | Descripción |
|---|---|---|---|
| `bgArgb` | Int | `0xCC000000` | Color de fondo (con alfa) |
| `bgOpacity` | Int | `204` (0-255) | Opacidad independiente de fondo |
| `timeColor` | Int | `0xFFFFFFFF` | Color del tiempo principal |
| `timeSizeSp` | Int | `32` | Tamaño del tiempo (sp) |
| `timeBold` | Bool | `true` | Negrita del tiempo |
| `showMs` | Bool | `true` | Mostrar milisegundos |
| `timeFormat` | String | `"hms"` | `"hms"` \| `"ms"` \| `"s_ms"` |
| `lapColor` | Int | `0xFFCCCCCC` | Color de texto de vueltas |
| `lapSizeSp` | Int | `12` | Tamaño de texto de vueltas (sp) |
| `lapBold` | Bool | `false` | Negrita de vueltas |
| `lapCount` | Int | `3` | Cuántas vueltas mostrar (1-5) |
| `showLapNumber` | Bool | `true` | Mostrar número de vuelta |
| `showLapDelta` | Bool | `true` | Mostrar tiempo delta |
| `modeLabelColor` | Int | `0xFF88AAFF` | Color de etiqueta de modo |
| `modeLabelSizeSp` | Int | `10` | Tamaño de etiqueta de modo (sp) |
| `iconColor` | Int | `0xFFFFFFFF` | Color de tinte de iconos |
| `iconColorEnabled` | Bool | `true` | Aplicar tinte a iconos |
| `iconSizeDp` | Int | `24` | Tamaño de iconos (dp) |
| `iconPlay` | String | `""` | PNG base64 icono play (vacío = built-in) |
| `iconPause` | String | `""` | PNG base64 icono pause |
| `iconReset` | String | `""` | PNG base64 icono reset |
| `iconLap` | String | `""` | PNG base64 icono vuelta |
| `iconToggleMode` | String | `""` | PNG base64 icono toggle modo |
| `ringTrackArgb` | Int | `0x33FFFFFF` | Color pista del anillo (style3) |
| `ringFillArgb` | Int | `0xFF4488FF` | Color relleno del anillo (style3) |
| `ringThicknessDp` | Int | `8` | Grosor del anillo (dp) |
| `barTrackArgb` | Int | `0x33FFFFFF` | Color pista de barra (style2 timer) |
| `barFillArgb` | Int | `0xFF4488FF` | Color relleno de barra |
| `barThicknessDp` | Int | `4` | Grosor de barra (dp) |
| `cornerRadiusDp` | Int | `12` | Radio de esquinas del fondo |
| `rowSpacingDp` | Int | `4` | Espaciado entre filas (style2) |
| `contentScalePct` | Int | `100` | Escala global del contenido (%) |
| `labelIdle` | String | `"Listo"` | Texto en estado idle |
| `labelPaused` | String | `"Pausado"` | Texto en estado pausado |
| `labelStopwatch` | String | `"CRONÓMETRO"` | Etiqueta modo cronómetro |
| `labelTimer` | String | `"TEMPORIZADOR"` | Etiqueta modo temporizador |
| `lapPrefix` | String | `"V"` | Prefijo de vuelta |
| `defaultMode` | String | `"stopwatch"` | Modo por defecto al agregar |

> **Regla de defaults espejo:** cada valor de la tabla debe estar duplicado
> en `StopwatchWidgetConfigService.def*` (Dart) y en
> `StopwatchWidgetProvider.readWidgetCfg(...)` (Kotlin).

---

## 11. Modelo de datos Flutter

```dart
enum StopwatchMode { stopwatch, timer }
enum StopwatchState { idle, running, paused, finished }

class StopwatchSnapshot {
  final StopwatchMode  mode;
  final StopwatchState state;
  final Duration       elapsed;      // para cronómetro
  final Duration       remaining;    // para temporizador
  final Duration       timerTarget;  // duración total del timer
  final List<LapEntry> laps;

  Duration get currentLapElapsed => laps.isEmpty
      ? elapsed
      : elapsed - laps.last.totalElapsed;
}

class LapEntry {
  final int     number;
  final Duration totalElapsed;
  final Duration delta;           // vs vuelta anterior
}

class StopwatchWidgetCfg {
  // ← todos los campos de la tabla de SharedPreferences §10
  // más los WidgetConfigSpec flags (hasRing, hasLaps, etc.)
}
```

---

## 12. Checklist de integridad al terminar la implementación

Sigue el checklist de 7 puntos de `connect-widgets-integration`, aplicado a este widget:

- [ ] Layout `widget_stopwatch_style1/2/3.xml` creados con IDs estables
- [ ] Info XMLs `stopwatch_widget_info_style1/2/3.xml` creados
- [ ] Subclases `StopwatchWidgetProviderStyle1/2/3` con `layoutResId` y `updateAll` propios
- [ ] 3 `<receiver>` en `AndroidManifest.xml`
- [ ] `StopwatchTimerFgService` declarado en `AndroidManifest.xml`
- [ ] Canal `STOPWATCH_CHANNEL` inicializado en `MainActivity.kt`
- [ ] `updateStopwatchWidget` llama a los 3 `updateAll` en `MainActivity.kt`
- [ ] `StopwatchWidgetConfigSpec` registrado en `StopwatchWidgetConfigService.widgets` (los 3)
- [ ] Rama `switch (spec.id)` en `StopwatchWidgetPreview` para los 3 estilos
- [ ] Defaults **idénticos** entre Dart (`def*`) y Kotlin (`readWidgetCfg`)
- [ ] Las claves `stopwatch_cfg_<id>_<prop>` coinciden en Dart y Kotlin
- [ ] `lib/main.dart` tiene ruta `/stopwatch_widget` y `/stopwatch_timer`
- [ ] `settings_screen.dart` tiene tile que navega a `StopwatchWidgetListScreen`
- [ ] El servicio nativo actualiza los 3 widgets en cada tick + en cada acción
- [ ] `onDeleted` limpia el estado por instancia si se usan prefs por `appWidgetId`
- [ ] Persistir en `onChangeEnd`, no en `onChanged` (evitar spam al widget nativo)
- [ ] El sonido funciona con app cerrada (MediaPlayer en el servicio nativo)
- [ ] La vibración funciona con app cerrada (Vibrator en el servicio nativo)
- [ ] El cronómetro sigue corriendo al rotar pantalla (estado recuperado de prefs)

---

## 13. Orden de implementación sugerido

1. **N1** `StopwatchTimerFgService.kt` + `AndroidManifest.xml` (service) → validar
   que el servicio arranca y escribe en SharedPreferences.
2. **R1-R6** Layouts + info XMLs → compilar sin errores.
3. **N2** `StopwatchWidgetProvider.kt` (solo style1 inicialmente) + manifest receiver →
   validar que el widget aparece en la pantalla de inicio y muestra tiempo.
4. **F1** `StopwatchTimerService.dart` + canal en `MainActivity.kt` → validar que
   Flutter puede iniciar/pausar/reiniciar el servicio.
5. **F4** `StopwatchTimerScreen` → probar la pantalla en app con cronómetro completo.
6. **F2** `StopwatchWidgetConfigService` + defaults espejo en Kotlin → validar que
   los defaults son iguales.
7. **F3** `StopwatchWidgetPreview` → preview en vivo básica.
8. **F6** `StopwatchWidgetEditorScreen` con todos los tabs → probar cada control.
9. **F5** `StopwatchWidgetListScreen`.
10. Completar **N2** style2 y style3.
11. Integración de sonido/vibración (tab en editor + servicio nativo).
12. Integración de navegación (`main.dart`, `settings_screen.dart`).
13. Checklist de integridad completo.

---

## 14. Dependencias y notas

- **No se requieren nuevos paquetes Flutter**; `shared_preferences` y `flutter/services`
  ya están en el proyecto.
- El selector de archivo de sonido reutiliza `CustomSoundSelectionScreen` (ruta
  `/custom_sound_selection`), ya implementada.
- El selector de patrón de vibración reutiliza `VibrationPatternsScreen` (ruta
  `/vibration_patterns`), ya implementada.
- `WidgetIconPicker` y `ColorInputWidget` se reutilizan en el editor.
- `foregroundServiceType="specialUse"` requiere `<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/>` (Android 14+).
- Para Android < 8.0, `Vibrator.vibrate(long)` sin `VibrationEffect`; usar el helper
  `vibrateCompat` ya utilizado en otros lugares del proyecto.
- El `updatePeriodMillis="0"` en los info XMLs es obligatorio: el widget NO se
  auto-refresca; lo hace el servicio vía `broadcastTick`.
