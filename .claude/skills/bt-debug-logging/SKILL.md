---
name: bt-debug-logging
description: Cómo emitir y leer logs de depuración del receptor a través de la conexión Bluetooth Classic emisor↔receptor en la app connect. Úsala al instrumentar/depurar cualquier funcionalidad del receptor (notificaciones, media, respuestas, navegación) que ocurre en segundo plano o en el dispositivo remoto y quieres ver qué pasa sin un cable USB.
---

# Debug logging por Bluetooth (emisor ↔ receptor)

La app `connect` tiene dos roles conectados por **Bluetooth Classic (RFCOMM/SPP)**.

**Arquitectura real de la conexión (importante, no es simétrica):**
- El **RECEPTOR corre `BtClassicServerService`** (servidor BT, acepta conexiones) —
  lo arrancan las pantallas `lib/screens/receptor/conexion_screen.dart` y
  `receptor_ble_signal_screen.dart` vía `BleService.startBtServer()`.
- El **EMISOR corre `BtClassicClient`** (cliente BT, inicia la conexión hacia el
  receptor) — lo dispara `lib/screens/emisor/seleccion_bl_screen.dart` vía
  `BleService.connectToPeer(address)`.

Para depurar lo que ocurre en el receptor (muchas veces en un isolate de fondo,
sin USB conectado), se envían mensajes estructurados `debug_log` por ese mismo
socket Bluetooth hacia el emisor, y se capturan con
`flutter logs`/`flutter run > archivo.txt` apuntando al **emisor** (ahí es
donde llegan los logs reenviados).

Usa este mecanismo cuando agregues o depures lógica del receptor y quieras
trazas: en vez de solo `print()` local (que no ves si el dispositivo no está
cableado), reenvía además el mensaje por BT al emisor.

## Cómo emitir un log (Dart) — método recomendado

### `BleService.sendDebugLogToPeers(source, message)` — directo y confiable

Es la forma **recomendada para logging frecuente** (cada mensaje, cada render,
resultados parciales de STT, etc.). Llama nativamente
`BtClassicServerService.sendDebugLogToPeers(source, message)`
**directo y síncrono, sin `Intent`/`startForegroundService`** — el mismo
patrón que usa `media_state` (`BtClassicClient.send(json)` en
[BtClassicClient.kt](../../../android/app/src/main/kotlin/com/example/connect/BtClassicClient.kt#L915)
para enviar, llamado directamente sobre el objeto que ya tiene el socket
activo, sin pasar por ningún Intent).

```dart
import 'package:connect/services/ble_service.dart';

unawaited(BleService.sendDebugLogToPeers('mi_funcionalidad', 'evento x id=$id estado=$estado'));
```

Patrón helper recomendado cuando vas a loguear varias veces en una clase
(combina print local simple + reenvío):

```dart
void _log(String message) {
  print('[mi_tag] $message'); // print simple, no debugPrint: no se trunca/throttlea
  try {
    unawaited(BleService.sendDebugLogToPeers('mi_tag', message));
  } catch (_) {}
}
```

Implementación Dart: [BleService.sendDebugLogToPeers](../../../lib/services/ble_service.dart).
Implementación nativa: caso `"sendDebugLogToPeers"` en el canal
`com.example.connect/ble` de
[MainActivity.kt](../../../android/app/src/main/kotlin/com/example/connect/MainActivity.kt),
que llama directo a
[BtClassicServerService.sendDebugLogToPeers](../../../android/app/src/main/kotlin/com/example/connect/BtClassicServerService.kt#L93)
(`instance?.sendDebugToPeers(...)`, sin Intent).

### ⚠️ Método legacy — `sendBtServerMessage` con `type: 'debug_log'` (NO usar para logging frecuente)

Existe también `BleService.sendBtServerMessage({'type': 'debug_log', ...})`,
usado originalmente en toda la app. **No lo uses para logging nuevo**: construye
un `Intent` y llama `startForegroundService(ACTION_SEND_TO_PEERS)` en cada
invocación. Android limita agresivamente cuántas veces por minuto se puede
llamar `startForegroundService` desde el mismo proceso — con logging chatty
(un log por mensaje renderizado, por resultado parcial de STT, etc.) la
mayoría de esas llamadas se descartan **en silencio**, sin error visible, y
los logs simplemente no llegan al peer. Esto fue diagnosticado tras observar
que el reenvío de logs de la pantalla de conversación nunca aparecía en el
receptor, mientras que `media_state` (que usa la llamada directa) sí
funcionaba siempre.

Si encuentras código viejo con este patrón, migra a `sendDebugLogToPeers`.

### Caso isolate de fondo (bt_hive / receptor headless)

Cuando estás dentro del entrypoint `btHiveMain` o de un servicio nativo headless
donde `BleService` no aplica (ese canal vive en el engine principal, no en el
engine headless de `BtClassicServerService`), usa el bridge
`com.example.connect/bt_hive_bridge` con el método `sendDebugLog` (ver `sendDebug`
en [main.dart](../../../lib/main.dart#L86)):

```dart
final btChannel = MethodChannel('com.example.connect/bt_hive_bridge');
await btChannel.invokeMethod('sendDebugLog', {
  'source': 'bt_hive_rx',
  'message': 'onBtNotification start id=$id',
}); // envuelto en try/catch
```

Este canal SÍ es directo (ver `"sendDebugLog"` en el `MethodChannel` que
`BtClassicServerService` registra para su engine embebido en `btHiveMain`,
[BtClassicServerService.kt](../../../android/app/src/main/kotlin/com/example/connect/BtClassicServerService.kt#L240)):
llama `sendDebugToPeers(source, message)` directo, sin Intent. Solo es
alcanzable desde Dart que corre en ese isolate headless, no desde el engine
principal de UI.

## Cómo emitir un log (Kotlin / nativo)

Desde un servicio nativo del receptor, llama siempre el helper estático
directo:

```kotlin
BtClassicServerService.sendDebugLogToPeers("mi_source_nativo", "mensaje")
```

`MainActivity.sendBtDebug(...)` y `LocalNotificationManager.sendBtDebug(...)`
ya delegan en este helper directo (fueron migrados desde el patrón
Intent/`startForegroundService` por el mismo problema de rate-limit).

## Dónde aparecen los logs (lectura)

1. **logcat del peer que recibe (el EMISOR)** — el nativo imprime al recibir el JSON:
   - en `BtClassicClient.kt` (el emisor es el cliente BT que recibe del servidor/receptor):
     `[btclassic][debug][<source>][<ts>] <message>`
     ([BtClassicClient.kt](../../../android/app/src/main/kotlin/com/example/connect/BtClassicClient.kt#L247))
   - Filtra con: `adb logcat | grep btclassic`
   - **Captura recomendada**: `flutter logs > salida.txt` (o `flutter run > salida.txt`)
     apuntando al dispositivo **emisor** — `flutter logs`/`flutter run` incluyen
     TODO el logcat del proceso de la app (no solo `I/flutter`), así que estas
     líneas nativas SÍ quedan en el archivo.

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
- **Nunca bloquees ni lances**: `unawaited(...)` o `try/catch` vacío. El logging
  jamás debe romper la funcionalidad que estás depurando.
- **Para logging frecuente, usa siempre `sendDebugLogToPeers`** (directo), nunca
  `sendBtServerMessage` con `type: 'debug_log'` (Intent, rate-limited).
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
