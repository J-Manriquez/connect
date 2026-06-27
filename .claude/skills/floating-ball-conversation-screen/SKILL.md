---
name: floating-ball-conversation-screen
description: Funcionamiento, invariantes y sistema de estilos de la pantalla de conversación de la bola flotante (lib/screens/emisor/floating_ball_conversation_screen.dart). Léela ANTES de modificar esa pantalla, su modal de responder, el modal STT o el orden/visibilidad de mensajes, para no romper comportamientos ya validados.
---

# Pantalla de conversación de la bola flotante

Archivo: [floating_ball_conversation_screen.dart](../../../lib/screens/emisor/floating_ball_conversation_screen.dart).
Es la conversación a pantalla completa que abre la bola flotante (rol emisor).
La pantalla equivalente de la app (rol receptor) es
[notification_detail_screen.dart](../../../lib/screens/receptor/notification_detail_screen.dart);
comparten patrones — si cambias uno, revisa si aplica al otro.

## Entradas / navegación

- `FloatingBallConversationScreen({notificationData, startInConversationMode, openedFromBackground})`.
- `FloatingBallConversationAutoOpenEntry`: wrapper que lee el payload nativo
  (`MethodChannel com.example.connect/auto_open` → `getAutoOpenPayload`) y calcula
  `startInConversationMode`. Se usa en la ruta `/floating_ball_conversation_auto`.
- Rutas en [main.dart](../../../lib/main.dart): `/floating_ball_conversation` y
  `/floating_ball_conversation_auto`.

## Dos modos de display

- **Conversación** vs **notificaciones** (`_isConversationMode`).
- Se entra a conversación solo si **todas** se cumplen (`_initModeAndMaybeLoad`):
  `widget.startInConversationMode && pkg.isNotEmpty && title.isNotEmpty &&
  fsConversationEnabled && appConversationEnabled`.
  - `fsConversationEnabled` = `FloatingBallService.isFullScreenConversationEnabled()`.
  - `appConversationEnabled` = el paquete está en
    `PreferencesService.getConversationEnabledPackages()`.
- Si el modo es OFF, **no** se llama `_loadConversationMessages()` (es intencional).

## Pipeline de mensajes (`_loadConversationMessages`) — INVARIANTES

Orden de pasos; respétalo si refactorizas:

1. `_receptorService.fetchAllNotificationsAcrossDaysRawOnce()` como fuente
   principal. **Si devuelve vacío** (sin `linkedDeviceId` o error de red), cae
   a `BtHiveStorageService.getLocalNotificationsForUi(includeVisualized: true)`
   como fallback — esta cache Hive local contiene las notificaciones BT entrantes
   (outbox + firebase_cache) y evita mostrar la conversación completamente vacía.
   No elimines este fallback: es la única fuente de mensajes recibidos cuando
   el vínculo Firebase aún no está establecido.
2. Respuestas locales `BtHiveStorageService.getConversationRepliesForUi(...)`.
3. Filtro por `packageName == _packageName && title == _conversationTitle`;
   si quedan ≤1, **filtro de respaldo** por título normalizado
   (`_normalizeConversationKey`, contains en ambos sentidos). No lo elimines:
   evita conversaciones vacías por títulos ligeramente distintos.
4. Dedupe en `byId` (mapa por `_messageId`), respuestas locales pisan remotas.
5. **Inyección del disparador** (CRÍTICO): si `_selectedMessageId` no está en
   `byId`, se sintetiza desde `widget.notificationData`. Sin esto, la
   notificación que abre la pantalla a veces no se ve. La pantalla de la app
   hace lo mismo; mantenlas simétricas.
6. **Orden seguro** (CRÍTICO): se ordena con `_sortKeyMs(m, loadNowMs)`, que
   cae a `loadNowMs` (capturado UNA vez por carga) cuando el timestamp es 0.
   - Nunca ordenes con timestamp 0/epoch directo: manda mensajes a 1970 (orden
     incorrecto).
   - El fallback debe ser **determinista** (un `now` capturado antes de ordenar),
     NO `DateTime.now()` dentro del comparador (rompe el contrato del sort).
7. Ventana = últimos 20 (`_windowStart`/`_windowEnd`); luego `_scrollToBottom()`
   y `_scheduleVisibilityCheck()`.

`_messageTimestampMs` resuelve el tiempo en este orden: `timestamp`(Timestamp) →
`time` → `timestampMs` → prefijo numérico del id → `postTime`.

## Mensajes nuevos en vivo (`_pollNewMessages`)

