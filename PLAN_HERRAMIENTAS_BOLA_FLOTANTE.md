# Plan de Implementación: Herramientas en la Bola Flotante

## Contexto técnico

La bola flotante es un **Android Foreground Service nativo en Kotlin** (`FloatingBallService.kt`)
que usa `WindowManager` para superponer vistas sobre cualquier app. La configuración se
comunica mediante `SharedPreferences` (prefijo `flutter.`) entre Flutter y Kotlin.
Los menús (popup compacto y pantalla completa) también son vistas nativas.

Los 4 widgets flotantes de herramientas deben ser **Android Views nativas** para que funcionen
sobre otras apps sin necesitar que la app principal esté en primer plano.

---

## Identificadores de herramientas

Los 4 ítems se identifican con el prefijo `tool:`:

| ID             | Herramienta   | Ícono Android              |
|----------------|---------------|----------------------------|
| `tool:tts`     | Lector TTS    | `ic_record_voice_over`     |
| `tool:dict`    | Diccionario   | `ic_menu_book`             |
| `tool:trans`   | Traductor     | `ic_translate`             |
| `tool:search`  | Buscar        | `ic_search`                |

---

## Fase 1 — Persistencia Flutter (`floating_ball_service.dart`)

### 1.1 Nuevas claves SharedPreferences

Agregar en la sección de constantes de `FloatingBallService`:

```dart
// Herramientas seleccionadas para el menú
static const String _keySelectedToolsJson = 'floating_ball_selected_tools_json';

// Offsets X/Y de cada widget flotante (en dp)
static const String _keyToolTtsOffsetX    = 'floating_ball_tool_tts_offset_x';
static const String _keyToolTtsOffsetY    = 'floating_ball_tool_tts_offset_y';
static const String _keyToolDictOffsetX   = 'floating_ball_tool_dict_offset_x';
static const String _keyToolDictOffsetY   = 'floating_ball_tool_dict_offset_y';
static const String _keyToolTransOffsetX  = 'floating_ball_tool_trans_offset_x';
static const String _keyToolTransOffsetY  = 'floating_ball_tool_trans_offset_y';
static const String _keyToolSearchOffsetX = 'floating_ball_tool_search_offset_x';
static const String _keyToolSearchOffsetY = 'floating_ball_tool_search_offset_y';
```

### 1.2 Nuevos métodos Flutter

```dart
static Future<List<String>> getSelectedTools() async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString(_keySelectedToolsJson);
  if (json == null || json.isEmpty) return [];
  return List<String>.from(jsonDecode(json) as List);
}

static Future<void> setSelectedTools(List<String> tools) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keySelectedToolsJson, jsonEncode(tools));
  _notifyNative();
}

// Getter/setter genérico para offsets
static Future<int> getToolOffsetX(String toolId) async { ... }
static Future<int> getToolOffsetY(String toolId) async { ... }
static Future<void> setToolOffsetX(String toolId, int value) async { ... }
static Future<void> setToolOffsetY(String toolId, int value) async { ... }
// Mapea toolId → clave usando un switch sobre _keyToolXxxOffsetX/Y
```

---

## Fase 2 — Selección de herramientas en configuración Flutter

### 2.1 Pantalla nueva: `floating_ball_tool_picker_screen.dart`

**Ruta**: `lib/screens/emisor/floating_ball_tool_picker_screen.dart`

- Lista estática de 4 ítems con `CheckboxListTile`
- Carga `getSelectedTools()` en `initState`
- Al cambiar un checkbox, llama `setSelectedTools()`
- Botón "Guardar" (o guardado automático por toggle)

```dart
final List<Map<String, dynamic>> _allTools = [
  {'id': 'tool:tts',    'title': 'Lector TTS',  'subtitle': 'Lee texto en voz alta', 'icon': Icons.record_voice_over},
  {'id': 'tool:dict',   'title': 'Diccionario',  'subtitle': 'Significado de palabras', 'icon': Icons.menu_book},
  {'id': 'tool:trans',  'title': 'Traductor',    'subtitle': 'Español ↔ Inglés', 'icon': Icons.translate},
  {'id': 'tool:search', 'title': 'Buscar',       'subtitle': 'Busca en el navegador', 'icon': Icons.search},
];
```

