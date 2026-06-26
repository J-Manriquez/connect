# Módulo IA

Carpeta autocontenida pensada para copiarse a otra app Flutter sin depender del resto del proyecto. Corre un modelo de lenguaje **100% local** (sin nube, sin APIs) vía `flutter_gemma` (motor LiteRT-LM/MediaPipe), compatible con cualquier dispositivo Android con RAM suficiente — a diferencia de AICore/Gemini Nano, no depende de un allowlist de hardware.

## Qué incluye

- `models/ai_model_catalog.dart`: catálogo fijo de modelos compatibles (Gemma 3/3n/4, Qwen3, Phi-4 Mini, SmolLM), cada uno con tamaño, RAM recomendada, rating de calidad (1-5★), descripción, URL y hash SHA-256 esperado.
- `services/ai_model_repository.dart`: descarga, verificación de integridad (HTTPS forzado, tamaño máximo, SHA-256) y almacenamiento **privado por app** (`getApplicationDocumentsDirectory()/ai_models/`). Soporta reanudar descargas interrumpidas.
- `services/ai_service.dart`: **API pública única** que debe usar la app anfitriona.
- `screens/ai_model_manager_screen.dart`: pantalla para listar el catálogo, ver el detalle de un modelo (tamaño, RAM, rating, descripción) antes de descargarlo, y activar/eliminar modelos descargados.
- `screens/ai_chat_screen.dart`: pantalla de chat de prueba sobre `AiService`.

## Integración mínima en otra app

1. Agregar a `pubspec.yaml`: `flutter_gemma`, `flutter_secure_storage`, `path_provider`, `crypto`.
2. Copiar la carpeta `lib/modules/ai/` completa.
3. Usar únicamente:

```dart
import 'package:tu_app/modules/ai/ai_module.dart';

final ai = AiService.instance;
await ai.setActiveModel('gemma3n-e2b');
await ai.downloadModel('gemma3n-e2b', onProgress: (pct, _, __) { ... });
final texto = await ai.generateText(
  prompt: 'Resume esto en una frase: ...',
  systemInstruction: 'Eres un asistente breve.',
);
```

No hay "carpeta compartida entre apps": cada app descarga y guarda su propia copia privada del modelo. Compartir un mismo archivo entre apps vía almacenamiento externo no es confiable en Android moderno (Scoped Storage) salvo que el usuario otorgue `MANAGE_EXTERNAL_STORAGE`, así que se descartó ese enfoque.

## Agregar un modelo nuevo al catálogo

Añadir una entrada en `AiModelCatalog.entries` (`models/ai_model_catalog.dart`) con: `id`, `displayName`, `description`, `qualityRating` (1-5), `approxSizeBytes`, `minRecommendedRamMb`, `fileKind` (`.task`/`.litertlm`), `engineModelType`, `downloadUrl` (debe ser HTTPS) y `sha256`.

**Importante**: los hashes `sha256` en el catálogo actual están vacíos como placeholder — complétalos con el hash oficial publicado por cada modelo antes de usar este módulo en producción. Si `sha256` queda vacío, la descarga no se verifica (se documenta como limitación, no se bloquea para no romper el flujo en desarrollo).
