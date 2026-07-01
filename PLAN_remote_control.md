# PLAN — Control Remoto (touchpad + teclado) y APK receptor "connect remote control"

> Documento de planificación. **No** contiene aún cambios de código; describe
> TODO lo necesario para implementar la funcionalidad más adelante sin romper
> nada de lo existente.

---

## 0. Objetivo y decisiones tomadas

**Qué se quiere:**

1. Dentro de la app `connect`, desde **Herramientas**, navegar a una nueva
   pantalla de **Control Remoto** que muestre:
   - Un **touchpad** (área de gestos) que mueve un cursor y hace click/scroll
     en el dispositivo receptor.
   - En el **AppBar**, un **dropdown** con los dispositivos Bluetooth detectados
     para seleccionar el receptor.
   - Un **icono de teclado** que abre un campo de texto para escribir y enviar
     teclas/texto al receptor.
2. Un **APK nuevo e independiente** que actúe **solo como receptor**: corre en
   segundo plano, al abrirlo pide los permisos necesarios y permite la conexión
   desde `connect`.
3. El APK receptor vive **dentro de este repositorio** pero se **excluye de la
   compilación del proyecto principal `connect`**. Se llama
   **"connect remote control"**.
4. **No romper** ninguna funcionalidad actual de `connect`.

**Decisiones de diseño (confirmadas / recomendadas):**

| Tema | Decisión | Motivo |
|------|----------|--------|
| Stack del receptor | **App Android nativa en Kotlin** (sin Flutter), subproyecto Gradle aparte | APK mínimo (sin motor Flutter → relevante por el problema de tamaño en el smartwatch), arranque rápido y **máxima compatibilidad: teléfonos viejos, tablets y Android TV** |
| Transporte | **Bluetooth Classic RFCOMM (SPP)** con framing JSON length-prefixed, **UUID dedicado nuevo** | Reutiliza el patrón ya probado en `BtClassicClient`/`BtClassicServerService`; UUID propio evita interferir con el puente de notificaciones/media existente |
| Modelo de cursor | **Cursor overlay + gestos de AccessibilityService** (deltas relativos) | Único enfoque viable sin root para simular mouse; ya hay infraestructura de overlay y accesibilidad en el repo |
| Modos de control | **Dos modos alternables con botón**: (1) **Cursor** (overlay + gestos) y (2) **D-pad** (deslizar=flechas, tap=OK) | El usuario alterna manualmente en cualquier dispositivo; D-pad es lo único que controla de verdad las apps de Android TV (que navegan por foco, no por toque) |
| Inyección de teclado | `AccessibilityNodeInfo.ACTION_SET_TEXT` / `ACTION_PASTE` sobre el nodo enfocado | Forma estándar sin root de escribir en campos de texto |
| Compatibilidad TV | Manifest leanback + `touchscreen` no requerido; **modo D-pad** para apps de TV + cursor para apps táctiles | Cumple "todos los Android incluyendo TV" controlando de verdad las apps de TV |

> **Importante (aislamiento):** el receptor usa un **UUID RFCOMM nuevo y propio**
> y, en el lado emisor, un **canal y cliente Kotlin nuevos** (`RemoteControlClient`),
> separados de `BtClassicClient` (notificaciones/media). Así el control remoto no
> toca el flujo Bluetooth actual.

---

## 1. Arquitectura general

```
┌─────────────────────────── connect (EMISOR) ───────────────────────────┐
│  HerramientasScreen ─▶ RemoteControlScreen (Flutter)                     │
│     · Touchpad (GestureDetector: pan/tap/double-tap/2-dedos scroll)     │
│     · AppBar dropdown de dispositivos (bonded + discovery)              │
│     · Botón teclado ▶ TextField que envía texto/teclas                  │
│                         │ MethodChannel                                 │
│                         ▼  com.example.connect/remote_control           │
│  MainActivity handler ─▶ RemoteControlClient.kt (RFCOMM client)         │
│                         │ socket RFCOMM (UUID dedicado, JSON len-prefix)│
└─────────────────────────┼───────────────────────────────────────────────┘
                          │  Bluetooth
┌─────────────────────────▼──── connect remote control (RECEPTOR) ────────┐
│  RemoteServerService (RFCOMM server, foreground)                        │
│     · Acepta socket, lee JSON {type:"remote_input"|"text"|"key"|...}    │
│     · Despacha a RemoteInputController                                   │
│  RemoteInputController                                                   │
│     · mueve CursorOverlayView (WindowManager overlay)                    │
│     · click/scroll ▶ RemoteAccessibilityService.dispatchGesture()       │
│     · texto/teclas ▶ RemoteAccessibilityService (ACTION_SET_TEXT/PASTE) │
│  OnboardingActivity (permisos) · MainActivity (estado/conexión)         │
└──────────────────────────────────────────────────────────────────────────┘
```

