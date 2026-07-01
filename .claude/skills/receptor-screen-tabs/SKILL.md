---
name: receptor-screen-tabs
description: Método correcto para reordenar y reestructurar VISUALMENTE una pantalla en pestañas (TabBar desplazable) agrupando mejor su contenido, sin tocar el core. Úsala SIEMPRE al rediseñar/ordenar pantallas del receptor (lib/screens/receptor/*) — o cualquier pantalla de configuración con contenido mezclado en cards/ExpansionTile largas — para aplicar el mismo patrón ya usado en floating_ball_style_screen, floating_ball_settings_screen y receptor_settings_screen. Regla central: NO tocar el core (estado, handlers, servicios, MethodChannel, persistencia, navegación), solo la interfaz.
---

# Reestructurar una pantalla en pestañas (solo interfaz)

Patrón validado para convertir una pantalla larga de **cards/ExpansionTile apiladas**
en un **menú superior de pestañas desplazables** (`TabBar` + `TabBarView`), agrupando
mejor el contenido. Aplícalo a pantallas del receptor y de configuración.

Ejemplos ya hechos con este método (úsalos de referencia):
- [floating_ball_style_screen.dart](../../../lib/screens/emisor/floating_ball_style_screen.dart) — pantalla enorme (~5700 líneas), pestañas adaptativas según un toggle de modo.
- [floating_ball_settings_screen.dart](../../../lib/screens/emisor/floating_ball_settings_screen.dart) — pantalla mediana, 3 pestañas.
- [receptor_settings_screen.dart](../../../lib/screens/receptor/receptor_settings_screen.dart) — reordenó contenido mezclado + rediseñó botones a cards + pestaña de Permisos.

---

## REGLA DE ORO: no tocar el core, solo la interfaz

Esta skill **solo cambia el árbol de widgets (la presentación)**. Está PROHIBIDO
modificar el "cerebro" de la pantalla. Si un cambio toca algo de la columna
izquierda, NO es parte de esta skill.

| ❌ Core — NO tocar | ✅ Interfaz — sí se reestructura |
|---|---|
| Campos de estado (`_xxx`) y sus valores por defecto | Contenedores: `Card`/`ExpansionTile` → pestañas |
| `initState`, `dispose`, `_load*`, `didChangeAppLifecycleState` | Agrupación y orden de las secciones |
| Handlers: `onTap`, `onChanged`, `_toggle*`, `_set*`, `_pick*` | Cómo se ve cada opción (botón plano → card explicativa) |
| Llamadas a servicios / `FloatingBallService` / `MethodChannel` | Encabezados, descripciones, iconos, padding |
| Persistencia (`SharedPreferences`, prefs keys) | Estilo del `AppBar`/`TabBar` |
| Rutas de navegación (`Navigator.pushNamed`, `MaterialPageRoute`) y sus destinos | — |
| `bottomNavigationBar` y su lógica | — |

Los **destinos** de navegación se conservan idénticos: si un botón iba a
`'/conversation_apps'`, la card nueva va al mismo sitio. Solo cambia cómo se ve el
disparador, nunca a dónde lleva ni qué hace.

Al terminar: `flutter analyze <archivo>` debe dar **0 errores**. Los avisos `info`
preexistentes (p. ej. `avoid_print`, `use_build_context_synchronously`,
`activeColor` deprecado) que ya estaban antes son aceptables; no introduzcas nuevos.

---

## Estructura objetivo

```dart
@override
Widget build(BuildContext context) {
  return DefaultTabController(
    length: _modo ? N : M,            // ver "pestañas adaptativas"
    key: ValueKey(_modo),             // SOLO si length cambia según un flag
    child: Scaffold(
      appBar: AppBar(
        title: const Text('<Título>'),
        backgroundColor: customColor[700],
        foregroundColor: Colors.white,
        bottom: _isLoading
            ? null
            : const TabBar(
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabAlignment: TabAlignment.start,
                tabs: [ Tab(text: 'A'), Tab(text: 'B'), Tab(text: 'C') ],
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              children: [ _buildTabA(), _buildTabB(), _buildTabC() ],
            ),
      bottomNavigationBar: /* si existía, se conserva TAL CUAL */,
    ),
  );
}
```

`DefaultTabController` evita tener que crear un `TabController` con mixin
`TickerProvider`. Envuelve al `Scaffold` para que el `TabBar` (en `appBar.bottom`)
y el `TabBarView` (en `body`) compartan el mismo controlador.

---

## Helpers obligatorios (copiar a la pantalla)

```dart
// Contenedor desplazable de una pestaña. Reemplaza a las antiguas cards.
Widget _tabPage(List<Widget> children) {
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    children: children,
  );
}