Timer cada 4 s que lee el marcador `bt_hive_last_notification` desde
SharedPreferences (escrito por `btHiveMain` en [main.dart](../../../lib/main.dart)
al recibir una notificación nueva por BT). Si el marcador cambió respecto al
último visto (`_lastSeenNewMessageId`), llama `_loadConversationMessages()` para
mostrar el nuevo mensaje sin cerrar la pantalla.

## Responder (`_openSttReply`) — el modal de responder con TextField se ELIMINÓ

El botón "Responder" ya **no** abre un diálogo de texto: llama directo a
`showSttReplyModal(context, accentColor, backgroundColor, onResult)`
(exportada desde `stt_mic_button.dart`), que pide permiso de micrófono,
inicializa el STT y abre el modal de grabación de voz a pantalla completa. El
`onResult` del modal llama `_sendConversationReply(text)`. No reintroduzcas el
viejo diálogo con `TextField` + ícono de mic + botón enviar — toda esa UI ahora
vive dentro del modal STT (ver detalle abajo).

`backgroundColor`/`accentColor` se pasan desde los mismos campos de estilo que
antes usaba el diálogo viejo: `Color(_convReplyModalBgColor)` /
`Color(_convReplyModalTextColor)`. Esos campos siguen cargándose en
`_loadStyle()` (configurables) aunque ya no los use un diálogo de texto propio.

## Modal STT (`showSttReplyModal` / `_SttRecordingModal` en `stt_mic_button.dart`)

- **No inicia grabación automáticamente al abrir.** El usuario debe presionar
  el botón Iniciar/Detener.
- Botón único **Iniciar/Detener** con doble función según `_isListening`.
- **La grabación NO se detiene por silencio**: `SttService` usa `pauseFor` y
  `listenFor` de 10 minutos. Solo se detiene cuando el usuario presiona Detener
  o Enviar. No bajes estos valores o volverá el auto-stop por silencio.
- **El texto se acumula entre pulsaciones de Iniciar**: al iniciar se captura
  `_baseText = _textController.text`; el `onResult` concatena
  `'$_baseText $text'`. Solo el botón Reiniciar limpia el texto (llama
  `_textController.clear()` antes de `_startListening`, con lo que `_baseText`
  queda vacío naturalmente).
- Orden de los 3 botones inferiores: **Iniciar/Detener (izquierda) — Reiniciar
  (CENTRO) — Enviar (derecha)**. No vuelvas a poner Reiniciar a la izquierda.
- El modal usa **toda la altura disponible de la pantalla**
  (`media.size.height - media.padding.top`), no una altura fija/expandible.
- Tiene un botón **X arriba a la derecha** que cancela el STT y cierra el modal
  sin enviar nada (`_close`).
- Tiene un ícono de **sonido arriba a la izquierda** (`volume_up`/`volume_off`)
  que silencia/restaura los beeps de inicio-fin de grabación del motor STT del
  sistema. Activado por defecto; el estado se persiste con
  `PreferencesService.getSttSoundEnabled()/saveSttSoundEnabled()` (clave
  `stt_sound_enabled`) para que el usuario no tenga que desactivarlo cada vez.
  El silenciado real es nativo: `BleService.sttSetMuted(bool)` →
  `AudioManager.adjustStreamVolume(STREAM_MUSIC/STREAM_NOTIFICATION,
  ADJUST_MUTE/ADJUST_UNMUTE, 0)` en `MainActivity.kt` y
  `AutoOpenConversationActivity.kt` (no hay forma de silenciar el beep del
  `SpeechRecognizer` del sistema directamente desde el plugin `speech_to_text`).
  Se muta justo antes de `listen()` y se restaura en
  `onDone`/`onError`/`_restart`/`_send`/`_close`/`dispose` — sigue el flag
  `_mutedByUs` para nunca dejar el stream muteado si el modal se cierra a
  mitad de una grabación.
- `showSttReplyModal(context, {onResult, accentColor, backgroundColor})` es la
  función reutilizable: tanto `SttMicButton` (el ícono redondo) como cualquier
  botón "Responder" la llaman. Si necesitas abrir el modal STT desde otra
  pantalla sin mostrar el ícono de mic, llama esta función directamente.

### Por qué es **solo online** (`onDevice: false` siempre)

`SttService.listen()` ya no soporta `preferOffline`/fallback. Antes, si el
modo offline (`onDevice: true`) fallaba (muy común: el modelo de idioma no
está instalado), el código reintentaba online automáticamente — pero cada
llamada nativa a `listen()` reproduce el sonido de "inicio de escucha" del
sistema, así que el síntoma reportado era **"suena dos veces al inicio y no
graba nada"**: el primer intento (offline) sonaba y fallaba sin grabar, y el
segundo (online) competía con el `cancel()` del primero. La solución fue
eliminar el modo offline por completo, no parchear el fallback. Si vuelves a
agregar offline, asume que vas a reintroducir este bug.