**Roles RFCOMM:** el **receptor** es el **servidor** (`listenUsingRfcommWithServiceRecord`)
y el **emisor** (`connect`) es el **cliente** (`createRfcommSocketToServiceRecord`),
igual que el patrón actual pero con **UUID propio**.

---

## 2. Protocolo de mensajes (JSON, framing length-prefixed)

Mismo framing que el actual: `DataOutputStream.writeInt(len)` + bytes UTF-8;
lectura con `readInt()` + `readFully`. Límite de tamaño defensivo (256 KB).

Mensajes **emisor → receptor**:

```jsonc
// Movimiento relativo del cursor (touchpad pan)
{ "type": "remote_input", "action": "move", "dx": 12.5, "dy": -4.0, "t": 1719... }

// Click (tap) en la posición actual del cursor
{ "type": "remote_input", "action": "tap" }
{ "type": "remote_input", "action": "tap", "button": "right" }    // long-press/menú
{ "type": "remote_input", "action": "double_tap" }
{ "type": "remote_input", "action": "down" }                       // arrastrar: inicio
{ "type": "remote_input", "action": "up" }                         // arrastrar: fin

// Scroll (2 dedos)
{ "type": "remote_input", "action": "scroll", "dx": 0, "dy": 120 }

// --- MODO D-PAD (para Android TV / navegación por foco) ---
// El emisor traduce gestos del touchpad a teclas direccionales y las envía:
{ "type": "key", "key": "dpad_left" }    // dpad_up|dpad_down|dpad_left|dpad_right|dpad_center
{ "type": "key", "key": "dpad_center" }  // = OK/seleccionar (tap)

// Cambio de modo de control (lo dispara el botón del AppBar)
{ "type": "config", "mode": "cursor" }   // mode: "cursor" | "dpad"

// Teclado: texto a insertar en el campo enfocado
{ "type": "text", "value": "hola mundo" }

// Teclado: tecla especial
{ "type": "key", "key": "backspace" }     // backspace|enter|space|tab|dpad_up|dpad_down|dpad_left|dpad_right|dpad_center|home|back
{ "type": "key", "key": "enter" }

// Sensibilidad / config en caliente (opcional)
{ "type": "config", "sensitivity": 1.6, "naturalScroll": true }

// Keepalive
{ "type": "ping", "t": 1719... }
```

Mensajes **receptor → emisor** (opcional, para feedback de UI):

```jsonc
{ "type": "hello", "name": "Connect Remote (TV salón)", "version": 1 }
{ "type": "ack", "ok": true }
{ "type": "status", "accessibility": true, "overlay": true }   // permisos listos
{ "type": "pong", "t": 1719... }
```

**Compatibilidad:** mensajes desconocidos → ignorar (`else -> return`), igual que
el handler actual, para poder ampliar el protocolo sin romper versiones.

---

## 3. PARTE A — Cambios en `connect` (EMISOR)

> Todos los cambios son **aditivos**. No se modifica `BtClassicClient`,
> `BtClassicServerService` ni el flujo de notificaciones/media.

### A.1 Navegación desde Herramientas
- Archivo: `lib/screens/emisor/herramientas_screen.dart`
- Añadir un `_tool(...)` nuevo (icono `Icons.mouse` o `Icons.touch_app`,
  título "Control remoto", subtítulo descriptivo) que navega a
  `RemoteControlScreen`. **Solo se agrega un item a la `ListView`**; no se toca
  el resto.

