# Plan de Implementación — Lector TTS Línea a Línea

## Objetivo
Agregar un lector de texto con TTS (Text-to-Speech) línea a línea accesible desde el `AppBar` del Emisor, con resaltado de la línea activa, navegación por toque y configuración de voz.

---

## Arquitectura de pantallas nueva

```
EmisorScreen (AppBar)
  └── [ícono cajón ≡ leading]
        └── HerramientasScreen  (/herramientas)
              └── LectorTtsScreen  (/lector_tts)
                    └── Modal de configuración de voz (bottom sheet)
```

---

## Paso 1 — Agregar dependencia `flutter_tts`

**Archivo:** `pubspec.yaml`

Agregar bajo `dependencies:`:

```yaml
flutter_tts: ^4.2.5
```

Luego ejecutar:

```bash
flutter pub get
```

> **Por qué `flutter_tts` y no `sherpa_onnx`:** el proyecto ya no incluye `sherpa_onnx` en sus dependencias actuales. `flutter_tts` usa las voces del sistema (sin descargas), es más sencillo de integrar y adecuado para lectura interactiva línea a línea. Las voces Piper ONNX pueden añadirse en una iteración futura como opción avanzada en el modal de configuración.

---

## Paso 2 — Crear el servicio TTS

**Archivo nuevo:** `lib/services/tts_service.dart`

Responsabilidades:
- Encapsular la instancia de `FlutterTts`.
- Exponer `speak(String text)`, `stop()`, `pause()`.
- Exponer `setLanguage`, `setSpeechRate`, `setPitch`, `setVolume`.
- Exponer `getVoices()` para listar voces del dispositivo.
- Exponer `setVoice(Map<String,String> voice)`.
- Callback `onComplete` para avanzar automáticamente a la siguiente línea.
- Usar `ChangeNotifier` para que la UI pueda escuchar estado (reproduciendo / detenido).

```dart
// Estructura base
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

  bool isPlaying = false;
  double speechRate = 0.5;
  double pitch = 1.0;
  double volume = 1.0;
  String language = 'es-MX';
  Map<String, String>? selectedVoice;

  Future<void> init() async { ... }
  Future<void> speak(String text) async { ... }
  Future<void> stop() async { ... }
  Future<List<Map>> getVoices() async { ... }
  Future<void> setVoice(Map<String, String> voice) async { ... }
  // setters para rate, pitch, volume, language con notifyListeners()
}
```

---

## Paso 3 — Crear la pantalla HerramientasScreen

**Archivo nuevo:** `lib/screens/emisor/herramientas_screen.dart`

Esta pantalla es un "cajón de aplicaciones" simple. Muestra una lista de opciones (tarjetas o `ListTile`). La primera y única opción de la primera iteración es **Lector TTS**.

### Estructura de UI

```
Scaffold
  AppBar: title = "Herramientas"
  Body: ListView
    ListTile #1
      leading: Icon(Icons.text_fields)          // ícono representativo
      title: "Lector TTS"
      subtitle: "Lee texto línea a línea en voz alta"
      trailing: Icon(Icons.arrow_forward_ios)
      onTap: Navigator.push → LectorTtsScreen
```

### Código clave

```dart
import 'package:flutter/material.dart';
import 'package:connect/screens/emisor/lector_tts_screen.dart';
import 'package:connect/theme_colors.dart';

class HerramientasScreen extends StatelessWidget {
  const HerramientasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Herramientas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.text_fields, color: customColor),
              title: const Text('Lector TTS'),
              subtitle: const Text('Lee texto línea a línea en voz alta'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LectorTtsScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Paso 4 — Crear la pantalla LectorTtsScreen

**Archivo nuevo:** `lib/screens/emisor/lector_tts_screen.dart`

### Estado interno

| Variable | Tipo | Descripción |
|---|---|---|
| `_rawText` | `String` | Texto completo pegado por el usuario |
| `_lines` | `List<String>` | Texto dividido por `\n`, líneas vacías filtradas |
| `_currentLineIndex` | `int` | Índice de la línea en reproducción (-1 = detenido) |
| `_isPlaying` | `bool` | Estado del reproductor |
| `_scrollController` | `ScrollController` | Para auto-scroll a la línea activa |
| `_ttsService` | `TtsService` | Instancia del servicio |

### Lógica principal

#### División del texto en líneas
```dart
List<String> _splitLines(String text) {
  return text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}
