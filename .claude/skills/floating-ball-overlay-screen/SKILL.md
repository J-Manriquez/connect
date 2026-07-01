---
name: floating-ball-overlay-screen
description: Cómo crear una pantalla Flutter NUEVA que la bola flotante abre por encima de otras apps (su propia Activity transparente). Cubre el patrón OBLIGATORIO de cierre (finalizar la Activity, no hacer pop de ruta) y el cableado nativo (Activity + canales + manifest + botón del menú). Léela ANTES de crear cualquier pantalla overlay de la bola (lib/screens/emisor/floating_ball_*), o si una de esas pantallas, al cerrarse, navega al home del emisor en vez de volver a la app previa.
---

# Pantallas overlay de la bola flotante

Una "pantalla overlay de la bola" es una pantalla Flutter que se abre **desde el
menú de la bola flotante, por encima de otra aplicación** (el usuario está en
WhatsApp, toca la bola, abre la pantalla). NO es una pantalla normal de la app.

Ejemplos actuales:
- [floating_ball_conversation_screen.dart](../../../lib/screens/emisor/floating_ball_conversation_screen.dart)
  (vía `AutoOpenConversationActivity`, ruta `/floating_ball_conversation_auto`).
- [floating_ball_chats_menu_screen.dart](../../../lib/screens/emisor/floating_ball_chats_menu_screen.dart)
  (vía `FloatingBallChatsActivity`, ruta `/floating_ball_chats`).

Cada una corre en una **Activity propia con su propio `FlutterEngine`** (NO
comparte el de `MainActivity`), lanzada con `getInitialRoute()` = su ruta.

## Regla CRÍTICA: cerrar = finalizar la Activity, NO hacer pop de ruta

### El problema

El `MaterialApp` se construye con
`initialRoute: ...defaultRouteName` (= la ruta de la pantalla overlay, p. ej.
`/floating_ball_chats`). Flutter, por defecto
(`Navigator.defaultGenerateInitialRoutes`), trata una ruta con `/` como
**deep link** y genera un STACK con las rutas intermedias. Para
`/floating_ball_chats` el stack queda:

```
['/', '/floating_ball_chats']
```

es decir **`EmisorScreen` ('/') queda DEBAJO** de la pantalla overlay.

Por eso, si al cerrar haces `Navigator.pop()` (o `canPop()` → `pop()`), NO
cierras el overlay: revelas `EmisorScreen` debajo y la app "navega al home del
emisor" abriéndose por encima de la app en la que estaba el usuario. **Bug.**

### La solución (aplícala SIEMPRE)

Cerrar una pantalla overlay debe **finalizar la Activity** con
`SystemNavigator.pop()` (de `package:flutter/services.dart`), que devuelve al
usuario a la app previa. Hazlo en los DOS caminos de cierre:

1. **Botón "Cerrar"/X** → llama a un `_close()` que hace `SystemNavigator.pop()`.
   Nunca `Navigator.pop()` ni `canPop()`.

2. **Gesto/botón "atrás"** del sistema → envuelve el `Scaffold` en un `PopScope`
   con `canPop: false` y finaliza la Activity en el callback (API de Flutter
   3.41: `onPopInvokedWithResult`):

```dart
return PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, result) {
    if (didPop) return;
    _close(); // SystemNavigator.pop()
  },
  child: scaffold,
);
```

Patrones de referencia ya en el repo:
- Botón cerrar que finaliza la Activity: `floating_ball_conversation_screen.dart`
  (`if (widget.openedFromBackground) SystemNavigator.pop();`).
- `PopScope(canPop:false)` + handler propio:
  [notification_detail_screen.dart](../../../lib/screens/receptor/notification_detail_screen.dart)
  (`_goBackToConexion`).
- Ejemplo completo (X + PopScope + `SystemNavigator.pop`):
  `floating_ball_chats_menu_screen.dart`.

### Navegación ANIDADA dentro del overlay

Si la pantalla overlay empuja otra pantalla (p. ej. el menú de chats abre la
conversación con `Navigator.push`), esa ruta SÍ se puede cerrar con un pop
normal (vuelve a la pantalla overlay de abajo, que es lo correcto). El
`PopScope(canPop:false)` de la pantalla overlay solo intercepta cuando ELLA es
la ruta superior, así que no estorba a las rutas anidadas.

Al empujar la **pantalla de conversación** desde un overlay, pásala con
`openedFromBackground: true`: así tiene **fondo sólido** (con `false` el fondo es
`Colors.transparent` y, sobre una Activity transparente, se ve la app de atrás)
y su botón "Cerrar" finaliza la Activity (vuelve a la app previa); el gesto
"atrás" hace pop normal y regresa a la pantalla overlay anterior.