### A.2 Pantalla nueva
- Archivo nuevo: `lib/screens/emisor/remote_control_screen.dart`
- `StatefulWidget` con:
  - **AppBar**:
    - `title`: "Control remoto".
    - `actions`: `DropdownButton`/`PopupMenuButton` con la lista de dispositivos
      (bonded + descubiertos) y estado de conexión (conectado/â€¦). Botón de
      refrescar (re-discovery).
    - **Botón de modo** (`IconButton`) que alterna entre **modo Cursor**
      (`Icons.mouse`) y **modo D-pad** (`Icons.gamepad`/`Icons.control_camera`).
      Al pulsarlo: cambia el estado local del touchpad y envía
      `{type:"config", mode:"cursor"|"dpad"}` al receptor.
    - Icono de **teclado** (`IconButton(Icons.keyboard)`) que togglea un panel
      inferior con un `TextField`.
  - **Cuerpo**:
    - Área de **touchpad** (el comportamiento depende del **modo activo**):
      - **Modo Cursor**:
        - `onPanUpdate` → acumula `delta` y envía `move` (throttling ~60 Hz,
          coalescer y enviar cada ~16 ms).
        - `onTap` → `tap`; `onDoubleTap` → `double_tap`;
          `onLongPress` → `tap button=right`.
        - 2 dedos (ScaleGesture o segundo pointer) → `scroll`.
      - **Modo D-pad**:
        - Swipe direccional → `key dpad_left/right/up/down` (con umbral mínimo de
          desplazamiento y debounce para no repetir).
        - `onTap` → `key dpad_center` (OK).
        - Opcional: botones grandes de flechas en pantalla como alternativa al
          swipe (útil en TV y para precisión).
    - Botones físicos de ayuda: "Click izq.", "Click der.", barra de scroll
      opcional, slider de **sensibilidad**.
    - Panel de teclado (cuando el icono está activo): `TextField` que en
      `onChanged`/`onSubmitted` envía `text`, y botones para teclas especiales
      (backspace, enter, flechas/D-pad para TV).
  - Reusar `theme_colors.dart` (`customColor`) para mantener estética.

### A.3 Servicio Dart
- Archivo nuevo: `lib/services/remote_control_service.dart`
- `MethodChannel('com.example.connect/remote_control')`.
- API:
  - `Future<List<RemoteDevice>> getBondedDevices()` (reutiliza `getBondedDevices`).
  - `Future<void> startDiscovery()` / `stopDiscovery()` + stream de resultados
    (reutiliza `startBtDiscovery`/`onBleScanResult` ya existentes, o un evento
    propio si se prefiere aislar).
  - `Future<bool> connect(String address)` / `Future<void> disconnect()`.
  - `Future<bool> sendMove(double dx, double dy)`, `sendTap({button})`,
    `sendScroll(dx, dy)`, `sendText(String)`, `sendKey(String)`, `sendConfig(...)`.
  - Stream de estado de conexión.
- **Throttling/coalescing de `move`** se hace aquí (acumular dx/dy y enviar a
  ~60 Hz) para no saturar el socket.

### A.4 Canal nativo nuevo en MainActivity
- Archivo: `android/app/src/main/kotlin/com/example/connect/MainActivity.kt`
- Añadir (de forma aditiva, junto a los canales existentes):
  - `private val REMOTE_CONTROL_CHANNEL = "com.example.connect/remote_control"`
  - `private lateinit var remoteControlChannel: MethodChannel`
  - En `configureFlutterEngine`: inicializar el canal y un `setMethodCallHandler`
    que delegue a `RemoteControlClient`:
    - `getBondedDevices` → reusar lógica existente (o llamar al método ya
      presente en `bleChannel`).
    - `startDiscovery`/`stopDiscovery` → reusar `startBtDiscovery`/`stopBtDiscovery`.
    - `connectRemote(address)` → `RemoteControlClient.connect(address)`.
    - `disconnectRemote` → `RemoteControlClient.disconnect()`.
    - `sendRemote(json)` → `RemoteControlClient.send(json)`.
  - `RemoteControlClient.init(applicationContext)` (similar a `BtClassicClient.init`).

