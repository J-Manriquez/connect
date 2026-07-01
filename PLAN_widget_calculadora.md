# Plan: Widget de Calculadora (home-screen) + pantalla en Herramientas

> Estado: PENDIENTE DE IMPLEMENTAR. Plan acordado; se aplicará más adelante.

## Contexto

connect ya tiene un sistema maduro de widgets de pantalla de inicio (música ×3, clima)
con el patrón Flutter↔nativo documentado en las skills `flutter-home-screen-widgets`,
`connect-widgets-integration` y el estándar de personalización
`customization-detail-standard`. El usuario quiere un **widget de calculadora** nuevo con:

- Calculadora básica con **paréntesis** (dígitos, + − × ÷, %, +/−, ., C/AC, ⌫, =).
- Botón que **expande** la ventana de la operación para ver toda la expresión.
- Botón que muestra el **historial** de ejercicios y permite **seguir operando** sobre ellos;
  cada operación nueva **se sigue almacenando**.
- En la **pantalla de Herramientas** (in-app): la misma calculadora con el **mismo estilo
  configurado del widget**, pero con lo que el widget nativo NO puede hacer: **nombrar,
  editar nombre y eliminar** entradas del historial.
- **Toda la interfaz** configurable: colores, tamaños, iconos, fondos, transparencia,
  redondeo de bordes (de botones y del contorno del widget), etc., vía **editor + preview**
  al nivel del estándar de connect.

Decisiones ya confirmadas con el usuario: destino = **AppWidget nativo** + **pantalla en
Herramientas** que comparten estilo e historial; personalización = **editor + preview**
(patrón connect).

## Límites honestos de RemoteViews (afectan el diseño del widget nativo)

RemoteViews no admite TextField/teclado/scroll editable. Por eso:
- **Nombrar/editar/eliminar historial** → SOLO en la pantalla in-app (confirmado).
- **"Expandir"** en el widget = alternar un `TextView` de expresión multilínea más alto
  (no se puede agrandar la celda; se muestra más de la expresión y se oculta parte del teclado).
- **Historial en el widget** = vista de filas paginadas con ▲▼ (patrón del widget de clima);
  tocar una fila **carga** ese ejercicio en la calculadora para seguir operando.
- La **evaluación de la expresión** se implementa en **ambos** lados (Dart y Kotlin), como el
  resto de widgets "espejo". Algoritmo: shunting-yard / precedencia con paréntesis.

## Arquitectura (puente = shared_preferences + MethodChannel, igual que el resto)

- **Estilo**: claves `widget_cfg_calc_<prop>` (Flutter) → `flutter.widget_cfg_calc_<prop>`
  (Kotlin). Defaults **espejo** Flutter↔Kotlin.
- **Historial compartido**: clave `calc_history_json` (Flutter) ↔ `flutter.calc_history_json`
  (Kotlin). Lo leen y escriben ambos lados. Esquema por entrada:
  `{ "id": String, "name": String, "expr": String, "result": String, "updatedAt": Long }`.
- **Estado efímero del widget por instancia** (`appWidgetId`): expresión en curso, modo
  (teclado/expandido/historial), offset de paginación del historial → en un
  `SharedPreferences` propio `calc_widget_ui` (limpiar en `onDeleted`, patrón clima).
- Tras escribir estilo o historial, repintar vía `MethodChannel('com.example.connect/ble')`
  → `updateCalculatorWidget`.

## Archivos nuevos — Flutter

1. `lib/services/calculator_engine.dart`
   - Evaluador puro: tokeniza y evalúa expresión con + − × ÷ %, paréntesis, decimales,
     signo. Maneja errores (división por cero, paréntesis desbalanceados) → "Error".
   - Reutilizado por la preview, la pantalla in-app y (espejo) por el Kotlin.
2. `lib/services/calculator_history_store.dart`
   - CRUD sobre `calc_history_json`: `loadAll()`, `append(expr,result)`, `rename(id,name)`,
     `delete(id)`, `clearAll()`. Tras cada cambio: `_notify()` → `updateCalculatorWidget`.
   - Modelo `CalcHistoryEntry`.
