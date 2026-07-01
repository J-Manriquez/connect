---
name: connect-widgets-integration
description: Mapa OFICIAL de los widgets de la app connect (música ×3 estilos + clima) y cómo integrarlos — qué archivos los componen, cómo se configuran/persisten, cómo se ven en la app (preview en vivo) y en la pantalla de inicio (AppWidget nativo), y las RUTAS exactas para añadir navegación a sus pantallas de configuración desde los ajustes de emisor y receptor. Léela ANTES de tocar, mover o añadir cualquier widget en connect, o de cablear la navegación a sus pantallas. Para el patrón genérico portable a otra app usa la skill hermana `flutter-home-screen-widgets`.
---

# Widgets de connect — estructura, configuración y navegación

App: Flutter Android `connect`. Hay **dos familias de widgets de pantalla de inicio**,
ambas con el patrón Flutter↔nativo descrito en `flutter-home-screen-widgets`
(puente por `shared_preferences` + `MethodChannel`).

## Inventario de widgets

| Widget | id config | Provider Kotlin | Layout | Tipo |
|---|---|---|---|---|
| Música (centrado) | `style2` | `MediaWidgetProviderStyle2` | `widget_media_style2.xml` | Espejo, configurable |
| Música (con progreso) | `style3` | `MediaWidgetProviderStyle3` | `widget_media_style3.xml` | Espejo, configurable |
| Música (ancho) | `wide` | `MediaWidgetProviderWide` | `widget_media_wide.xml` | Espejo, configurable |
| Clima | — | `WeatherWidgetProvider` | `widget_weather.xml` | Autónomo navegable |

> Los layouts/info `style4`, `style5` y `widget_media.xml` antiguos fueron **eliminados**
> (ver git status). El registro vivo de música son `style2`, `style3`, `wide`.

## Archivos por familia

### Música (3 estilos configurables)
- Config + persistencia: [lib/services/widget_config_service.dart](../../../lib/services/widget_config_service.dart)
  — `WidgetConfigService.widgets` es el **registro**; añadir un estilo = añadir un `WidgetConfigSpec`.
- Lista de widgets: [lib/screens/emisor/widgets_config_screen.dart](../../../lib/screens/emisor/widgets_config_screen.dart)
  (`WidgetsConfigScreen`, acepta `embedded`).
- Editor + preview fija + pestañas: [lib/screens/emisor/widget_editor_screen.dart](../../../lib/screens/emisor/widget_editor_screen.dart).
- Preview en vivo (Dart): [lib/widgets/widget_music_preview.dart](../../../lib/widgets/widget_music_preview.dart)
  (`switch` por `widgetId`: `style2`/`style3`/`wide`).
- Pickers de iconos: [lib/widgets/widget_icon_picker.dart](../../../lib/widgets/widget_icon_picker.dart),
  [lib/widgets/widget_default_app_icon_picker.dart](../../../lib/widgets/widget_default_app_icon_picker.dart).
- Nativo: [android/app/src/main/kotlin/com/example/connect/MediaWidgetProvider.kt](../../../android/app/src/main/kotlin/com/example/connect/MediaWidgetProvider.kt)
  (`BaseMediaWidgetProvider` + 3 subclases). Layouts en `res/layout/widget_media_*.xml`,
  info en `res/xml/media_widget_info_*.xml`.

### Clima (autónomo navegable, CON personalización rica)
- Datos/snapshot: [lib/services/weather_store.dart](../../../lib/services/weather_store.dart)
  (`rebuildWidgetSnapshot()` → clave `weather_widget_json` → `updateWeatherWidget`;
  `notifyWidget()` repinta sin tocar el snapshot, lo usa el config service).
- Personalización + persistencia: [lib/services/weather_widget_config_service.dart](../../../lib/services/weather_widget_config_service.dart)
  — `WeatherWidgetConfig` (tamaños/colores/negritas de cabecera, vista "Ahora", filas de
  listas, indicadores; modo de fondo dinámico/sólido/degradado, oscurecido %, radio de
  esquinas) con claves `weather_widget_cfg_<prop>` → `flutter.weather_widget_cfg_<prop>`.
  `resetAll()` borra el prefijo y repinta.
- Pantalla de config (ciudades): [lib/screens/weather_settings_screen.dart](../../../lib/screens/weather_settings_screen.dart)
  — tiene un botón "Personalizar widget" que navega al editor.
- Editor de estilo (preview fija + pestañas Tamaño/Colores/Fondo/Indicadores):
  [lib/screens/emisor/weather_widget_editor_screen.dart](../../../lib/screens/emisor/weather_widget_editor_screen.dart)
  (reutiliza `showWidgetColorPicker` de `widget_editor_screen.dart`).
- Preview en app: [lib/widgets/weather_widget.dart](../../../lib/widgets/weather_widget.dart)
  (lee `WeatherWidgetConfig` y lo aplica a cabecera/páginas/puntos/fondo),
  [lib/widgets/weather_background.dart](../../../lib/widgets/weather_background.dart)
  (animación + `darkenPct`).