### 2.2 Modificación: `floating_ball_settings_screen.dart`

Dentro del `ExpansionTile` **"Aplicaciones del menú"**, agregar después del `ListTile`
"Seleccionar aplicaciones" un nuevo `ListTile`:

```dart
const Divider(),
ListTile(
  contentPadding: EdgeInsets.zero,
  title: const Text('Herramientas del menú'),
  subtitle: Text(_selectedToolsText),   // '3 seleccionadas' o 'Sin herramientas'
  trailing: TextButton(
    onPressed: _pickTools,
    style: linkBtnStyle,
    child: const Text('Seleccionar'),
  ),
),
```

Agregar en el estado `_FloatingBallSettingsScreenState`:

```dart
List<String> _selectedTools = [];

// En _loadState():
final tools = await FloatingBallService.getSelectedTools();
// En setState(): _selectedTools = tools;

String get _selectedToolsText => _selectedTools.isEmpty
    ? 'Sin herramientas seleccionadas'
    : '${_selectedTools.length} seleccionada(s)';

Future<void> _pickTools() async {
  await Navigator.push(context, MaterialPageRoute(
    builder: (_) => const FloatingBallToolPickerScreen(),
  ));
  await _loadState();
}
```

---

## Fase 3 — Reordenamiento de herramientas

### 3.1 `floating_ball_reorder_screen.dart` (pantalla completa)

**En `_load()`**: después de agregar los `pkg:` de apps seleccionadas, agregar las herramientas:

```dart
final selectedTools = await FloatingBallService.getSelectedTools();
for (final toolId in selectedTools) {
  if (!used.contains(toolId)) {
    nextOrder.add(toolId);
    used.add(toolId);
  }
}
```

**En `_titleForId()`**: agregar casos `tool:`:

```dart
if (id.startsWith('tool:')) {
  switch (id) {
    case 'tool:tts':    return 'Lector TTS';
    case 'tool:dict':   return 'Diccionario';
    case 'tool:trans':  return 'Traductor';
    case 'tool:search': return 'Buscar';
    default:            return id;
  }
}
```

**En `_iconForId()`**: agregar casos `tool:`:

```dart
if (id.startsWith('tool:')) {
  IconData icon = Icons.build;
  switch (id) {
    case 'tool:tts':    icon = Icons.record_voice_over; break;
    case 'tool:dict':   icon = Icons.menu_book;         break;
    case 'tool:trans':  icon = Icons.translate;         break;
    case 'tool:search': icon = Icons.search;            break;
  }
  return Icon(icon, color: Color(_fsIconColor), size: _fsIconSizeDp.toDouble());
}
```

### 3.2 `floating_ball_popup_reorder_screen.dart` (menú compacto)

Mismos cambios que en 3.1, adaptados a las variables `_popupIconColor` de la pantalla popup.

---

## Fase 4 — Configuración de posición X/Y por widget

### 4.1 Nueva sección en `floating_ball_settings_screen.dart`

Agregar una nueva `Card` con `ExpansionTile` **"Posición de widgets flotantes"** debajo de la sección de Personalización.
Solo visible si `_selectedTools.isNotEmpty`.

Para cada herramienta seleccionada, mostrar dos `ListTile` con `Slider` (rango -500 dp a 500 dp, paso 10):

```dart
Card(
  child: ExpansionTile(
    title: const Text('Posición de widgets flotantes'),
    subtitle: const Text('Ajusta dónde aparece cada widget al abrirse.'),
    children: [
      for (final toolId in _selectedTools) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(_toolLabel(toolId),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        _buildOffsetSlider('Posición X', toolId, 'x'),
        _buildOffsetSlider('Posición Y', toolId, 'y'),
        const Divider(),
      ],
    ],
  ),
),
```

