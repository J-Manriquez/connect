---
name: customization-detail-standard
description: El ESTÁNDAR de granularidad de personalización de connect — el nivel de detalle con el que ya se configuran la bola flotante y los widgets de música (cada color, tamaño, espaciado, margen, radio, icono y offset es ajustable por elemento, con preview en vivo, persistencia y reset). Úsala para (a) entender hasta qué punto se personaliza una interfaz en este proyecto y (b) ESPECIFICAR/exigir ese mismo nivel de detalle al diseñar una pantalla o widget nuevo. Es la vara de medir; no documenta una pantalla concreta sino el listón de "qué debe ser configurable y cómo".
---

# Estándar de granularidad de personalización (connect)

En connect, "personalizable" no significa un par de colores: significa que **cada propiedad
visual de cada elemento** es ajustable por el usuario, con vista previa en vivo, persistencia
inmediata y opción de restablecer. Esta skill fija ese listón para pedir lo mismo a pantallas
y widgets nuevos.

Referencias vivas (la vara real):
- [floating_ball_style_screen.dart](../../../lib/screens/emisor/floating_ball_style_screen.dart)
  — ~5700 líneas, **+300 controles** de estilo en una sola pantalla.
- [widget_editor_screen.dart](../../../lib/screens/emisor/widget_editor_screen.dart) +
  [widget_music_preview.dart](../../../lib/widgets/widget_music_preview.dart) — editor con
  preview en vivo y persistencia espejo Flutter↔nativo (ver `connect-widgets-integration`).

---

## El listón: qué debe ser configurable

Para CADA elemento visible (bola, botón, icono, texto, barra, tarjeta, popup, fila…),
asume que el usuario podrá ajustar **todo lo aplicable** de esta lista:

| Dimensión | Ejemplos reales en connect |
|---|---|
| **Color** | color de la bola, del icono, de fondo, de botones, de bordes, de textos, de pista/relleno de barra, velo sobre carátula |
| **Color con opacidad** | velo, fondos translúcidos (ARGB con slider de alpha aparte) |
| **Tamaño** | tamaño de la bola, del icono, de textos (sp), de iconos de apps vs sistema por separado |
| **Espaciado** | espacio entre botones (sistema), entre apps, entre filas; padding del botón/sticky/contenedor |
| **Margen** | margen botones de acción, margen botones de apps |
| **Radio** | radio de esquinas de botones |
| **Posición / Offset** | offset X/Y del popup, del popup multimedia (en dp, horizontal/vertical) |
| **Iconos por elemento** | override PNG/SVG por icono (volumen, prev, play, pause, next, back, home, recientes, brillo, ajustes, chats…), cada uno con su **acción** asociada |
| **Visibilidad / Toggles** | pantalla completa, ocultar textos (solo iconos), mostrar/ocultar botón |
| **Texto literal** | textos "sin multimedia", etiquetas |
| **Escala global** | escala del contenido (%), que multiplica tamaños |
| **Grosor** | grosor de barra de progreso, de barra de volumen |
| **Negrita** | por cada bloque de texto (título / subtítulo / tiempos) |

**Regla de separación por contexto**: cuando un elemento existe en dos contextos (p. ej.
botones **de sistema** vs **de apps**), cada contexto tiene su propio set de color/borde/
tamaño/espaciado. No se reutiliza un único valor "para todo".

**Regla de override por instancia**: los iconos son reemplazables uno a uno (no "un tema de
iconos"), cada uno guarda su origen (built-in / imagen / SVG con color+tamaño) y su acción.

---

## El listón: cómo se ofrece y se aplica

Toda personalización en connect cumple este contrato (replícalo en lo nuevo):

1. **Preview en vivo.** Hay una vista previa en Dart que refleja el cambio **mientras** se
   ajusta (no "guardar y ver"). Para widgets nativos, la preview Dart replica el RemoteViews.
2. **Persistencia inmediata por propiedad.** Cada control persiste su valor (típicamente en
   `shared_preferences`) — sliders persisten en `onChangeEnd`, no en cada frame.
3. **Defaults explícitos y, si hay lado nativo, espejo.** Cada propiedad tiene su default;
   los de Flutter y Kotlin deben coincidir (ver `flutter-home-screen-widgets`).
4. **Restablecer.** Botón de reset que borra la personalización (por elemento o global) y
   vuelve a defaults.
5. **Organización en secciones/pestañas.** Con tantos controles, se agrupan en pestañas
   (Tamaño / Fondo / Iconos / Barras / Textos…) con la preview fija arriba. Para reordenar/
   estructurar esas pantallas sigue `receptor-screen-tabs` (no tocar el core, solo UI).
6. **Controles reutilizables.** Un puñado de helpers (`_sliderTile`, `_colorTile`,
   `_textGroup`, `_iconTile`, selector de color con hex + paleta + opacidad) se reusan para
   los cientos de ajustes. No se escribe UI ad-hoc por propiedad.

---

## Cómo usar esta skill

### Para ENTENDER el nivel de detalle existente
Cuando alguien pregunte "¿cuánto se puede personalizar X?", la respuesta base es: **todo lo
de la tabla de arriba que aplique al elemento**, con preview en vivo + persistencia + reset.
Mira las referencias vivas para el catálogo exacto.

### Para ESPECIFICAR una pantalla/widget nuevo con este nivel
Al diseñar algo nuevo, recorre la tabla por cada elemento visible y decide explícitamente
qué se expone. Plantilla de especificación:

```
Elemento: <p. ej. "tarjeta de notificación">
  Color de fondo:        [sí, ARGB+alpha]   default #...
  Color de texto:        [sí]               default #...
  Tamaño de texto:       [sí, sp 8–80]      default 14
  Radio de esquinas:     [sí, 0–32dp]       default 12
  Padding interno:       [sí, 0–48dp]       default 12
  Margen entre tarjetas: [sí, 0–48dp]       default 8
  Icono:                 [override por icono + acción]
  Visibilidad:           [toggle]
  ...
Contrato: preview en vivo ✔ · persiste onChangeEnd ✔ · default espejo (si nativo) ✔ · reset ✔
Agrupación: pestañas [Colores][Tamaños][Iconos][Textos]
```

### Frase para PEDIR este nivel a otro agente / en un prompt
> "Hazlo con el mismo nivel de detalle de personalización que la bola flotante y los widgets
> de música: cada color/tamaño/espaciado/margen/radio/icono/offset ajustable por elemento
> (separando contextos como sistema vs apps), con preview en vivo, persistencia por propiedad,
> defaults explícitos (espejo si hay lado nativo) y botón de restablecer. Sigue la skill
> `customization-detail-standard`."

---

## Anti-patrones (lo que NO cuenta como "personalizable" en connect)
- Un solo color/tamaño "global" que afecta a todo por igual.
- Cambios que solo se ven tras guardar y reabrir (sin preview en vivo).
- Iconos como "tema" en bloque en vez de override por icono.
- Persistir en cada frame del slider (spamea el repintado nativo).
- Defaults distintos entre Flutter y el widget nativo (preview y widget divergen).
- UI ad-hoc por propiedad en vez de helpers reutilizables.