- Nativo: [android/app/src/main/kotlin/com/example/connect/WeatherWidgetProvider.kt](../../../android/app/src/main/kotlin/com/example/connect/WeatherWidgetProvider.kt)
  — `readWeatherWidgetCfg()` espejo de los defaults Dart; el fondo (cualquier modo) se
  dibuja a un `Bitmap` con `Canvas`/`LinearGradient` (`buildBgBitmap`, espejo de
  `WeatherCodeInfo.gradientColors` vía `dynamicGradientFor`) y se aplica con
  `setImageViewBitmap` sobre `weather_bg_image` (RemoteViews no admite Drawables propios).
  Layout `res/layout/widget_weather.xml`, info `res/xml/weather_widget_info.xml`. Los
  drawables estáticos `res/drawable/weather_bg_*`/`weather_widget_bg.xml` quedaron sin uso
  (el fondo ahora siempre se genera en runtime) — no se eliminaron pero no afectan nada.

## Cómo se configura y persiste (música)

- Claves: `widget_cfg_<id>_<prop>` (Flutter) → `flutter.widget_cfg_<id>_<prop>` (Kotlin `readWidgetCfg`).
- Lo configurable (por estilo): escala de contenido, espacio entre filas (solo `style3`,
  `hasRowSpacing`), color/velo/opacidad de fondo, color+tamaño de iconos, iconos PNG base64
  (prev/play/pause/next/volume), colores y grosor de barras, tamaño/color/negrita de
  título/subtítulo/tiempos, textos "sin multimedia", y botón "abrir app por defecto"
  (`hasDefaultAppButton`, claves globales `media_default_app_widget2_icon_*`).
- Persistir SOLO en `onChangeEnd`; `onChanged` mueve la preview en memoria.
- Tras cualquier escritura: `WidgetConfigService._notify()` → `BleService.updateWidget()`
  → `MethodChannel('com.example.connect/ble').updateWidget` → en
  [MainActivity.kt](../../../android/app/src/main/kotlin/com/example/connect/MainActivity.kt)
  llama a `MediaWidgetProviderStyle2/Style3/Wide.updateAll(applicationContext)`.
- **Defaults espejo**: `WidgetConfigService.def*` ⇔ `readWidgetCfg(...)`. Cambiar uno obliga al otro.

## Cómo se muestra

- **En la app (preview)**: `WidgetMusicPreview` / `WeatherWidget` — Dart puro que replica el
  layout leyendo la misma config; refleja los cambios en vivo.
- **En la pantalla de inicio**: `RemoteViews` que el `Provider` construye en
  `buildRemoteViews()` leyendo `flutter.*`. Acciones por `PendingIntent` broadcast →
  `onReceive`. Música reenvía comandos por BT (`BtClassicServerService`); clima navega entre
  sus 3 vistas (Ahora / Por horas / Por días) con botones y rota ciudades.

## RUTAS para añadir navegación a las pantallas de config

### Lista de widgets de música (`WidgetsConfigScreen`)
- **Emisor** — push directo (no es ruta nombrada):
  ```dart
  import 'package:connect/screens/emisor/widgets_config_screen.dart';
  Navigator.push(context, MaterialPageRoute(
    builder: (context) => const WidgetsConfigScreen(),
  ));
  ```
  Ya cableado en [settings_screen.dart](../../../lib/screens/emisor/settings_screen.dart) (~L548-561), tile "Widgets".
- **Receptor** — incrustada en una pestaña con `embedded: true`:
  ```dart
  const Expanded(child: WidgetsConfigScreen(embedded: true)),
  ```
  Ya cableado en [receptor_settings_screen.dart](../../../lib/screens/receptor/receptor_settings_screen.dart) (~L977).
- **Editor de un estilo** (desde la lista): `WidgetEditorScreen(spec: spec)` por `MaterialPageRoute`.

### Pantalla de clima (`WeatherSettingsScreen`)
- **Ruta nombrada** registrada en [main.dart](../../../lib/main.dart) (~L1037):
  ```dart
  '/weather_settings': (context) => const WeatherSettingsScreen(),
  ```
  Navegar con: `Navigator.pushNamed(context, '/weather_settings');`
  (la lista de música ya enlaza aquí con un `ListTile` "Widget de clima").

### Patrón para enlazar desde una pantalla de ajustes nueva
```dart
ListTile(
  title: const Text('Widgets'),
  subtitle: const Text('Widget de clima y widgets de música de la pantalla de inicio'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const WidgetsConfigScreen())),
)
```
Para una pestaña/sección incrustada usa `WidgetsConfigScreen(embedded: true)` dentro de un
`Expanded`/`Column` (sin Scaffold propio). Para reordenar esas pantallas en pestañas, sigue
la skill `receptor-screen-tabs` (no tocar el core, solo la interfaz).

## Al añadir/quitar/mover un widget — verifica los 7 puntos
Layout `xml` · info `xml` · subclase Provider · `<receiver>` en Manifest · llamada en
`MainActivity.updateWidget` · `WidgetConfigSpec` en el registro · rama en la preview Dart.
(+ defaults espejo si cambias alguno). Detalle en `flutter-home-screen-widgets`.
