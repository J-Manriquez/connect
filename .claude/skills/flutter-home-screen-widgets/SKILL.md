---
name: flutter-home-screen-widgets
description: Patrón GENÉRICO y reutilizable para implementar widgets de pantalla de inicio Android (AppWidget) configurables desde una app Flutter — con vista previa en vivo dentro de la app, editor de estilos persistente (colores, tamaños, iconos, textos), y un widget nativo (RemoteViews) que lee la misma configuración. Cubre los dos tipos: widget "espejo" (música) y widget "autónomo navegable" (clima). Úsala al portar este sistema de widgets a OTRA app Flutter, o al añadir un widget nuevo desde cero. Para las rutas y navegación concretas de la app connect usa la skill hermana `connect-widgets-integration`.
---

# Widgets de pantalla de inicio configurables (Flutter ⇄ Android nativo)

Patrón validado para que una app Flutter ofrezca **widgets de pantalla de inicio Android**
totalmente personalizables desde la propia app, con **vista previa en vivo** y un
**editor** que persiste cada ajuste. El widget real se dibuja en Kotlin con
`RemoteViews`; Flutter solo escribe la configuración y pide repintar.

Esta skill es **genérica** (no depende de connect). Da la arquitectura, los archivos
a crear y las reglas para no romper el puente Flutter↔nativo.

---

## Concepto central: el puente es `SharedPreferences`

No hay paso de datos en caliente. Flutter y el widget nativo se comunican **solo** por
`shared_preferences`:

- Flutter escribe con `shared_preferences` → la clave se guarda como `flutter.<clave>`.
- El lado nativo (Kotlin) lee `SharedPreferences("FlutterSharedPreferences")` con la
  clave **incluyendo el prefijo** `flutter.`.
- Tras escribir, Flutter invoca un `MethodChannel` (`updateWidget` / `updateWeatherWidget`)
  que llama a `Provider.updateAll(context)`, y el widget se repinta leyendo lo recién escrito.

> ⚠️ Regla de oro: **los defaults del lado Flutter y del lado Kotlin deben ser idénticos.**
> Si no, la vista previa de la app y el widget real divergen. Mantenlos como constantes
> espejo (ver `WidgetConfigService.def*` ↔ `readWidgetCfg(...)`).

```
┌─────────────── Flutter ───────────────┐        ┌────────── Android nativo ──────────┐
│ EditorScreen  ── escribe ──▶ Service   │        │ AppWidgetProvider                  │
│   (sliders,                  (setInt/  │ prefs  │   onUpdate / onReceive             │
│    colores,   ◀── lee ─────   setBool/ │◀──────▶│   buildRemoteViews():              │
│    iconos)                   setString)│ flutter.│     readWidgetCfg(prefs)          │
│ Preview (Dart) refleja Config          │  *      │     applyTextStyles / icons / bars │
│ MethodChannel.updateWidget() ──────────┼────────┼──▶ Provider.updateAll() → repinta  │
└────────────────────────────────────────┘        └────────────────────────────────────┘
```

---

## Dos tipos de widget (elige según el caso)

### Tipo A — "Espejo" (ej. música)
El widget refleja un estado externo (reproducción) y sus controles **envían comandos**.
Varios *estilos* comparten un mismo `BaseProvider` y se diferencian solo por el `layoutResId`.

- **Estado**: se cachea en `SharedPreferences` con timestamp y TTL (`now - updatedAt <= 15s`
  ⇒ "fresco"; si no, estado "sin datos").
- **Acciones**: cada botón es un `PendingIntent.getBroadcast` → `onReceive` despacha por
  `intent.action` (TOGGLE, NEXT, PREV, SET_VOLUME…) y reenvía el comando (BT, servicio, etc.).
- **Personalización rica**: tamaños, colores, negritas, opacidad de fondo, iconos PNG en
  base64, grosor de barras, textos de "sin datos".

### Tipo B — "Autónomo navegable" (ej. clima)
El widget tiene **datos propios** (un snapshot JSON que Flutter genera) y **navega dentro
de sí mismo** porque `RemoteViews` no admite gestos: se usan botones ◀▶▲▼.

- **Estado de UI por instancia** (`appWidgetId`): vista actual, offset de scroll, ciudad
  seleccionada, en un `SharedPreferences` propio (`weather_widget_ui`), con limpieza en
  `onDeleted`.
- **Datos**: Flutter construye un snapshot (`rebuildWidgetSnapshot()`), lo guarda en una
  clave (`flutter.weather_widget_json`) y pide repintar. El widget solo pinta.
- **Sin personalización de estilo** (fondo dinámico por condición), solo navegación.

---

## Archivos a crear (plantilla)

### Lado Flutter
1. **`lib/services/<x>_widget_config_service.dart`** — modelo + persistencia.
   - `class WidgetConfigSpec` (id, nombre, descripción, defaults, flags de capacidades).
   - `class WidgetConfig` (snapshot mutable que el editor muta).
   - `class WidgetConfigService`:
     - `static const List<WidgetConfigSpec> widgets` (registro; escalar = añadir aquí).
     - `static const def*` (defaults **espejo del Kotlin**).
     - clave canónica `_k(id, prop) => 'widget_cfg_${id}_$prop'`.
     - `load(spec)`, `setInt/setBool/setString/remove`, `resetAll(id)` (borra prefijo),
       y `_notify()` → `MethodChannel.invokeMethod('updateWidget')`.