3. `lib/services/calculator_style_service.dart`
   - `CalculatorStyleConfig` (snapshot mutable) + `CalculatorStyleService` con
     `widgets`-style spec mínimo, `load()`, `setInt/setBool/setString`, `resetAll()`,
     `def*` (defaults espejo del Kotlin). Mismo molde que
     `lib/services/widget_config_service.dart`.
   - Propiedades configurables (estándar de personalización, por grupo de elemento):
     - **Contorno del widget**: color de fondo, imagen/transparencia (alpha), radio de esquinas.
     - **Display (expresión + resultado)**: color de fondo, color/tamaño de texto de expresión,
       color/tamaño de resultado, alineación, radio.
     - **Botones por grupo** (números / operadores / función `C ⌫ ( ) %` / igual `=`):
       color de fondo, color de texto/icono, tamaño de texto, radio de esquinas, override de
       icono PNG opcional por tecla clave (=, ⌫, expandir, historial).
     - **Layout**: espaciado entre botones, padding del teclado, escala de contenido (%).
     - Toggles: mostrar fila de funciones científicas básicas (paréntesis/%), etc.
4. `lib/widgets/calculator_widget_preview.dart`
   - Preview en vivo (Dart) que dibuja la calculadora con `CalculatorStyleConfig` — refleja
     cambios mientras se ajustan. Debe verse igual que el RemoteViews real.
5. `lib/screens/emisor/calculator_widget_editor_screen.dart`
   - Editor con preview fija arriba (`NestedScrollView` + `SliverPersistentHeader`+`TabBar`)
     y pestañas (Contorno / Display / Botones / Layout / Iconos). Controles reutilizables
     tipo `_sliderTile`/`_colorTile`/`_iconTile` (mismo molde que
     `lib/screens/emisor/widget_editor_screen.dart`, incl. `showWidgetColorPicker`). Botón
     "Restablecer".
6. `lib/screens/emisor/calculator_screen.dart` (pantalla in-app, Herramientas)
   - Calculadora funcional completa con el estilo de `CalculatorStyleConfig`.
   - Botón expandir (ventana de expresión multilínea) y botón historial.
   - Panel de historial: lista con cargar (seguir operando), **renombrar** (TextField/diálogo),
     **eliminar** entrada, y eliminar todo. Operar y pulsar `=` **agrega** al historial.

## Archivos nuevos — Android nativo

7. `android/app/src/main/kotlin/com/example/connect/CalculatorWidgetProvider.kt`
   - `AppWidgetProvider`. `onUpdate`/`onReceive` con acciones:
     `DIGIT`(extra valor), `OP`, `PAREN`, `DOT`, `PERCENT`, `SIGN`, `CLEAR`, `BACKSPACE`,
     `EQUALS`, `TOGGLE_EXPAND`, `TOGGLE_HISTORY`, `HIST_UP`, `HIST_DOWN`, `LOAD_HIST`(extra id).
   - Estado por `appWidgetId` en `calc_widget_ui`. `EQUALS` evalúa (evaluador Kotlin espejo),
     muestra resultado y **append** a `flutter.calc_history_json`.
   - `buildRemoteViews`: lee `readCalcCfg(prefs)` (espejo de `def*`), pinta display + teclado;
     aplica colores/tamaños/radios dibujando fondos de botón a `Bitmap`/`GradientDrawable`
     según el radio (RemoteViews no estiliza esquinas directamente → usar
     `setImageViewBitmap` o `setInt(...,"setBackgroundResource"/"setBackgroundColor")` +
     drawables; para radio variable, generar drawable con `GradientDrawable` y aplicarlo como
     bitmap de fondo donde haga falta). Iconos override vía base64 como en música.
   - `companion object updateAll(context)` + paginación de historial (patrón clima).
8. `android/app/src/main/res/layout/widget_calculator.xml`
   - RemoteViews: contorno con `widget_calc_root` (fondo+radio), `widget_calc_display`
     (expresión), `widget_calc_result`, fila superior con botones expandir/historial, grid
     de teclado (filas de `LinearLayout`), y un contenedor `widget_calc_history` (filas
     paginadas + ▲▼) que se alterna por visibilidad. Solo Views soportadas por RemoteViews.