## Cableado nativo de una pantalla overlay nueva

Para que el menú de la bola abra una pantalla overlay nueva hacen falta 4 piezas:

1. **Ruta Flutter** en [main.dart](../../../lib/main.dart) (`routes:`), p. ej.
   `'/floating_ball_chats': (context) => const FloatingBallChatsMenuScreen()`.

2. **Activity propia** (Kotlin), modelada sobre
   [AutoOpenConversationActivity.kt](../../../android/app/src/main/kotlin/com/example/connect/AutoOpenConversationActivity.kt)
   y [FloatingBallChatsActivity.kt](../../../android/app/src/main/kotlin/com/example/connect/FloatingBallChatsActivity.kt):
   - `getBackgroundMode()` = `transparent`, `getRenderMode()` = `texture`.
   - `getInitialRoute()` = la ruta de la pantalla.
   - `configureFlutterEngine`: registra los canales que la pantalla (y cualquier
     pantalla que ANIDE) usa. Como mínimo `com.example.connect/ble` con los 5
     métodos (`getBtServerStatus`, `sendBtServerMessage`, `sendNotification`,
     `sendDebugLogToPeers`, `sttSetMuted`); además `com.example.connect/app_list`
     (`getInstalledApps`) y `com.example.connect/floating_ball`
     (`getFsBarSystemState`) si se usan. **Sin registrar el canal BLE,
     `BleService` falla en silencio** (logs BT, indicador de notif-activa y mute
     STT rotos) — ver [[bt-debug-logging]] y [[floating-ball-conversation-screen]].
   - En `onCreate`, fija `flutter.skip_auto_redirect_once = true` en
     `FlutterSharedPreferences` (evita el auto-redirect a `/receptor`).

3. **Registro en el manifest**
   ([AndroidManifest.xml](../../../android/app/src/main/AndroidManifest.xml)):
   copia el bloque de `AutoOpenConversationActivity` (`launchMode="singleTask"`,
   `taskAffinity` propio, `theme="@style/AutoOpenTheme"`, `exported="false"`,
   `excludeFromRecents="true"`, `showWhenLocked`/`turnScreenOn`).

4. **Lanzamiento desde el menú** en
   [FloatingBallService.kt](../../../android/app/src/main/kotlin/com/example/connect/FloatingBallService.kt):
   una función `startActivity(Intent(this, MiActivity::class.java).apply { addFlags(FLAG_ACTIVITY_NEW_TASK or FLAG_ACTIVITY_SINGLE_TOP) })`
   conectada al botón correspondiente en el menú pantalla completa (`byId[...]`)
   y/o popup (`popupItems[...]`). Si el botón es opcional, agrégalo también a los
   reorder screens ([floating_ball_reorder_screen.dart](../../../lib/screens/emisor/floating_ball_reorder_screen.dart),
   [floating_ball_popup_reorder_screen.dart](../../../lib/screens/emisor/floating_ball_popup_reorder_screen.dart)).

## Estilos: leer de FloatingBallService, no hardcodear

Igual que las demás pantallas de la bola, toda la apariencia se persiste en
SharedPreferences vía `FloatingBallService.getX/setX` y se edita en
[floating_ball_style_screen.dart](../../../lib/screens/emisor/floating_ball_style_screen.dart).
No pongas colores/medidas literales; cárgalos en un `_load()`/`_loadStyle()`.
Detalle del sistema de estilos en [[floating-ball-conversation-screen]].

## Checklist al crear una pantalla overlay de la bola

- [ ] Cerrar (X) → `SystemNavigator.pop()`, NUNCA `Navigator.pop()`/`canPop()`.
- [ ] `PopScope(canPop:false)` + `onPopInvokedWithResult` → finaliza la Activity.
- [ ] Si anida la conversación, pásala con `openedFromBackground: true`.
- [ ] Activity propia (transparent/texture) con `getInitialRoute` correcto.
- [ ] Registrar canales BLE/app_list/floating_ball en `configureFlutterEngine`.
- [ ] `skip_auto_redirect_once=true` en `onCreate`.
- [ ] Activity en el AndroidManifest (singleTask, taskAffinity propio).
- [ ] Lanzamiento desde el menú nativo + (si aplica) reorder screens.
- [ ] Ruta en main.dart.
- [ ] Estilos desde `FloatingBallService`, sin literales.