## Envío (`_sendConversationReply`)

1. Mensaje **óptimista** agregado a la lista y reordenado con `_sortKeyMs`.
2. Entrega por capas: `getBtServerStatus()` → si hay peers
   `sendBtServerMessage` → si no, `sendNotification` → si no,
   `_enqueueReplyInFirestoreFallback` (queued).
3. Persistencia: `NotificationCacheService.recordSentReply` +
   `BtHiveStorageService.storeConversationReply`.
4. Recarga con `_loadConversationMessages()`.

## Indicador "¿notificación aún en la barra del emisor?" + botones animados

Punto pequeño en el header (derecha, centrado vertical): **verde**=sigue en la
barra del emisor, **rojo**=ya no, **gris**=desconocido. Toque → modal con la
leyenda (`_showNotifActiveInfo`). Está en AMBAS pantallas de conversación: aquí
en `_buildHeader`, y en la pantalla de la app
([notification_detail_screen.dart](../../../lib/screens/receptor/notification_detail_screen.dart))
dentro de `actions` del AppBar de conversación.

**Efecto en los botones inferiores** (`_buildBottomBar`):
- Cuando `_notifStillActive == false` (rojo): el botón Responder se **oculta
  con animación** (300 ms, `Curves.easeInOut`) y el botón Cerrar se expande
  hasta el ancho total.
- Cuando `_notifStillActive` vuelve a `true` o `null` (verde/gris): la
  animación se **invierte** — Responder reaparece y Cerrar se achica de nuevo.
- Implementación: `LayoutBuilder` para conocer el ancho total, luego dos
  `AnimatedContainer` (uno para Cerrar, otro que envuelve gap + Responder).
  No uses `Expanded` directamente en los botones dentro de este bloque animado:
  el ancho se gestiona con `AnimatedContainer`.

Mecánica (`_pollNotifActive`, Timer cada 4s):
1. Envía por BT `{type:'query_notif_active', sbnKey, requestId}` con el sbnKey
   a sondear: **prioriza `_notifActiveSbnKey`** (campo dedicado, fijado al
   entrar en modo conversación y actualizado cada vez que llega un mensaje
   ENTRANTE nuevo en `_loadConversationMessages`); solo si está vacío cae a
   `_pickBestSbnKeyForReply()` (que puede tomar el sbnKey de una respuesta
   saliente vieja — sirve para enviar replies, pero no es fiable para este
   indicador, por eso el campo dedicado).
2. **Optimismo al abrir**: en `_initModeAndMaybeLoad`, si se entra en modo
   conversación, `_notifStillActive` se fija en `true` de inmediato (verde)
   usando el sbnKey de `widget.notificationData` — la notificación que abrió
   la pantalla, por definición, estaba activa. No esperes el primer poll para
   pintar el indicador.
3. El emisor responde `notif_active_state` (consulta
   `NotificationListener.isNotificationActive(sbnKey)`); el nativo guarda la
   respuesta en SharedPreferences `bt_notif_active_last`.
4. La UI lee `prefs.reload()` + `getString('bt_notif_active_last')`, compara el
   `sbnKey` y pinta el color. Detalle del protocolo en [[bt-debug-logging]].
5. La consulta se envía en capas (servidor BT → si no, cliente BT) porque
   `sendBtServerMessage` por sí solo solo funciona si este dispositivo es en
   ese momento el servidor de la conexión — ver [[bt-debug-logging]] para la
   arquitectura real (receptor=servidor BT, emisor=cliente BT).

Nota relacionada: el **auto-vínculo BT→Firebase** (`firebase_link`) hace que, al
emparejar por BT, el receptor se vincule al `device_id` actual del emisor. Sin un
`linkedDeviceId` válido, `fetchAllNotificationsAcrossDaysRawOnce` devuelve `[]`
y se activa el fallback Hive. Ver [[bt-debug-logging]].

## `AutoOpenConversationActivity` — canal BLE obligatorio

Esta Activity crea su propio `FlutterEngine` (no comparte el de `MainActivity`).
El canal `com.example.connect/ble` **debe estar registrado** en su
`configureFlutterEngine` con los 5 métodos que usa esta pantalla:
`getBtServerStatus`, `sendBtServerMessage`, `sendNotification`,
`sendDebugLogToPeers`, `sttSetMuted`. Sin este registro, todas las llamadas de
`BleService` desde Dart fallan en silencio (capturadas por try/catch) sin dar
ningún error visible, rompiendo: logs BT, indicador notif-activa y mute STT.

## Depuración

