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

1. `_receptorService.fetchAllNotificationsAcrossDaysRawOnce()` + respuestas
   locales `BtHiveStorageService.getConversationRepliesForUi(...)`.
2. Filtro por `packageName == _packageName && title == _conversationTitle`;
   si quedan ≤1, **filtro de respaldo** por título normalizado
   (`_normalizeConversationKey`, contains en ambos sentidos). No lo elimines:
   evita conversaciones vacías por títulos ligeramente distintos.
3. Dedupe en `byId` (mapa por `_messageId`), respuestas locales pisan remotas.
4. **Inyección del disparador** (CRÍTICO): si `_selectedMessageId` no está en
   `byId`, se sintetiza desde `widget.notificationData`. Sin esto, la
   notificación que abre la pantalla a veces no se ve. La pantalla de la app
   hace lo mismo; mantenlas simétricas.
5. **Orden seguro** (CRÍTICO): se ordena con `_sortKeyMs(m, loadNowMs)`, que
   cae a `loadNowMs` (capturado UNA vez por carga) cuando el timestamp es 0.
   - Nunca ordenes con timestamp 0/epoch directo: manda mensajes a 1970 (orden
     incorrecto).
   - El fallback debe ser **determinista** (un `now` capturado antes de ordenar),
     NO `DateTime.now()` dentro del comparador (rompe el contrato del sort).
6. Ventana = últimos 20 (`_windowStart`/`_windowEnd`); luego `_scrollToBottom()`
   y `_scheduleVisibilityCheck()`.

`_messageTimestampMs` resuelve el tiempo en este orden: `timestamp`(Timestamp) →
`time` → `timestampMs` → prefijo numérico del id → `postTime`.

## Modal de responder (`_openReplyDialog`)

- `showModalBottomSheet(isScrollControlled, useSafeArea, backgroundColor: transparent)`,
  el sheet ocupa toda la altura y el panel va arriba/centrado.
- **Cerrar al tocar fuera**: el fondo está envuelto en
  `GestureDetector(behavior: opaque, onTap: pop)` y el panel en otro
  `GestureDetector(onTap: {})` que **absorbe** el toque. No quites el absorbente
  o el modal se cerraría al tocar el panel. (El dismiss por scrim no basta
  porque el sheet tapa la barrera.)
- Devuelve el texto vía `Navigator.pop(text)` → `_sendConversationReply(text)`.
- **STT (micrófono)**: `SttMicButton` con
  `modalBackgroundColor: Color(_convBgColor)` (el modal de voz usa el color de
  fondo de la conversación) y `onResult` que hace `Navigator.pop(trimmed)`:
  enviar y cerrar el modal de responder en un toque. Ver la skill
  [[stt-mic-button]] si tocas el modal de voz.

## Envío (`_sendConversationReply`)

1. Mensaje **óptimista** agregado a la lista y reordenado con `_sortKeyMs`.
2. Entrega por capas: `getBtServerStatus()` → si hay peers
   `sendBtServerMessage` → si no, `sendNotification` → si no,
   `_enqueueReplyInFirestoreFallback` (queued).
3. Persistencia: `NotificationCacheService.recordSentReply` +
   `BtHiveStorageService.storeConversationReply`.
4. Recarga con `_loadConversationMessages()`.

## Indicador "¿notificación aún en la barra del emisor?"

Punto pequeño en el header (derecha, centrado vertical): **verde**=sigue en la
barra del emisor, **rojo**=ya no, **gris**=desconocido. Toque → modal con la
leyenda (`_showNotifActiveInfo`). Está en AMBAS pantallas de conversación: aquí
en `_buildHeader`, y en la pantalla de la app
([notification_detail_screen.dart](../../../lib/screens/receptor/notification_detail_screen.dart))
dentro de `actions` del AppBar de conversación.

Mecánica (`_pollNotifActive`, Timer cada 4s):
1. Envía por BT `{type:'query_notif_active', sbnKey, requestId}` con el sbnKey de
   la conversación (`_pickBestSbnKeyForReply`).
2. El emisor responde `notif_active_state` (consulta
   `NotificationListener.isNotificationActive(sbnKey)`); el nativo guarda la
   respuesta en SharedPreferences `bt_notif_active_last`.
3. La UI lee `prefs.reload()` + `getString('bt_notif_active_last')`, compara el
   `sbnKey` y pinta el color. Detalle del protocolo en [[bt-debug-logging]].

Nota relacionada: el **auto-vínculo BT→Firebase** (`firebase_link`) hace que, al
emparejar por BT, el receptor se vincule al `device_id` actual del emisor. Sin un
`linkedDeviceId` válido, `fetchAllNotificationsAcrossDaysRawOnce` devuelve `[]` y
la conversación queda vacía / no auto-abre. Ver [[bt-debug-logging]].

## Depuración

Usa `_btDebug(message, {required sig, required throttleMs})` (source
`floating_ball_conversation`). Imprime local con `print('[floating_ball_conversation] …')`
y reenvía por BT. Logs clave ya puestos: `initMode`, `loadStart`, `loadDone`
(con `zeroTs`/`selectedPresent`), `inject`, `sendOptimistic`, `sendResult`.
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
- [ ] Modal de responder: cerrar al tocar fuera + absorber toque en el panel.
- [ ] STT: `modalBackgroundColor = Color(_convBgColor)` y enviar+cerrar en `onResult`.
- [ ] Leer estilos de `_loadStyle()` / `FloatingBallService`, sin literales.
- [ ] Mantener los `_btDebug` de diagnóstico mientras se depura.
- [ ] Indicador notif-activa: el Timer de `_pollNotifActive` se cancela en
      `dispose()` (igual en la pantalla de la app).
- [ ] Cualquier dato que venga de los servicios BT (isleta de fondo) hacia la UI
      debe pasar por SharedPreferences nativas, no por Hive (ver [[bt-debug-logging]]).