```dart
Widget _buildOffsetSlider(String label, String toolId, String axis) {
  final value = axis == 'x' ? _getOffsetX(toolId) : _getOffsetY(toolId);
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    title: Text('$label: ${value.toInt()} dp'),
    subtitle: Slider(
      min: -500, max: 500, divisions: 100,
      value: value.toDouble(),
      activeColor: customColor[600],
      onChanged: (v) => setState(() => _setOffset(toolId, axis, v.toInt())),
      onChangeEnd: (v) => FloatingBallService.setToolOffsetX/Y(toolId, v.toInt()),
    ),
  );
}
```

Mantener en el estado un `Map<String, int> _toolOffsetsX` y `_toolOffsetsY`, cargados en `_loadState()`.

---

## Fase 5 — Lado nativo Kotlin (`FloatingBallService.kt`)

### 5.1 Nuevas constantes en el `companion object`

```kotlin
private const val KEY_SELECTED_TOOLS_JSON    = "flutter.floating_ball_selected_tools_json"
private const val KEY_TOOL_TTS_OFFSET_X      = "flutter.floating_ball_tool_tts_offset_x"
private const val KEY_TOOL_TTS_OFFSET_Y      = "flutter.floating_ball_tool_tts_offset_y"
private const val KEY_TOOL_DICT_OFFSET_X     = "flutter.floating_ball_tool_dict_offset_x"
private const val KEY_TOOL_DICT_OFFSET_Y     = "flutter.floating_ball_tool_dict_offset_y"
private const val KEY_TOOL_TRANS_OFFSET_X    = "flutter.floating_ball_tool_trans_offset_x"
private const val KEY_TOOL_TRANS_OFFSET_Y    = "flutter.floating_ball_tool_trans_offset_y"
private const val KEY_TOOL_SEARCH_OFFSET_X   = "flutter.floating_ball_tool_search_offset_x"
private const val KEY_TOOL_SEARCH_OFFSET_Y   = "flutter.floating_ball_tool_search_offset_y"
```

### 5.2 Variables de instancia

```kotlin
private var selectedTools: List<String> = emptyList()
private val toolViews = mutableMapOf<String, View?>()  // toolId → overlay View activo
```

### 5.3 Lectura de configuración

En el método `loadConfig()` (o donde se lee la config de SharedPreferences), agregar:

```kotlin
val toolsJson = prefs.getString(KEY_SELECTED_TOOLS_JSON, "[]") ?: "[]"
selectedTools = try {
    val arr = JSONArray(toolsJson)
    (0 until arr.length()).map { arr.getString(it) }
} catch (_: Exception) { emptyList() }
```

### 5.4 Renderizado de botones en el menú

En la función que construye los botones del menú (popup compacto y pantalla completa),
donde actualmente se itera sobre `pkg:` items, agregar iteración sobre `selectedTools`:

```kotlin
// En el bucle que construye botones por id de orden:
if (id.startsWith("tool:")) {
    addToolButton(container, id, iconColor, buttonColor, iconSizeDp)
}
```

```kotlin
private fun addToolButton(
    container: LinearLayout,
    toolId: String,
    iconColor: Int,
    bgColor: Int,
    iconSizeDp: Int
) {
    val btn = buildMenuButton(
        icon       = getToolIconDrawable(toolId, iconColor, iconSizeDp),
        label      = getToolLabel(toolId),
        bgColor    = bgColor,
        iconColor  = iconColor
    )
    btn.setOnClickListener {
        dismissMenu()
        openToolOverlay(toolId)
    }
    container.addView(btn)
}

private fun getToolLabel(toolId: String) = when (toolId) {
    "tool:tts"    -> "Lector TTS"
    "tool:dict"   -> "Diccionario"
    "tool:trans"  -> "Traductor"
    "tool:search" -> "Buscar"
    else          -> toolId
}
```

> **Nota**: Los íconos de herramientas se crean con `VectorDrawableCompat` usando los íconos
> del sistema Android (`search`, `translate`, etc.) o íconos vectoriales incluidos en el proyecto.

### 5.5 Función despachadora de overlays