### A.5 Cliente RFCOMM nuevo (Kotlin)
- Archivo nuevo: `android/app/src/main/kotlin/com/example/connect/RemoteControlClient.kt`
- **Copia reducida** del patrón de `BtClassicClient` pero:
  - **UUID propio**: `REMOTE_SPP_UUID = UUID.fromString("<NUEVO-UUID-GENERADO>")`
    (generar uno fijo, p. ej. derivado aleatoriamente; NO el `00001101-...`).
  - Solo necesita: `init`, `connect(address)`, `disconnect`, `send(json)` con
    reconexión exponencial (igual que el actual) y un reader thread opcional para
    `ack`/`pong`.
  - **No** integra Flutter engine ni media/notificaciones (es solo transporte).
- **No** modificar `BtClassicClient.kt`.

### A.6 Permisos en el emisor
- Ya existen en el manifest de `connect` todos los permisos BT necesarios
  (`BLUETOOTH`, `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION`).
  **No hay que añadir permisos nuevos** en el emisor.
- La pantalla debe pedir en runtime (Android 12+) `BLUETOOTH_CONNECT`/`SCAN`
  antes de descubrir/conectar; reutilizar `requestBlePermissions` (ya existe).

### A.7 Garantía de no-regresión en el emisor
- Cambios solo aditivos: 1 item en Herramientas + 1 pantalla + 1 servicio Dart
  + 1 canal + 1 clase Kotlin nueva.
- No se altera ningún canal, servicio o UUID existente.

---

## 4. PARTE B — Subproyecto receptor "connect remote control"

### B.1 Estructura y ubicación
- Carpeta nueva en la raíz del repo:
  `connect_remote_control/` (proyecto Android nativo Gradle independiente).
- Estructura mínima:
  ```
  connect_remote_control/
    settings.gradle.kts            // include(":app"), rootProject.name = "connect remote control"
    build.gradle.kts               // plugins AGP + kotlin (versiones alineadas con el repo: AGP 8.9.1, Kotlin 2.1.0)
    gradle.properties
    gradle/wrapper/...             // wrapper propio (o reutilizar el de /android)
    app/
      build.gradle.kts             // applicationId = "com.andodevs.connectremote"
      src/main/AndroidManifest.xml
      src/main/kotlin/com/andodevs/connectremote/
        MainActivity.kt
        OnboardingActivity.kt
        RemoteServerService.kt
        RemoteAccessibilityService.kt
        RemoteInputController.kt
        CursorOverlayView.kt
        PermissionHelper.kt
      src/main/res/
        layout/activity_main.xml, activity_onboarding.xml
        drawable/cursor.xml (icono de cursor)
        values/strings.xml, themes.xml
        xml/remote_accessibility_service.xml
        mipmap-*/ic_launcher
  ```
- `applicationId` **distinto** (`com.andodevs.connectremote`) para poder instalar
  ambas apps a la vez sin conflicto.
- **`label`** de la app: "connect remote control".

### B.2 Componentes

**MainActivity.kt**
- UI simple: estado de conexión, estado de permisos (accesibilidad/overlay/BT),
  botón "Activar receptor" (arranca `RemoteServerService` + hace discoverable),
  botón "Permisos" → `OnboardingActivity`.
- Compatible con TV: navegable por D-pad (focusables), `CATEGORY_LEANBACK_LAUNCHER`.