```

#### Iniciar lectura desde una línea
```dart
Future<void> _startFromLine(int index) async {
  if (index >= _lines.length) {
    setState(() { _isPlaying = false; _currentLineIndex = -1; });
    return;
  }
  setState(() { _currentLineIndex = index; _isPlaying = true; });
  _scrollToCurrentLine();
  await _ttsService.speak(_lines[index]);
}
```

#### Callback al terminar una línea → avanzar automáticamente
```dart
// En initState, registrar en TtsService:
_ttsService.onComplete = () {
  if (_isPlaying && _currentLineIndex >= 0) {
    _startFromLine(_currentLineIndex + 1);
  }
};
```

#### Toque sobre una línea diferente
```dart
void _onLineTapped(int index) {
  _ttsService.stop();
  _startFromLine(index);
}
```

#### Auto-scroll
```dart
void _scrollToCurrentLine() {
  final itemHeight = 48.0; // altura aproximada por línea
  final offset = _currentLineIndex * itemHeight;
  _scrollController.animateTo(
    offset,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );
}
```

### Estructura de UI

```
Scaffold
  AppBar
    title: "Lector TTS"
    actions:
      IconButton(Icons.settings) → _openSettingsModal()

  Body: Column
    ┌─ Sección de entrada de texto (expandible, min 120px) ──────┐
    │  TextField(                                                  │
    │    maxLines: null,   // sin límite                          │
    │    keyboardType: TextInputType.multiline,                    │
    │    decoration: InputDecoration(                             │
    │      hintText: 'Pega tu texto aquí...',                     │
    │      border: OutlineInputBorder(),                          │
    │    ),                                                        │
    │    onChanged: (v) => setState(() { _rawText = v; ... }),    │
    │  )                                                           │
    └──────────────────────────────────────────────────────────────┘

    Row (controles de reproducción)
      ElevatedButton.icon
        icon: _isPlaying ? Icons.stop : Icons.play_arrow
        label: _isPlaying ? "Detener" : "Reproducir"
        onPressed: _isPlaying ? _stopReading : () => _startFromLine(0)

    Divider

    ┌─ Lista de líneas (Expanded) ────────────────────────────────┐
    │  ListView.builder(                                           │
    │    itemCount: _lines.length,                                 │
    │    itemBuilder: (ctx, i) {                                   │
    │      final isActive = i == _currentLineIndex;               │
    │      return GestureDetector(                                 │
    │        onTap: () => _onLineTapped(i),                       │
    │        child: AnimatedContainer(                            │
    │          color: isActive                                     │
    │            ? customColor[100]   // resaltado suave          │
    │            : Colors.transparent,                            │
    │          padding: EdgeInsets.all(8),                         │
    │          child: Text(                                        │
    │            _lines[i],                                        │
    │            style: TextStyle(                                 │
    │              fontSize: isActive ? 17 : 15,                  │
    │              fontWeight: isActive                            │
    │                ? FontWeight.bold : FontWeight.normal,        │
    │              color: isActive ? customColor[800] : null,     │
    │            ),                                                │
    │          ),                                                  │
    │        ),                                                    │
    │      );                                                      │
    │    },                                                        │
    │  )                                                           │
    └──────────────────────────────────────────────────────────────┘