```kotlin
private fun openToolOverlay(toolId: String) {
    // Si ya hay uno abierto, cerrarlo primero
    closeToolOverlay(toolId)

    when (toolId) {
        "tool:tts"    -> openTtsOverlay()
        "tool:dict"   -> openDictionaryOverlay()
        "tool:trans"  -> openTranslatorOverlay()
        "tool:search" -> openSearchOverlay()
    }
}

private fun closeToolOverlay(toolId: String) {
    toolViews[toolId]?.let {
        try { windowManager.removeView(it) } catch (_: Exception) {}
    }
    toolViews[toolId] = null
}
```

### 5.6 Función auxiliar de WindowManager params para overlays

```kotlin
private fun makeOverlayParams(offsetXDp: Int, offsetYDp: Int): WindowManager.LayoutParams {
    val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
    else
        @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE

    return WindowManager.LayoutParams(
        dpToPx(320),
        WindowManager.LayoutParams.WRAP_CONTENT,
        type,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
        PixelFormat.TRANSLUCENT
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = dpToPx(offsetXDp).coerceAtLeast(0)
        y = dpToPx(offsetYDp).coerceAtLeast(0)
    }
}
```

### 5.7 Función auxiliar de dragging

Todos los overlays usan el mismo `OnTouchListener` para ser arrastrables:

```kotlin
private fun makeDragTouchListener(
    params: WindowManager.LayoutParams,
    rootView: View,
    toolId: String
): View.OnTouchListener {
    var initialX = 0; var initialY = 0
    var initialTouchX = 0f; var initialTouchY = 0f
    return View.OnTouchListener { _, event ->
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                initialX = params.x; initialY = params.y
                initialTouchX = event.rawX; initialTouchY = event.rawY
                true
            }
            MotionEvent.ACTION_MOVE -> {
                params.x = initialX + (event.rawX - initialTouchX).toInt()
                params.y = initialY + (event.rawY - initialTouchY).toInt()
                windowManager.updateViewLayout(rootView, params)
                true
            }
            MotionEvent.ACTION_UP -> {
                // Persistir posición final
                saveToolOffset(toolId, params.x, params.y)
                true
            }
            else -> false
        }
    }
}

private fun saveToolOffset(toolId: String, xPx: Int, yPx: Int) {
    val xDp = pxToDp(xPx); val yDp = pxToDp(yPx)
    val (keyX, keyY) = getOffsetKeys(toolId)
    prefs.edit().putInt(keyX, xDp).putInt(keyY, yDp).apply()
}

private fun getOffsetKeys(toolId: String) = when (toolId) {
    "tool:tts"    -> Pair(KEY_TOOL_TTS_OFFSET_X,    KEY_TOOL_TTS_OFFSET_Y)
    "tool:dict"   -> Pair(KEY_TOOL_DICT_OFFSET_X,   KEY_TOOL_DICT_OFFSET_Y)
    "tool:trans"  -> Pair(KEY_TOOL_TRANS_OFFSET_X,  KEY_TOOL_TRANS_OFFSET_Y)
    "tool:search" -> Pair(KEY_TOOL_SEARCH_OFFSET_X, KEY_TOOL_SEARCH_OFFSET_Y)
    else          -> Pair("", "")
}
```

### 5.8 Widget Lector TTS (`openTtsOverlay`)

**Vista**: `LinearLayout` vertical con:
- **Header draggable**: barra con título "Lector TTS" + botón `✕` cerrar (fijo, no enfocable)
- **EditText** multilínea para pegar texto (`FLAG_NOT_FOCUSABLE` se quita solo en el campo)
- **Botones**: `▶ Reproducir` / `⏸ Pausar` / `⏹ Detener` / `⏭ Siguiente línea`
- **TextView** para mostrar la línea actual en lectura (highlight)

**Lógica**:
- Usar `android.speech.tts.TextToSpeech` directamente en Kotlin
- Dividir el texto por `\n` y leer línea a línea con `utteranceId`
- `onUtteranceCompleted` → avanzar al siguiente índice, actualizar TextView
- Al abrir el overlay, cambiar el flag a `FLAG_NOT_FOCUSABLE or FLAG_ALT_FOCUSABLE_IM`
  para permitir el teclado solo cuando se toca el EditText