**OnboardingActivity.kt** (flujo de permisos al entrar)
- Solicita y enlaza a ajustes para:
  1. **Permisos BT runtime** (Android 12+): `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`,
     `BLUETOOTH_ADVERTISE`; Android ≤11: `ACCESS_FINE_LOCATION`.
  2. **Hacerse visible (discoverable)**: `ACTION_REQUEST_DISCOVERABLE`.
  3. **Overlay** (`SYSTEM_ALERT_WINDOW`): `Settings.ACTION_MANAGE_OVERLAY_PERMISSION`.
  4. **Accesibilidad**: abrir `ACTION_ACCESSIBILITY_SETTINGS` para activar
     `RemoteAccessibilityService`.
  5. **Optimización de batería** (opcional): `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
  6. **POST_NOTIFICATIONS** (Android 13+) para la notificación foreground.
- `PermissionHelper.kt` centraliza checks (`canDrawOverlays`, accesibilidad
  habilitada, permisos BT concedidos).

**RemoteServerService.kt** (foreground service)
- Patrón análogo a `BtClassicServerService` pero **sin Flutter** y con
  **UUID propio**:
  - `adapter.listenUsingRfcommWithServiceRecord("ConnectRemote", REMOTE_SPP_UUID)`.
  - Accept loop + reader thread con framing length-prefixed.
  - Parser JSON → `RemoteInputController`.
  - Notificación foreground persistente ("Receptor de control remoto activo").
  - `foregroundServiceType` = `connectedDevice` (o `specialUse` con justificación);
    en TV/SDK altos validar el tipo permitido.
  - Reinicio `START_STICKY`.
- Envía `hello`/`status` al conectar.

**RemoteAccessibilityService.kt**
- `canPerformGestures` (Android 7+ / API 24): usa `dispatchGesture()` para:
  - **tap**: gesture de toque corto en (cursorX, cursorY).
  - **double_tap**: dos taps.
  - **long-press / click derecho**: gesture con duración larga (abre menú
    contextual donde aplique).
  - **scroll**: `StrokeDescription` (swipe) desde el cursor en dirección dy/dx.
  - **drag** (down/up): mantener un stroke con `willContinue`.
- **Teclado**: sobre el `rootInActiveWindow`/nodo enfocado
  (`findFocus(FOCUS_INPUT)`):
  - `text` → `ACTION_SET_TEXT` (append al texto actual) o `ACTION_PASTE` vía
    portapapeles para textos largos.
  - `backspace` → `ACTION_SET_TEXT` recortando el último carácter.
  - `enter` → intentar `ACTION_IME_ENTER` (API 30+) o `performGlobalAction`
    equivalente; fallback a tecla.
  - Teclas D-pad/`home`/`back` → `performGlobalAction` (BACK/HOME) y, para D-pad,
    mover foco (`ACTION_FOCUS`/navegación) — **clave para Android TV**.
- `remote_accessibility_service.xml`:
  ```xml
  <accessibility-service
      android:accessibilityEventTypes="typeAllMask"
      android:accessibilityFeedbackType="feedbackGeneric"
      android:accessibilityFlags="flagDefault|flagRequestFilterKeyEvents"
      android:canRetrieveWindowContent="true"
      android:canPerformGestures="true"
      android:notificationTimeout="50" />
  ```

**CursorOverlayView.kt**
- Vista overlay vía `WindowManager` (`TYPE_APPLICATION_OVERLAY`,
  `FLAG_NOT_FOCUSABLE | FLAG_NOT_TOUCHABLE`) que dibuja un cursor (flecha/círculo).
- Mantiene `cursorX/cursorY`, los actualiza con los deltas `move`
  (× sensibilidad), clamp a los bordes de pantalla
  (`WindowManager.currentWindowMetrics`/`DisplayMetrics`).
- `RemoteInputController` lee esta posición para construir los gestos.

**RemoteInputController.kt**
- Orquesta: recibe el mensaje parseado, actualiza el overlay (move) o pide al
  `RemoteAccessibilityService` el gesto/inyección de texto correspondiente.
- Maneja sensibilidad, scroll natural/invertido, debounce de taps.
- **Estado de modo** (`cursor`/`dpad`) recibido vía `{type:"config", mode}`:
  - En **modo cursor**: muestra el overlay y procesa `move`/`tap`/`scroll`/`drag`.
  - En **modo D-pad**: oculta el cursor overlay y enruta las teclas `dpad_*` al
    `RemoteAccessibilityService` (navegación por foco / `performGlobalAction`).
  - El receptor obedece el modo que indique el emisor; el botón del AppBar es la
    fuente de verdad. (Si el receptor detecta que es TV puede arrancar en `dpad`
    por defecto hasta recibir el primer `config`.)

### B.3 Manifest del receptor (puntos clave)
```xml
<uses-feature android:name="android.hardware.touchscreen" android:required="false"/>
<uses-feature android:name="android.software.leanback" android:required="false"/>
<uses-feature android:name="android.hardware.bluetooth" android:required="true"/>