2. **`lib/widgets/<x>_preview.dart`** — vista previa en Flutter puro que reproduce el
   layout del widget leyendo la misma `WidgetConfig` (con `switch` por `widgetId`). Usa
   datos de ejemplo y un toggle "sin datos". **Debe verse igual que el RemoteViews real.**
3. **`lib/screens/<x>_list_screen.dart`** — lista de widgets disponibles (`...widgets.map`),
   con `embedded` opcional (sin Scaffold) para incrustar en una pestaña.
4. **`lib/screens/<x>_editor_screen.dart`** — editor con preview fija arriba
   (`NestedScrollView` + `SliverPersistentHeader` con `TabBar`) y pestañas de secciones
   (Tamaño / Fondo / Iconos / Barras / Textos). Cada control:
   `setState` local (mueve la preview) + `onChangeEnd`→ `Service.setX` (persiste + repinta).
   Botón "Restablecer" → `resetAll`.

### Lado Android nativo
5. **`android/.../<X>WidgetProvider.kt`**:
   - `abstract class Base<X>WidgetProvider : AppWidgetProvider()` con `layoutResId` abstracto.
   - `onUpdate` → `updateAppWidgets(...)`; `onReceive` → `when(action){...}` despacha acciones.
   - `companion object`: `readWidgetCfg(prefs, id)` (lee `flutter.widget_cfg_<id>_<prop>` con
     defaults espejo), `applyTextStyles`, `applyControlIcon` (decodifica base64 / tinte),
     `renderBar` (dibuja barra a `Bitmap`), `buildRemoteViews`, y `updateAll(context)`.
   - Subclases concretas, una por estilo, cada una con su `layoutResId` y `updateAll`.
   - El `id` de config se deriva del nombre de clase:
     `providerClass.simpleName.removePrefix("<X>WidgetProvider").lowercase()`.
6. **`android/.../res/layout/widget_<x>_*.xml`** — un layout RemoteViews por estilo. IDs
   estables que el Kotlin referencia (`widget_title`, `widget_progress`, `widget_prev`…).
   Solo Views soportadas por RemoteViews (FrameLayout/LinearLayout/RelativeLayout,
   TextView, ImageView, ProgressBar…). Nada de ConstraintLayout ni custom views.
7. **`android/.../res/xml/<x>_widget_info_*.xml`** — `appwidget-provider` (initialLayout,
   minWidth/Height, resizeMode, `updatePeriodMillis="0"`, `widgetCategory="home_screen"`).
8. **`AndroidManifest.xml`** — un `<receiver>` por estilo:
   ```xml
   <receiver android:name=".<X>WidgetProviderStyleN" android:enabled="true"
       android:exported="false" android:permission="android.permission.BIND_APPWIDGET">
       <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE"/></intent-filter>
       <meta-data android:name="android.appwidget.provider" android:resource="@xml/<x>_widget_info_styleN"/>
   </receiver>
   ```
9. **`MainActivity.kt`** — en el `MethodChannel` handler:
   ```kotlin
   "updateWidget" -> { ProviderStyle2.updateAll(applicationContext); /* … */; result.success(true) }
   ```

---

## Reglas que NO se rompen

1. **Defaults espejo Flutter↔Kotlin.** Cambiar un default obliga a cambiarlo en ambos lados.
2. **Claves canónicas.** El nombre de la clave (`widget_cfg_<id>_<prop>`) es contrato.
   Cámbialo en los dos lados o no se leerá.
3. **`flutter.` prefix.** Flutter no lo escribe (lo añade `shared_preferences`); Kotlin SÍ
   debe incluirlo al leer.
4. **Persistir en `onChangeEnd`, no en `onChanged`.** Mover el slider repinta la preview en
   memoria; solo al soltar se persiste + se repinta el widget (evita spamear el nativo).
5. **Booleans tolerantes en Kotlin.** `shared_preferences` puede guardar bool como Boolean,
   String o Int; lee con un helper `readFlutterBool` que acepte los tres.
6. **Limpia el estado por instancia en `onDeleted`** (widgets tipo B con `appWidgetId`).
7. **`RemoteViews` es limitado.** Sin gestos (usa botones), sin animaciones, sin custom
   views. Para "barras" y formas, dibújalas a `Bitmap` con `Canvas` y mételas con
   `setImageViewBitmap`.
8. **Iconos personalizados = PNG base64** en prefs; el nativo decodifica, escala y opcional
   tinta. Si está vacío, usa el drawable built-in.

---

## Checklist para añadir un estilo nuevo

- [ ] Layout `widget_<x>_styleN.xml` con los IDs que el Kotlin espera.
- [ ] `xml/<x>_widget_info_styleN.xml`.
- [ ] Subclase `…ProviderStyleN` con su `layoutResId` + `updateAll`.
- [ ] `<receiver>` en el Manifest.
- [ ] Llamada en `MainActivity.updateWidget`.
- [ ] `WidgetConfigSpec(id: 'styleN', …)` en `WidgetConfigService.widgets`.
- [ ] Rama `case 'styleN'` en la preview Dart.
- [ ] Defaults espejo si el estilo cambia alguno (`readWidgetCfg`).

## Checklist para añadir una propiedad configurable nueva

- [ ] Campo en `WidgetConfig` + carga en `load()` + default en `def*`.
- [ ] Control en la sección correspondiente del editor (`onChangeEnd` → `setX`).
- [ ] Uso en la preview Dart.
- [ ] Lectura en `readWidgetCfg` (Kotlin) con **el mismo default**.
- [ ] Aplicación en `buildRemoteViews` (Kotlin).
