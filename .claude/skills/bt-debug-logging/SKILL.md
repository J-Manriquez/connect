---
name: bt-debug-logging
description: Cómo emitir y leer logs de depuración del receptor a través de la conexión Bluetooth Classic emisor↔receptor en la app connect. Úsala al instrumentar/depurar cualquier funcionalidad del receptor (notificaciones, media, respuestas, navegación) que ocurre en segundo plano o en el dispositivo remoto y quieres ver qué pasa sin un cable USB.
---

# Debug logging por Bluetooth (emisor ↔ receptor)

La app `connect` tiene dos roles conectados por **Bluetooth Classic (RFCOMM/SPP)**:
emisor y receptor. Para depurar lo que ocurre en el receptor (muchas veces en un
isolate de fondo, sin USB conectado), se envían mensajes estructurados
`debug_log` por ese mismo socket Bluetooth. El otro extremo los imprime a logcat
y/o los reemite al `logStream` de Flutter.

Usa este mecanismo cuando agregues o depures lógica del receptor y quieras
trazas: en vez de `print()` (que no ves si el dispositivo no está cableado),
manda un `debug_log` por BT.

## Cómo emitir un log (Dart)

### Caso normal — UI / isolate principal
Vía [BleService.sendBtServerMessage](../../../lib/services/ble_service.dart#L196).
Es la forma estándar usada en toda la app. **Fire-and-forget**, nunca bloquea ni
lanza:

```dart
import 'package:connect/services/ble_service.dart';

unawaited(BleService.sendBtServerMessage({
  'type': 'debug_log',
  'source': 'mi_funcionalidad',          // tag corto del contexto
  'message': 'evento x id=$id estado=$estado', // pares key=value
  'timestamp': DateTime.now().millisecondsSinceEpoch,
}));
```

Patrón helper recomendado (copiado de `_btDebug` en
[main.dart](../../../lib/main.dart#L364)) cuando vas a loguear varias veces en
una clase:

```dart
Future<void> _btDebug(String message) async {
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  try {
    print('[${DateTime.fromMillisecondsSinceEpoch(nowMs).toIso8601String()}][mi_tag] $message');
  } catch (_) {}
  try {
    await BleService.sendBtServerMessage({
      'type': 'debug_log',
      'source': 'mi_tag',
      'message': message,
      'timestamp': nowMs,
    });
  } catch (_) {}
}
```

### Caso isolate de fondo (bt_hive / receptor headless)
Cuando estás dentro del entrypoint `btHiveMain` o de un servicio nativo headless
donde `BleService` no aplica, usa el bridge `com.example.connect/bt_hive_bridge`
con el método `sendDebugLog` (ver `sendDebug` en
[main.dart](../../../lib/main.dart#L86)):

```dart
final btChannel = MethodChannel('com.example.connect/bt_hive_bridge');
await btChannel.invokeMethod('sendDebugLog', {
  'source': 'bt_hive_rx',
  'message': 'onBtNotification start id=$id',
}); // envuelto en try/catch
```

El lado nativo (`BtClassicServerService` / `BtClassicClient`) lo envuelve como
`{type:debug_log, source, message, timestamp}` y lo difunde a los peers con
`sendDebugToPeers`.

## Cómo emitir un log (Kotlin / nativo)

Desde un servicio nativo del receptor:

```kotlin
BtClassicServerService.sendDebugLogToPeers("mi_source_nativo", "mensaje")
```

Helpers nativos equivalentes existen en `MainActivity`, `LocalNotificationManager`
y `BtClassicServerService` (todos construyen el mismo JSON `type=debug_log`).

## Dónde aparecen los logs (lectura)

1. **logcat del peer que recibe** — el nativo imprime al recibir el JSON:
   - servidor: `[btclassic][server][peer_debug][<source>][<ts>] <message>`
     ([BtClassicServerService.kt](../../../android/app/src/main/kotlin/com/example/connect/BtClassicServerService.kt#L760))
   - cliente: `[btclassic][debug][<source>][<ts>] <message>`
     ([BtClassicClient.kt](../../../android/app/src/main/kotlin/com/example/connect/BtClassicClient.kt#L242))
   - Filtra con: `adb logcat | grep btclassic`

2. **`BleService.logStream` en Flutter** — los managers GATT reemiten eventos vía
   `onBleLog`, que [BleService.initialize](../../../lib/services/ble_service.dart#L62)
   empuja a `logStream`. En [main.dart](../../../lib/main.dart#L384)
   `_MainAppState.initState` se suscribe, filtra `type == 'debug_log'` e imprime
   `[<iso_ts>][bt_debug][<source>] <message>`. Para consumirlo en otra pantalla:

   ```dart
   final sub = BleService.logStream.listen((e) {
     if ((e['type'] ?? e['event']) != 'debug_log') return;
     // e['source'], e['message'], e['timestamp']
   });
   // recuerda sub.cancel() en dispose()
   ```

## Convenciones

- **`source`**: tag corto y estable por contexto (`receptor_nav`, `bt_hive_rx`,
  `ble_rx`, `flutter_open_detail`, `media_state`, …). Sirve para filtrar.
- **`message`**: pares `key=value` legibles. Trunca textos largos
  (p. ej. `title="${t.length > 60 ? t.substring(0,60) : t}"`).
- **`timestamp`**: siempre `DateTime.now().millisecondsSinceEpoch`.
- **Nunca bloquees ni lances**: `unawaited(...)` o `try/catch` vacío. El logging
  jamás debe romper la funcionalidad que estás depurando.
- **Rate-limit**: para fuentes muy ruidosas (ej. `media_state`) el nativo ya
  descarta repetidos < 1200 ms; ten en cuenta que algunos logs se omiten a
  propósito.

## Otros mensajes del protocolo BT (RFCOMM)

Por el mismo socket viajan mensajes JSON con `type`, manejados en el `when/if (type)`
de [BtClassicClient.handleIncomingPayload](../../../android/app/src/main/kotlin/com/example/connect/BtClassicClient.kt#L183)
y del lado servidor en [BtClassicServerService](../../../android/app/src/main/kotlin/com/example/connect/BtClassicServerService.kt).
Tipos relevantes (además de `debug_log`, `notif_reply`, `media_*`):

- **`firebase_link`** `{deviceId}` — **auto-vínculo BT→Firebase**. El EMISOR
  (detectado por `NotificationListener.isRunning`) envía su `device_id` de
  Firestore al conectar (`maybeSendFirebaseLink`, en `connected`/`accept`). El
  RECEPTOR lo guarda en `flutter.linked_device_id` (SharedPreferences) y avisa a
  Dart vía `onFirebaseLink` ([main.dart `btHiveMain`](../../../lib/main.dart)) →
  `ReceptorService.saveLinkedDeviceId` (estado de vínculo en Firebase + sync).
  La pantalla de vinculación `ReceptorScreen` sondea cada 2s y navega cuando
  aparece el id. Esto cura el desvínculo tras reinstalar (el emisor regenera su
  `device_id`).
- **`query_notif_active`** `{sbnKey, requestId}` / **`notif_active_state`**
  `{sbnKey, active, requestId}` — indicador "¿la notificación sigue en la barra
  del emisor?". El que muestra la conversación consulta; el emisor responde con
  `NotificationListener.isNotificationActive(sbnKey)`. Ver detalle en la skill
  [[floating-ball-conversation-screen]].

### Patrón clave: puente entre isletas con SharedPreferences (NO Hive)

Los servicios BT corren en una **isleta de fondo** (entrypoint `btHiveMain`),
distinta de la isleta de UI. **Hive NO comparte escrituras de forma fiable entre
isletas** (cada una tiene su copia en memoria). Para pasar datos de la isleta de
fondo a la UI usa **SharedPreferences nativas**: el nativo escribe
`getSharedPreferences("FlutterSharedPreferences").edit().putString("flutter.<key>", json).apply()`
y la UI lee con `prefs.reload()` + `getString('<key>')` (sin el prefijo
`flutter.`). Así están implementados `bt_notif_active_last` y `linked_device_id`.
Es el mismo patrón que ya usaba `media_default_app`.

## Relacionado (no confundir)

[DebugLogsScreen](../../../lib/screens/debug_logs_screen.dart) es un visor de
logcat **local** (canal `com.example.connect/debug_logs`, método `getRecentLogs`)
para depurar notificaciones en Android 8. No usa Bluetooth ni el `logStream`; es
un mecanismo distinto.