```

---

## Paso 5 — Modal de configuración de voz

**Método:** `_openSettingsModal()` dentro de `LectorTtsScreen`

Se abre como `showModalBottomSheet` con `isScrollControlled: true`.

### Opciones del modal

| Control | Tipo | Descripción |
|---|---|---|
| Idioma | `DropdownButton` | Seleccionar locale (ej. `es-MX`, `es-ES`, `en-US`) |
| Voz | `DropdownButton` | Lista voces disponibles en el dispositivo vía `tts.getVoices` |
| Velocidad | `Slider` (0.1 – 1.0) | `speechRate` |
| Tono | `Slider` (0.5 – 2.0) | `pitch` |
| Volumen | `Slider` (0.0 – 1.0) | `volume` |

### Código clave del modal

```dart
void _openSettingsModal() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => _VoiceSettingsModal(
        ttsService: _ttsService,
        scrollController: scrollCtrl,
      ),
    ),
  );
}
```

El modal se implementa como `StatefulWidget` separado `_VoiceSettingsModal` para manejar su propio estado de sliders y dropdowns sin reconstruir la pantalla completa.

---

## Paso 6 — Agregar ícono al AppBar del Emisor

**Archivo:** `lib/screens/emisor/emisor_screen.dart`

Modificar el `AppBar` existente para agregar un `leading` con el ícono de cajón:

```dart
appBar: AppBar(
  leading: IconButton(
    icon: const Icon(Icons.apps),          // ícono cajón de apps
    tooltip: 'Herramientas',
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HerramientasScreen()),
    ),
  ),
  title: const Text('Emisor de Notificaciones'),
  actions: [ ... ],  // sin cambios
),
```

---

## Paso 7 — Registrar rutas (opcional)

Si el proyecto usa rutas nombradas en `main.dart`, agregar:

```dart
'/herramientas': (_) => const HerramientasScreen(),
'/lector_tts':   (_) => const LectorTtsScreen(),
```

Si no, la navegación directa con `MaterialPageRoute` (como se muestra en los pasos anteriores) es suficiente y no requiere modificar `main.dart`.

---

## Orden de implementación recomendado

| # | Tarea | Archivo |
|---|---|---|
| 1 | Agregar `flutter_tts: ^4.2.5` | `pubspec.yaml` |
| 2 | `flutter pub get` | terminal |
| 3 | Crear `TtsService` | `lib/services/tts_service.dart` |
| 4 | Crear `HerramientasScreen` | `lib/screens/emisor/herramientas_screen.dart` |
| 5 | Crear `LectorTtsScreen` (sin modal) | `lib/screens/emisor/lector_tts_screen.dart` |
| 6 | Crear `_VoiceSettingsModal` dentro de `lector_tts_screen.dart` | mismo archivo |
| 7 | Modificar `EmisorScreen` AppBar (leading) | `lib/screens/emisor/emisor_screen.dart` |
| 8 | (Opcional) Registrar rutas en `main.dart` | `lib/main.dart` |

---

## Notas de implementación

- **Sin límite de texto:** `TextField` con `maxLines: null` y `keyboardType: TextInputType.multiline` acepta texto de cualquier longitud. No hay que paginar; la lista de líneas renderiza solo las visibles gracias a `ListView.builder`.
- **Auto-scroll:** usar `GlobalKey` por línea o un `itemExtent` fijo en `ListView.builder` para calcular el offset con precisión.
- **Ciclo de vida:** llamar `_ttsService.stop()` en el `dispose()` de `LectorTtsScreen` para evitar que el TTS siga hablando al salir de la pantalla.
- **Android permisos:** `flutter_tts` no requiere permisos adicionales en Android para síntesis de voz del sistema.
- **Voces disponibles:** en dispositivos Android con pocas voces instaladas, el `DropdownButton` de voces puede mostrar pocas opciones. Esto es una limitación del dispositivo, no de la implementación.
- **`onComplete` en `flutter_tts`:** el callback `setCompletionHandler` se dispara cuando una llamada a `speak()` termina naturalmente (no por `stop()`). Usar este comportamiento para encadenar líneas automáticamente.