<uses-permission android:name="android.permission.BLUETOOTH"/>                 <!-- maxSdk 30 -->
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>           <!-- maxSdk 30 -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>      <!-- maxSdk 30, si aplica -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>   <!-- opcional auto-inicio -->

<application android:label="connect remote control" ...>
  <activity android:name=".MainActivity" android:exported="true">
    <intent-filter>
      <action android:name="android.intent.action.MAIN"/>
      <category android:name="android.intent.category.LAUNCHER"/>
      <category android:name="android.intent.category.LEANBACK_LAUNCHER"/> <!-- TV -->
    </intent-filter>
  </activity>
  <activity android:name=".OnboardingActivity" android:exported="false"/>
  <service android:name=".RemoteServerService"
           android:exported="false"
           android:foregroundServiceType="connectedDevice"/>
  <service android:name=".RemoteAccessibilityService"
           android:exported="false"
           android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
    <intent-filter>
      <action android:name="android.accessibilityservice.AccessibilityService"/>
    </intent-filter>
    <meta-data android:name="android.accessibilityservice"
               android:resource="@xml/remote_accessibility_service"/>
  </service>
</application>
```

### B.4 Compatibilidad de versiones
- `minSdk`: **21** (cubre la gran mayoría; `dispatchGesture` requiere API 24 → en
  21–23 degradar a taps absolutos o avisar "no soportado").
  - Recomendado: `minSdk = 24` para garantizar gestos; documentar el corte.
- `targetSdk`: alinear con el de `connect` (`flutter.targetSdkVersion`).
- ABIs: app nativa → `universal` (sin libs pesadas, APK pequeño); opcionalmente
  `--split-per-abi` no es necesario porque casi no hay código nativo.

---

## 5. Inyección de input — detalle técnico (sin root)

- **Mover el cursor**: no existe cursor de sistema manipulable por apps; por eso
  se dibuja un **overlay propio** y los gestos se despachan en esa coordenada.
- **Click/scroll/drag**: `AccessibilityService.dispatchGesture(GestureDescription)`
  con `StrokeDescription`. Tap = toque corto; scroll = swipe; drag = stroke con
  `willContinue=true` y continuación.
- **Texto**: localizar nodo enfocado editable y `ACTION_SET_TEXT`/`ACTION_PASTE`.
  Limitación conocida: si no hay campo enfocado, el texto no se inserta (mostrar
  feedback). Para juegos/campos no estándar, la inyección puede no aplicar.
- **Android TV**: además de gestos, mapear teclas D-pad a navegación de foco y
  `performGlobalAction(BACK/HOME)`; el cursor overlay sigue funcionando para apps
  táctiles dentro de TV.

---

## 6. Aislamiento del build — "no compilar con `connect`"

Como el receptor es un **proyecto Gradle independiente en su propia carpeta**:

- `flutter build apk` / `flutter build apk --split-per-abi` ejecutado en la raíz
  **solo compila `connect`** (Flutter solo conoce `/android`). El receptor **no**
  se incluye nunca en ese build. ✔ Cumple el requisito sin tocar el gradle actual.
- El receptor se compila aparte:
  `cd connect_remote_control && ./gradlew :app:assembleRelease`.
- **No** se añade `include(...)` del receptor en `android/settings.gradle.kts`
  (eso lo metería en el build principal). Permanecen separados.
- Añadir a `.gitignore` los artefactos del receptor
  (`connect_remote_control/app/build/`, `.gradle/`) pero **versionar el código**.
- Reutilizar el mismo `debug.keystore` (copiándolo) si se quiere firma estable,
  igual que hace `connect`, para evitar conflictos de instalación.

---

## 7. Orden de implementación (checklist ejecutable)

**Fase 1 — Transporte y esqueleto receptor**
1. [ ] Generar y fijar `REMOTE_SPP_UUID` (mismo valor en emisor y receptor).
2. [ ] Crear proyecto `connect_remote_control/` (gradle + manifest + MainActivity vacía).
3. [ ] `RemoteServerService` con accept loop + log de JSON recibido.
4. [ ] `RemoteControlClient.kt` en `connect` + canal `remote_control` en MainActivity.
5. [ ] Probar conexión cruda: enviar `ping` desde un botón temporal y verlo en logs del receptor.

**Fase 2 — UI emisor**
6. [ ] `remote_control_service.dart` (connect/discovery/send + throttling de move).
7. [ ] `remote_control_screen.dart` (touchpad + dropdown + teclado).
8. [ ] Tile en `herramientas_screen.dart`.

**Fase 3 — Inyección receptor**
9. [ ] `RemoteAccessibilityService` + `remote_accessibility_service.xml`.
10. [ ] `CursorOverlayView` (overlay + clamp + sensibilidad).
11. [ ] `RemoteInputController` (move/tap/scroll/drag/text/key).
12. [ ] `OnboardingActivity` + `PermissionHelper` (todos los permisos guiados).

**Fase 4 — Robustez y compatibilidad**
13. [ ] Reconexión, keepalive (`ping`/`pong`), feedback de estado en ambas apps.
14. [ ] Soporte Android TV (leanback, D-pad, focus).
15. [ ] Manejo de degradación en `minSdk` bajos (API < 24).

**Fase 5 — Pruebas y entrega**
16. [ ] Matriz de pruebas (ver §8).
17. [ ] Verificar que `flutter build apk --split-per-abi` de `connect` sigue igual
        y que ninguna funcionalidad existente cambió.
18. [ ] Build del receptor y prueba en teléfono + (si disponible) Android TV.

---

## 8. Pruebas / verificación

- **No-regresión `connect`**: notificaciones, media, bola flotante, widgets y
  conexión BT actual siguen funcionando (el control remoto usa canal/UUID aparte).
- **Control remoto**:
  - Descubrir y conectar al receptor desde el dropdown.
  - Mover cursor con touchpad; click, doble click, click derecho, scroll, drag.
  - Escribir texto en un campo del receptor; backspace/enter.
  - TV: navegación D-pad + cursor.
  - Reconexión tras alejar/acercar / apagar-encender BT.
- **Permisos receptor**: flujo de onboarding concede overlay + accesibilidad + BT
  y el receptor queda operativo en segundo plano.
- **Aislamiento build**: confirmar que el receptor no entra en el APK de `connect`.

---

## 9. Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| `dispatchGesture` no disponible (<API 24) | Subir `minSdk` a 24 o degradar a taps absolutos con aviso |
| Texto no se inserta sin campo enfocado | Feedback en UI; usar PASTE; documentar limitación |
| `foregroundServiceType` rechazado en SDK altos | Usar `connectedDevice` y justificar; validar por versión |
| Colisión con el UUID del puente actual | **UUID dedicado** distinto del `00001101-...` |
| Romper el build de `connect` | Receptor en carpeta/proyecto Gradle separado, sin `include` en el settings principal |
| Android TV sin pantalla táctil | Cursor overlay + D-pad; `touchscreen` no requerido |
| Latencia del touchpad | Coalescing de `move` a ~60 Hz; envío binario corto |

---

## 10. Resumen de archivos a crear/editar

**Editar en `connect`:**
- `lib/screens/emisor/herramientas_screen.dart` (1 tile nuevo)
- `android/app/src/main/kotlin/com/example/connect/MainActivity.kt` (1 canal nuevo)

**Crear en `connect`:**
- `lib/screens/emisor/remote_control_screen.dart`
- `lib/services/remote_control_service.dart`
- `android/app/src/main/kotlin/com/example/connect/RemoteControlClient.kt`

**Crear subproyecto `connect_remote_control/`** (nativo Kotlin, ver §B.1):
- `MainActivity.kt`, `OnboardingActivity.kt`, `RemoteServerService.kt`,
  `RemoteAccessibilityService.kt`, `RemoteInputController.kt`,
  `CursorOverlayView.kt`, `PermissionHelper.kt` + manifest, recursos y gradle.

> Ningún archivo existente de notificaciones, media, bola flotante o widgets se
> modifica. El control remoto es **100% aditivo** y aislado.