Usa `_btDebug(message, {required sig, required throttleMs})` (source
`floating_ball_conversation`). Imprime local con `print('[floating_ball_conversation] …')`
y reenvía por BT. Logs clave ya puestos: `initMode`, `loadStart`, `loadDone`
(con `zeroTs`/`selectedPresent`), `loadFallbackHive`, `inject`, `sendOptimistic`,
`sendResult`, `screenOpen`, `screenClose`.
Detalle del mecanismo en la skill [[bt-debug-logging]].

## Sistema de ESTILOS — no hardcodear

Toda la apariencia es configurable y se carga en `_loadStyle()` desde
`FloatingBallService.getFullScreen*` (prefs persistidas, editadas en las
pantallas de estilo/ajustes de la bola). **Regla: lee siempre de estos campos;
no pongas colores/medidas literales.** Colores = enteros ARGB usados con
`Color(int)`; medidas = enteros `Dp`/`Sp`.

Grupos de campos (todos en el `State`):

- **Barra superior (`_fsBar*`)**: `_fsBarEnabled`, `_fsBarHeightDp`,
  `_fsBarBgColor`, `_fsBarIconSizeDp`, `_fsBarTextSizeSp`, paddings, y colores
  por ícono (time/wifi/bt/data/loc/battery/restore) + sus PNG base64 opcionales.
- **Modo notificaciones (`_notifs*`)**: `_notifsBgColor`, `_notifsItemBgColor`,
  `_notifsItemBorderColor`, `_notifsTitleColor`, `_notifsTextColor`,
  `_notifsTitleSizeSp`, `_notifsTextSizeSp`.
- **Modo conversación (`_conv*`)**: `_convBgColor` (también fondo del modal STT),
  `_convIncomingColor`, `_convOutgoingColor`, `_convTextColor`, `_convTextSizeSp`,
  `_convTitleColor`, `_convTitleSizeSp`, `_convHeaderAppIconSizeDp`.
- **Botones inferiores cerrar/responder**: `_convClose*` y `_convReply*`
  (alto, bg, texto, borde, ocultar texto, etiqueta, ícono PNG, tamaño ícono) +
  `_convBottomButtonsGapDp`, `_convBottomButtonsPaddingHorz/VertDp`.
- **Modal de responder**: `_convReplyModalBgColor`, `_convReplyModalTextColor`,
  `_convReplyModalTextSizeSp`, `_convReplyModalSendBgColor`,
  `_convReplyModalSendBorderColor`, `_convReplyModalSendIconPngBase64`,
  `_convReplyModalSendIconSizeDp`.

Helper `_pngOrIcon(base64Png, fallback, tint, size)`: si hay PNG base64 lo usa,
si no cae al `IconData`. Respeta ese patrón al añadir íconos configurables.

## Checklist al modificar esta pantalla

- [ ] No romper la inyección del disparador (`_selectedMessageId`).
- [ ] Mantener el orden con fallback determinista (`_sortKeyMs`), nunca timestamp 0.
- [ ] Conservar el filtro de respaldo por título normalizado.
- [ ] Conservar el fallback Hive en `_loadConversationMessages` (cuando `remote` vacío).
- [ ] No reintroduzcas un diálogo de texto para responder: "Responder" abre
      `showSttReplyModal` directo.
- [ ] Modal STT: no auto-iniciar grabación, botón Iniciar/Detener, orden
      Iniciar/Detener–Reiniciar(centro)–Enviar, altura completa, botón X.
- [ ] STT: `SttService.listen()` solo online (`onDevice: false`), `pauseFor` y
      `listenFor` de 10 minutos (no los bajes o vuelve el auto-stop por silencio).
- [ ] STT texto acumulativo: `_baseText` captura el texto existente al iniciar;
      solo Reiniciar borra (`_textController.clear()` antes de `_startListening`).
- [ ] Leer estilos de `_loadStyle()` / `FloatingBallService`, sin literales.
- [ ] Mantener los `_btDebug` de diagnóstico mientras se depura.
- [ ] Indicador notif-activa: el Timer de `_pollNotifActive` se cancela en
      `dispose()` (igual en la pantalla de la app); usa `_notifActiveSbnKey`
      (no recalcules desde `_pickBestSbnKeyForReply` para este indicador).
- [ ] Botones inferiores animados: usa `LayoutBuilder` + `AnimatedContainer`;
      no vuelvas a `Expanded` directamente dentro del bloque animado.
- [ ] `AutoOpenConversationActivity` debe registrar el canal BLE con los 5 métodos.
- [ ] Cualquier dato que venga de los servicios BT (isleta de fondo) hacia la UI
      debe pasar por SharedPreferences nativas, no por Hive (ver [[bt-debug-logging]]).
