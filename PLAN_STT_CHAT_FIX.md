# Plan: STT sin IA + Fix pantallas de chat

## Cambios 1 — STT: eliminar módulo IA del flujo, UI tap-único

### Problema actual
El flujo STT en el receptor envía el texto por BT al emisor (`stt_reply_request`),
donde el módulo IA lo corrige antes de responder WhatsApp. Esto agrega latencia y
dependencia del módulo IA estando cargado.

### Solución
El STT transcribe en el mismo dispositivo (receptor o emisor) y el texto va
directamente al TextField de respuesta. El usuario puede editar antes de enviar.
No hay corrección IA.

### Archivos afectados

#### `lib/widgets/stt_mic_button.dart` — REESCRIBIR
- Eliminar `SttButtonMode` enum (ya no hay modo `holdToRecord`)
- Tap único sobre el ícono → abre `showModalBottomSheet`
- El modal es un `StatefulWidget` autónomo que:
  - Arranca STT automáticamente al abrirse
  - Muestra un `TextField` grande y editable (min 4 líneas) con la transcripción
    (se actualiza con resultados parciales)
  - Indicador de estado: "Escuchando…" con ícono pulsante rojo / "Detenido"
  - Fila de 3 botones:
    1. **Reiniciar** (`Icons.refresh`): limpia texto + reinicia grabación
    2. **Detener** (`Icons.stop`): detiene grabación, texto queda en TextField
    3. **Enviar** (`Icons.send`): detiene si activo, llama `onResult(text)` y cierra
- Gestión de permisos de micrófono conservada
- STT no disponible → diálogo explicativo

#### `lib/screens/receptor/notification_detail_screen.dart`
- `SttMicButton.onResult`: ya no llama `_sendSttReply`. En su lugar hace
  `_replyController.text = text` para poblar el TextField de respuesta.
- Eliminar método `_sendSttReply()`
- El usuario revisa/edita el texto y toca enviar normalmente

#### `lib/screens/emisor/floating_ball_conversation_screen.dart`
- En `_openReplyDialog`, el `SttMicButton` ya no hace `Navigator.of(ctx).pop(sttText)`.
  En su lugar `onResult: (text) { controller.text = text; }` para poblar el TextField
  del diálogo de respuesta.
- El usuario sigue en el diálogo, revisa el texto y toca enviar.

#### `lib/services/ble_service.dart`
- Eliminar método `sendSttReplyRequest`

#### `lib/main.dart`
- Eliminar case `'onSttReplyRequest'` del switch en `btHiveMain`

#### `android/app/src/main/kotlin/com/example/connect/BtClassicClient.kt`
- Eliminar handler del tipo de mensaje `stt_reply_request`
- Eliminar llamada a `btHiveChannel?.invokeMethod("onSttReplyRequest", ...)` 

---

## Cambios 2 — Fix pantallas de chat: orden, historial y paginación

### Problema actual

**`notification_detail_screen.dart`**
- Ventana inicial de SOLO 5 mensajes centrada en `selectedIndex`
- Si `selectedIndex` apunta a un mensaje no reciente → muestra mensajes viejos

**`floating_ball_conversation_screen.dart`**
- Ventana inicial de 20 mensajes (±10 alrededor de `focusIdx`)
- Puede no mostrar los últimos mensajes si `focusIdx` no está al final

**Ambas pantallas**
- Al recargar después de respuesta, la ventana se recalcula y puede mostrar
  mensajes distintos a los esperados
- Paginación expande de a 5 mensajes: lento

### Solución

Para **ambas** pantallas:
- Ventana inicial siempre en los ÚLTIMOS 20 mensajes del historial
  - `_windowStart = max(0, total - 20)`
  - `_windowEnd = total`
- Si `selectedMessageId` NO está en esa ventana (es un mensaje viejo),
  aun así scrollear al final (los últimos mensajes son los más relevantes)
- Paginación aumentada a **10 mensajes** por paso al subir o bajar
- Después de enviar respuesta: ventana → últimos 20

### Archivos afectados

#### `lib/screens/receptor/notification_detail_screen.dart`
- `_loadConversationMessages`: cambiar cálculo de `start`/`end` inicial:
  ```dart
  // ANTES
  int start = (selectedIndex - 2).clamp(0, filtered.length);
  int end = (start + 5).clamp(0, filtered.length);
  start = (end - 5).clamp(0, filtered.length);
  
  // DESPUÉS
  int end = filtered.length;
  int start = (end - 20).clamp(0, end);
  ```
- `_maybeLoadMoreConversation`: expandir de 5 → 10 por paso
- `_sendConversationReply` optimistic: usar últimos 20, no últimos 15

#### `lib/screens/emisor/floating_ball_conversation_screen.dart`
- `_loadConversationMessages`: cambiar ventana inicial a últimos 20
- `_maybeLoadMoreConversation`: expandir de 5 → 10 por paso
- `_sendConversationReply` optimistic: usar últimos 20, no últimos 15

---

## Resumen de archivos

| Archivo | Tipo de cambio |
|---|---|
| `lib/widgets/stt_mic_button.dart` | Reescritura completa |
| `lib/screens/receptor/notification_detail_screen.dart` | STT + chat fix |
| `lib/screens/emisor/floating_ball_conversation_screen.dart` | STT + chat fix |
| `lib/services/ble_service.dart` | Eliminar `sendSttReplyRequest` |
| `lib/main.dart` | Eliminar case `onSttReplyRequest` |
| `android/.../BtClassicClient.kt` | Eliminar handler `stt_reply_request` |