// Encabezado descriptivo al inicio de cada pestaña.
Widget _tabHeader(String title, String subtitle) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const Divider(height: 20),
      ],
    ),
  );
}
```

Cada pestaña es `_tabPage([ _tabHeader(titulo, descripcion), ...contenido ])`.

> ⚠️ Si pones un `Column` como hijo directo de `_tabPage` (un `ListView`), ese
> `Column` debe llevar `mainAxisSize: MainAxisSize.min` (altura no acotada).

---

## Cómo agrupar y ordenar el contenido

1. **Una pestaña = un grupo lógico.** Identifica los temas reales de la pantalla.
   El error típico es tener cards con contenido mezclado (p. ej. acciones del
   dispositivo + un permiso + toggles juntos). Sepáralos por tema.
2. **Mueve cada opción a la pestaña que le corresponde**, aunque antes estuviera en
   otra card. Ejemplo real del receptor: el permiso de notificaciones salió de
   "Opciones de dispositivo" y se fue a la pestaña **Permisos**; los ajustes de
   notificación dispersos en dos cards se unificaron en **Notificaciones**.
3. **Subgrupos dentro de una pestaña**: está bien dejar `ExpansionTile` anidados
   como sub-secciones *dentro* de una pestaña. Lo que confunde y se elimina es la
   navegación de primer nivel por cards plegables.
4. **El número de pestañas debe ser legible.** Si son muchas, el `TabBar` es
   `isScrollable: true` (se desliza a los lados) — eso es lo correcto, no las apiles.

---

## Rediseño de cada opción (mejor diseño)

Convierte botones de navegación planos (`ElevatedButton.icon`) en **cards
explicativas** (icono en chip + título + descripción + chevron). Helper sugerido:

```dart
Widget _navCard({
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
  Color? color,
}) {
  final c = color ?? customColor[600]!;
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: c, size: 26),
      ),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black54)),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,                 // ← MISMO destino que el botón original
    ),
  );
}
```

Para switches usa un `_switchCard` equivalente con `activeThumbColor` (NO el
`activeColor` deprecado), reutilizando el handler `onChanged` existente. Los
handlers `_toggle*` suelen ser `void Function(bool?)`; el parámetro del helper se
declara `ValueChanged<bool?>` y se pasa tal cual a `Switch.onChanged`.

---

## Pestaña de Permisos (cuando aplique)

Patrón para mostrar **cada permiso con su estado (Concedido / No concedido)** y una
acción para concederlo. Ver implementación en
[receptor_settings_screen.dart](../../../lib/screens/receptor/receptor_settings_screen.dart).

- Descriptor `_PermItem { id, icon, title, subtitle, check, action, actionLabel }`
  donde `check: Future<bool> Function()` y `action: Future<void> Function()`.
- Lista `_permItems` con un item por permiso solicitado por el receptor.
- `_loadPermissions()` recorre la lista, guarda estados en `Map<String,bool> _permStatus`
  y hace `setState`. Se llama en `_initializeSettings` y en
  `didChangeAppLifecycleState` (resumed), para refrescar al volver de los ajustes.
- `_buildPermissionCard(item)` pinta el chip de estado (verde/rojo) + botón que hace
  `await item.action(); await _loadPermissions();`.

Fuentes de estado de permisos en este proyecto (no reinventarlas):
- **permission_handler**: `(await Permission.xxx.status).isGranted` / `.request()`
  (`notification`, `bluetoothConnect`, `bluetoothScan`, `location`, `audio`, …).
- **Acceso a notificaciones (listener)**: canal nativo
  `MethodChannel('com.example.connect/notifications').invokeMethod('isNotificationServiceEnabled')`
  y `'openNotificationSettings'` para abrir ajustes.
- **Overlay / Accesibilidad / Batería**: `FloatingBallService.isOverlayPermissionGranted` /
  `isAccessibilityEnabled` / `isBatteryOptimizationIgnored` (+ sus `open*/request*`).

---

## Pestañas adaptativas (contenido que depende de un modo)

Cuando el contenido cambia según un flag (ej. `_fullScreen` en el style screen):
- `DefaultTabController(key: ValueKey(_flag), length: _flag ? N : M, …)` — el `key`
  fuerza recrear el controlador cuando cambia el número de pestañas.
- Usa **collection-if** en `tabs:` y en `children:` con la MISMA condición, de modo
  que ambos produzcan exactamente la misma cantidad en cada modo:

```dart
tabs: [
  const Tab(text: 'Base'),
  if (!_flag) const Tab(text: 'X'),
  if (_flag) ...[ const Tab(text: 'A'), const Tab(text: 'B') ],
  const Tab(text: 'Último'),   // pestañas siempre presentes pueden ir al final
],
// children del TabBarView: MISMA estructura de if/spread, mismo orden.
```

---

## Dos técnicas de implementación

### A) Reescritura por límites (pantallas enormes)
Para archivos gigantes (miles de líneas) donde reordenar todo es arriesgado:
**conserva el contenido hoja intacto y edita SOLO los wrappers** entre secciones.
Cada `Card(child: ExpansionTile(... children: [X, Y, Z]))` se transforma en
`_tabPage([ _tabHeader(...), X, Y, Z ])` cambiando la apertura y el cierre, sin
tocar X/Y/Z. Los `ExpansionTile` anidados se quedan como subgrupos. Así se hizo el
style screen. Verifica los corchetes con `flutter analyze` tras cada edición.

### B) Reconstrucción en métodos `_buildXxxTab()` (pantallas medianas)
Cuando además **reordenas y rediseñas** (mover opciones, botón→card): escribe
métodos `_buildTabA()/_buildTabB()/…` con el contenido nuevo (reutilizando los
handlers existentes), **borra el body viejo** y conecta el `TabBarView` a esos
métodos. Así se hizo el receptor_settings_screen. Conserva intactos los métodos de
estado y los helpers ya existentes (p. ej. `_buildLocalNotificationsToggleCard`).

---

## Checklist al aplicar la skill

- [ ] `tabs.length` == nº de hijos del `TabBarView` == `length` del controlador, en
      TODOS los modos. (Es el error más común; cuéntalo a mano por cada modo.)
- [ ] El orden de las etiquetas coincide con el orden de las páginas.
- [ ] No cambiaste ningún `onTap`/`onChanged`/destino de navegación/llamada a servicio.
- [ ] No tocaste estado, `_load*`, persistencia, `MethodChannel`, ni `bottomNavigationBar`.
- [ ] `AppBar`: `backgroundColor: customColor[700]`, `foregroundColor: Colors.white`;
      `TabBar` con `isScrollable`, `labelColor` blanco, `indicatorColor` blanco,
      `tabAlignment: TabAlignment.start`.
- [ ] `TabBar`/`TabBarView` solo se muestran cuando `!_isLoading` (bottom `null` y
      body `CircularProgressIndicator` mientras carga).
- [ ] `flutter analyze <archivo>` → 0 errores (avisos preexistentes OK; 0 nuevos).
- [ ] Tras terminar, pregunta al usuario si compila las 3 APK (ver `CLAUDE.md`).