9. `android/app/src/main/res/xml/calculator_widget_info.xml`
   - `appwidget-provider` (initialLayout, minWidth/Height ~ 2x3, resizeMode,
     `updatePeriodMillis="0"`, `widgetCategory="home_screen"`).

## Archivos a MODIFICAR

10. `android/app/src/main/AndroidManifest.xml` — añadir `<receiver
    android:name=".CalculatorWidgetProvider">` con intent-filter `APPWIDGET_UPDATE`,
    `BIND_APPWIDGET`, y meta-data `@xml/calculator_widget_info` (junto a los otros receivers,
    L181–239).
11. `android/app/src/main/kotlin/com/example/connect/MainActivity.kt` — en el handler del
    MethodChannel añadir `"updateCalculatorWidget" -> { CalculatorWidgetProvider.updateAll(
    applicationContext); result.success(true) }` (junto a `updateWidget`/`updateWeatherWidget`,
    ~L1321–1336).
12. `lib/services/ble_service.dart` — añadir `static Future<bool> updateCalculatorWidget()`
    (espejo de `updateWidget`, ~L233).
13. `lib/screens/emisor/widgets_config_screen.dart` — añadir un `Card`/`ListTile`
    "Widget de calculadora" que navega a `CalculatorWidgetEditorScreen` (junto a la card de
    clima y la lista de música). Así aparece tanto en ajustes de emisor como en la pestaña
    embebida del receptor (ya reutilizan `WidgetsConfigScreen`).
14. `lib/screens/emisor/herramientas_screen.dart` — añadir un `_tool(...)` "Calculadora"
    que navega a `CalculatorScreen`.

## Reglas que se respetan (de las 3 skills)

- Defaults **espejo** Flutter↔Kotlin para cada propiedad de estilo.
- Claves canónicas `widget_cfg_calc_<prop>` y `calc_history_json` (contrato en ambos lados;
  Kotlin con prefijo `flutter.`).
- Persistir estilo en `onChangeEnd` (no por frame); preview en memoria con `setState`.
- Estándar de personalización: por cada elemento (contorno, display, cada grupo de botones)
  exponer color/tamaño/radio/espaciado/icono que aplique; preview en vivo; reset.
- Los 7 puntos al añadir un widget: layout xml · info xml · provider · receiver manifest ·
  hook en MainActivity · entrada en el registro/lista de widgets · rama en la preview Dart.
- Estructura del editor en pestañas siguiendo `receptor-screen-tabs` (no tocar core, solo UI).

## Verificación

1. `flutter analyze` sin errores nuevos; revisar evaluador con casos:
   `1+2*3`, `(1+2)*3`, `2+`, `5/0`, decimales y `%`, signo `+/−`.
2. `flutter build apk --debug` compila (Kotlin + Flutter).
3. Manual en dispositivo:
   - Añadir el widget de calculadora a la home; operar; `=` muestra resultado y se guarda.
   - Botón expandir alterna la vista de expresión; botón historial pagina y al tocar una
     entrada la carga y permite seguir operando (y guarda la nueva).
   - Editor: cambiar colores/tamaños/radios/transparencia/iconos → la preview refleja en vivo
     y el widget de la home se repinta; "Restablecer" vuelve a defaults.
   - Herramientas → Calculadora: mismo estilo; renombrar, editar nombre y eliminar entradas
     del historial; seguir operando sobre una entrada; los cambios se ven reflejados también
     en el widget.
4. Si el usuario acepta (regla del proyecto CLAUDE.md): `flutter build apk --split-per-abi`
   y copiar los 3 APK a `releases/` renombrados con la versión de `pubspec.yaml`.

## Notas / posibles ajustes durante la implementación

- El estilado de **radio de esquinas** en RemoteViews requiere generar drawables
  (`GradientDrawable`) a `Bitmap` por grupo de botón; si resulta costoso para todas las teclas,
  se aplicará radio al contorno + a fondos de grupo (no por tecla individual) manteniendo la
  preview Dart fiel a esa misma decisión.
- Evaluador duplicado Dart/Kotlin: mantener la misma precedencia y manejo de errores para que
  el resultado del widget y de la app coincidan.