```kotlin
private var tts: TextToSpeech? = null
private var ttsLines: List<String> = emptyList()
private var ttsCurrentLine = 0

private fun openTtsOverlay() {
    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    val offsetX = prefs.getInt(KEY_TOOL_TTS_OFFSET_X, 40)
    val offsetY = prefs.getInt(KEY_TOOL_TTS_OFFSET_Y, 200)
    val params  = makeOverlayParams(offsetX, offsetY)

    val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
    // ... construir la vista completa ...

    tts = TextToSpeech(this) { status ->
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale("es", "MX")
        }
    }

    windowManager.addView(root, params)
    toolViews["tool:tts"] = root

    val dragHandle = root.findViewById<View>(R.id.tts_drag_handle) // o la barra header
    dragHandle.setOnTouchListener(makeDragTouchListener(params, root, "tool:tts"))
}
```

### 5.9 Widget Diccionario (`openDictionaryOverlay`)

**Vista**: `LinearLayout` vertical con:
- **Header draggable**: título "Diccionario" + botón `✕`
- **Row**: `EditText` para la palabra + `Button` "Buscar"
- **ScrollView** con `TextView` para el resultado (definiciones formateadas)
- **ProgressBar** circular mientras carga

**Lógica** (petición HTTP en hilo secundario):
```kotlin
private fun searchDictionary(word: String, resultView: TextView, progress: ProgressBar) {
    progress.visibility = View.VISIBLE
    resultView.text = ""
    Thread {
        try {
            val url = java.net.URL(
                "https://api.dictionaryapi.dev/api/v2/entries/es/${
                    java.net.URLEncoder.encode(word.trim(), "UTF-8")
                }"
            )
            val conn = url.openConnection() as java.net.HttpURLConnection
            conn.connectTimeout = 10_000; conn.readTimeout = 10_000
            val response = conn.inputStream.bufferedReader().readText()
            val result = parseDictionaryResponse(response)  // parsea JSON → String formateado
            Handler(Looper.getMainLooper()).post {
                progress.visibility = View.GONE
                resultView.text = result
            }
        } catch (e: Exception) {
            Handler(Looper.getMainLooper()).post {
                progress.visibility = View.GONE
                resultView.text = "No se encontró definición para \"$word\""
            }
        }
    }.start()
}

private fun parseDictionaryResponse(json: String): String {
    // Parsear JSONArray → extraer meanings[].definitions[].definition
    // Retorna texto formateado con números y categorías gramaticales
}
```

### 5.10 Widget Traductor (`openTranslatorOverlay`)

**Vista**: `LinearLayout` vertical con:
- **Header draggable**: título "Traductor" + botón `✕`
- **Row**: dos `Button` para seleccionar dirección (ES→EN / EN→ES), con el activo destacado
- **EditText** para el texto a traducir
- **Button** "Traducir"
- **TextView** para el resultado

**Lógica** (petición HTTP en hilo secundario):
```kotlin
private fun translate(text: String, from: String, to: String, resultView: TextView, ...) {
    Thread {
        try {
            val encoded = java.net.URLEncoder.encode(text.trim(), "UTF-8")
            val url = java.net.URL(
                "https://api.mymemory.translated.net/get?q=$encoded&langpair=$from|$to"
            )
            // ... parsear JSON response.responseData.translatedText ...
        } catch (e: Exception) { /* mostrar error */ }
    }.start()
}
```

### 5.11 Widget Buscar (`openSearchOverlay`)

**Vista**: `LinearLayout` horizontal/vertical con:
- **Header draggable**: título "Buscar" + botón `✕`
- **EditText** para la consulta
- **Button** "Buscar en web"

**Lógica**:
```kotlin
private fun openWebSearch(query: String) {
    val intent = Intent(Intent.ACTION_VIEW,
        Uri.parse("https://www.google.com/search?q=${Uri.encode(query.trim())}"))
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    startActivity(intent)
}
```

> **Nota**: El Intent requiere `FLAG_ACTIVITY_NEW_TASK` porque se lanza desde un Service.

### 5.12 Manejo del foco del teclado para EditText en overlays

Por defecto los overlays usan `FLAG_NOT_FOCUSABLE`. Para permitir escritura en los `EditText`,
cuando el usuario toca un campo se debe cambiar el flag:

```kotlin
editText.setOnFocusChangeListener { _, hasFocus ->
    if (hasFocus) {
        params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()
    } else {
        params.flags = params.flags or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
    }
    windowManager.updateViewLayout(rootView, params)
}
```

---

## Fase 6 — Orden de los botones en el menú (reorder integrado)

El orden de los botones en el menú (tanto popup como pantalla completa) ya se gestiona por
`FloatingBallReorderScreen` y `FloatingBallPopupReorderScreen`. Los cambios de la Fase 3
permiten que los `tool:*` aparezcan en esas pantallas.

En el lado nativo (`FloatingBallService.kt`), cuando se lee el orden guardado:

```kotlin
val fsOrderJson = prefs.getString(KEY_FS_ORDER_JSON, "[]") ?: "[]"
val orderList = try {
    val arr = JSONArray(fsOrderJson)
    (0 until arr.length()).map { arr.getString(it) }
} catch (_: Exception) { emptyList<String>() }

// Añadir tools no incluidas en el orden guardado pero que están seleccionadas
val toolsNotInOrder = selectedTools.filter { it !in orderList }
val finalOrder = orderList + toolsNotInOrder
```

---

## Fase 7 — Cierres y limpieza

- Al destruir el Service (`onDestroy()`), cerrar todos los overlays activos:
  ```kotlin
  toolViews.forEach { (_, view) ->
      view?.let { try { windowManager.removeView(it) } catch (_: Exception) {} }
  }
  toolViews.clear()
  tts?.shutdown()
  ```

- Al recibir `ACTION_UPDATE_CONFIG`, recargar `selectedTools` y cerrar overlays de tools
  que ya no estén seleccionadas.

---

## Resumen de archivos a crear/modificar

### Archivos nuevos (Flutter)
| Archivo | Descripción |
|---------|-------------|
| `lib/screens/emisor/floating_ball_tool_picker_screen.dart` | Pantalla de selección de herramientas con 4 toggles |

### Archivos modificados (Flutter)
| Archivo | Cambio |
|---------|--------|
| `lib/services/floating_ball_service.dart` | +8 claves de offset, +métodos `getSelectedTools`, `setSelectedTools`, `getToolOffset*`, `setToolOffset*` |
| `lib/screens/emisor/floating_ball_settings_screen.dart` | +ListTile "Herramientas del menú", +Card "Posición de widgets flotantes", +estado `_selectedTools` |
| `lib/screens/emisor/floating_ball_reorder_screen.dart` | +soporte `tool:*` en `_load`, `_titleForId`, `_iconForId` |
| `lib/screens/emisor/floating_ball_popup_reorder_screen.dart` | +soporte `tool:*` igual que reorder_screen |

### Archivos modificados (Kotlin)
| Archivo | Cambio |
|---------|--------|
| `android/app/src/main/kotlin/com/example/connect/FloatingBallService.kt` | +9 constantes de keys, +`selectedTools`, +`toolViews`, +`openToolOverlay`, +4 funciones de overlay, +`makeDragTouchListener`, +`saveToolOffset`, +TTS instance, +HTTP helpers para dict y translator |

---

## Orden de implementación sugerido

1. **Fase 1** → Agregar claves y métodos en `floating_ball_service.dart`
2. **Fase 2** → Crear `floating_ball_tool_picker_screen.dart` y modificar settings
3. **Fase 3** → Extender las dos pantallas de reordenamiento
4. **Fase 4** → Agregar sliders de posición X/Y en settings
5. **Fase 5.1–5.3** → Agregar constantes y lectura de config en Kotlin
6. **Fase 5.4** → Renderizar botones `tool:*` en los menús nativos
7. **Fase 5.8** → Implementar overlay Buscar (el más simple, sin HTTP)
8. **Fase 5.9** → Implementar overlay Diccionario
9. **Fase 5.10** → Implementar overlay Traductor
10. **Fase 5.7** → Implementar overlay Lector TTS (el más complejo, con TTS engine)
11. **Fase 6** → Integrar orden en el renderizado nativo
12. **Fase 7** → Limpieza en onDestroy y onUpdateConfig
