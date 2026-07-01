# PLAN: Widget de Presentación de Imágenes — Pantalla de Inicio

> Última actualización: 2026-06-27 (decisiones confirmadas)  
> Branch objetivo: crear desde `menos-8` o nuevo branch `feature/image-slideshow-widget`  
> Skills de referencia: `flutter-home-screen-widgets`, `connect-widgets-integration`, `customization-detail-standard`

---

## 1. Visión general

Widget de pantalla de inicio Android que muestra imágenes de una carpeta del dispositivo como
presentación de diapositivas automática. El usuario configura la carpeta, el intervalo, el
efecto visual y docenas de opciones de estilo desde una pantalla dentro de la app, con
**vista previa en vivo** que replica el widget real.

### Restricciones técnicas de RemoteViews (fundamentales para entender las decisiones)

`RemoteViews` no soporta animaciones, gestos, vistas personalizadas ni temporizadores.
Por eso:
- El **avance automático** se implementa con `AlarmManager` (broadcast periódico).
- Las **transiciones** son transformaciones de `Bitmap` en Kotlin (no animaciones entre frames).
- Los **efectos** se aplican al bitmap antes de enviarlo al widget (Ken Burns = recorte + escala,
  fundido = composición con capa de color).

---

## 2. Arquitectura: el puente Flutter ↔ Android nativo

```
Flutter                                  Android nativo
──────────────────────────────────────   ──────────────────────────────────────────────
ImageWidgetService.dart                  ImageSlideShowWidgetProvider.kt
  - config en SharedPreferences          - onUpdate → setup AlarmManager
  - copia imágenes a internal storage    - ACTION_ADVANCE → avanza índice → repinta
  - MethodChannel("updateImageWidget")   - ACTION_PREV / ACTION_NEXT (tap manual)
                                         - buildRemoteViews() → aplica efectos Bitmap
                                         - companion: readCfg / applyEffect / renderFrame
```

**Clave canónica:** `widget_cfg_img_<prop>` → SharedPreferences como `flutter.widget_cfg_img_<prop>`

**Almacenamiento de imágenes:** cuando el usuario selecciona una carpeta, Flutter copia y
redimensiona las imágenes (máx 800px lado mayor, JPEG q=85) al directorio interno de la app:
`getFilesDir()/image_widget/`. La lista de rutas se guarda como JSON en prefs.
Esto evita los problemas de permisos de SAF en RemoteViews.

---

## 3. Archivos a crear / modificar

### 3.1 Flutter — nuevos

| Archivo | Responsabilidad |
|---|---|
| `lib/services/image_widget_service.dart` | Modelo de config + persistencia + copia de imágenes + MethodChannel |
| `lib/widgets/image_widget_preview.dart` | Preview Dart del widget (replica RemoteViews) |
| `lib/screens/emisor/image_widget_editor_screen.dart` | Editor completo: preview fija + 6 pestañas de ajustes |

### 3.2 Android nativo — nuevos

| Archivo | Responsabilidad |
|---|---|
| `android/.../ImageSlideShowWidgetProvider.kt` | Provider + AlarmManager + efectos Bitmap |
| `android/.../res/layout/widget_image_slideshow.xml` | Layout RemoteViews: ImageView + overlay + caption + dots |
| `android/.../res/xml/image_slideshow_widget_info.xml` | Descriptor `appwidget-provider` |

### 3.3 Archivos existentes a modificar

| Archivo | Cambio |
|---|---|
| `AndroidManifest.xml` | + permiso `READ_MEDIA_IMAGES` + `<receiver>` para el widget |
| `MainActivity.kt` | + case `"updateImageWidget"` en el BLE MethodChannel |
| `lib/screens/emisor/settings_screen.dart` | + tile "Widget de imágenes" que navega al editor |
| `lib/main.dart` | + ruta nombrada `/image_widget_editor` |

---

## 4. Especificación detallada: `ImageWidgetConfig` y sus propiedades

Todas las propiedades siguen el estándar del proyecto: preview en vivo, `onChangeEnd`
para persistir, defaults espejo Flutter↔Kotlin, botón de restablecer por sección.

### Tab 1 — Fuente

| Propiedad | Tipo | Default | Clave prefs |
|---|---|---|---|
| Carpeta seleccionada | String | `''` | `img_folder_path` |
| Lista de rutas de imágenes (JSON) | String | `'[]'` | `img_file_list` |
| Índice actual | int | `0` | `img_current_index` |
| Barajar imágenes | bool | `false` | `img_shuffle` |
| Bucle infinito | bool | `true` | `img_loop` |
| Segundos por imagen | int (3–300) | `10` | `img_interval_sec` |
| Segundos para ocultar controles | int (2–30) | `5` | `img_controls_hide_delay_sec` |
| Controles visibles (estado runtime) | bool | `false` | `img_controls_visible` |

**UI del tab:**
- Botón "Seleccionar carpeta" → `FilePicker.platform.getDirectoryPath()` → Isolate copia + redimensiona con barra de progreso → guarda lista.
- Chip/badge con número de imágenes encontradas.
- Switch "Barajar" con vista previa que reorganiza las miniaturas.
- Switch "Bucle".
- Slider "Segundos por imagen" (3–300s, step 1, mostrar valor en tiempo `mm:ss`).
- Slider "Ocultar controles tras…" (2–30s, step 1) — tiempo de inactividad antes de ocultar botones prev/next.

### Tab 2 — Transición

| Propiedad | Tipo | Default | Clave prefs |
|---|---|---|---|
| Tipo de efecto | int (0–3) | `0` | `img_fx_type` |
| Intensidad del zoom Ken Burns (%) | int (100–160) | `115` | `img_fx_zoom_pct` |
| Color de fade/cortina | ARGB | `0xFF000000` | `img_fx_color` |

**Tipos de efecto (valores int):**
- `0` — Ninguno (imagen directa)
- `1` — Ken Burns (zoom lento: cada actualización recorta el bitmap desplazado levemente)
- `2` — Fundido al negro (la imagen siguiente aparece con una capa negra que va disminuyendo; implementado con 3 updates rápidos de widget a 0%, 50%, 100% opacidad)
- `3` — Fundido al blanco (igual pero con capa blanca)

**UI del tab:**
- SegmentedButton o RadioListTile por efecto (con icono ilustrativo).
- Slider "Intensidad del zoom" (visible solo si fx = Ken Burns).
- ColorPicker "Color de cortina" (visible solo si fx = Fundido).

### Tab 3 — Marco y Borde

| Propiedad | Tipo | Default | Clave prefs |
|---|---|---|---|
| Radio de esquinas del widget (dp) | int (0–80) | `16` | `img_corner_radius_dp` |
| Padding interno (dp) | int (0–32) | `0` | `img_padding_dp` |
| Mostrar borde | bool | `false` | `img_border_show` |
| Color del borde | ARGB | `0xFFFFFFFF` | `img_border_color` |
| Grosor del borde (dp) | int (0–16) | `2` | `img_border_thickness_dp` |

**Notas de implementación:**
- El radio de esquinas se aplica en Kotlin usando un `Bitmap` con `Path.addRoundRect` + `Canvas.clipPath`.
- El borde se dibuja con `Paint(Style.STROKE)` sobre el bitmap ya recortado.
- La preview en Dart usa `ClipRRect(borderRadius: BorderRadius.circular(radius))` + `Container(decoration: BoxDecoration(border: Border.all(...)))`.

### Tab 4 — Imagen (ajuste y overlay)

| Propiedad | Tipo | Default | Clave prefs |
|---|---|---|---|
| Modo de ajuste de imagen | int (0–2) | `0` | `img_scale_type` |
| Mostrar superposición | bool | `false` | `img_scrim_show` |
| Color de superposición (ARGB) | int | `0x80000000` | `img_scrim_color` |
| Opacidad de superposición (%) | int (0–100) | `50` | `img_scrim_opacity` |

**Modos de ajuste (`img_scale_type`):**
- `0` — Rellenar / Cubrir (centerCrop — sin bordes negros, puede recortar bordes)
- `1` — Contener (fitCenter — imagen completa visible, bandas del color de fondo)
- `2` — Estirar (fitXY — ocupa todo el widget, puede distorsionar)
- `3` — Centro sin escalar (center — imagen a tamaño real, recorta si es más grande)
- `4` — Ajustar al ancho (fitStart/fitEnd con crop vertical centrado)

**Color de fondo para modo Contener:** cuando el modo es `1` (fitCenter) las bandas usan
el color de fondo configurable por separado:

| Propiedad | Tipo | Default | Clave prefs |
|---|---|---|---|
| Color de fondo (bandas) | ARGB | `0xFF000000` | `img_bg_color` |

**Nota:** el "Color de superposición" tiene canal alpha propio más el slider de opacidad extra
(igual que los widgets de música con `scrimArgb` + `artAlpha`).

### Tab 5 — Texto / Pie de foto

| Propiedad | Tipo | Default | Clave prefs |
|---|---|---|---|
| Mostrar pie de foto | bool | `false` | `img_caption_show` |
| Fuente del pie | int (0–1) | `0` | `img_caption_source` |
| Color del texto del pie | ARGB | `0xFFFFFFFF` | `img_caption_color` |
| Tamaño del texto del pie (sp) | int (8–36) | `14` | `img_caption_size_sp` |
| Negrita del pie | bool | `false` | `img_caption_bold` |
| Posición del pie | int (0–1) | `1` | `img_caption_position` |
| Color de fondo del pie | ARGB | `0x99000000` | `img_caption_bg` |
| Padding del pie (dp) | int (0–24) | `8` | `img_caption_pad_dp` |

**Fuentes del pie (valores int):**
- `0` — Nombre del archivo (sin extensión)
- `1` — Fecha de modificación del archivo

**Posición del pie (valores int):**
- `0` — Arriba
- `1` — Abajo

**Implementación Kotlin:** el texto se dibuja sobre el bitmap con `Canvas.drawText` usando un
`Paint` configurado con el color, tamaño y negrita definidos, sobre un rectángulo de fondo
dibujado en la posición configurada.

**Implementación Dart (preview):** `Positioned(bottom/top: 0, child: Container(color:..., child: Text(...)))`.

### Tab 6 — Indicador de posición (dots)

| Propiedad | Tipo | Default | Clave prefs |
|---|---|---|---|
| Mostrar indicador | bool | `false` | `img_dots_show` |
| Color del dot activo | ARGB | `0xFFFFFFFF` | `img_dots_active_color` |
| Color del dot inactivo | ARGB | `0x80FFFFFF` | `img_dots_inactive_color` |
| Tamaño del dot (dp) | int (4–16) | `8` | `img_dots_size_dp` |
| Espaciado entre dots (dp) | int (2–16) | `6` | `img_dots_spacing_dp` |
| Posición del indicador | int (0–1) | `1` | `img_dots_position` |

**Implementación Kotlin:** se dibuja una fila de círculos con `Canvas.drawCircle` en la
posición configurada. El dot del índice activo usa el color activo; los demás el inactivo.
Se dibuja sobre el bitmap antes de enviarlo al widget.

**Límite:** máximo 12 dots visibles (si hay más imágenes, se muestra solo un subset centrado
en el actual). Este límite evita que los dots desborden el widget.

---

## 5. Especificación detallada: `ImageSlideShowWidgetProvider.kt`

```kotlin
// Estructura de clases
object ImageSlideShowWidgetProvider : AppWidgetProvider() {
    // Acciones
    const val ACTION_ADVANCE = "com.example.connect.IMAGE_WIDGET_ADVANCE"
    const val ACTION_PREV    = "com.example.connect.IMAGE_WIDGET_PREV"
    const val ACTION_NEXT    = "com.example.connect.IMAGE_WIDGET_NEXT"

    // Defaults (espejo exacto de ImageWidgetService.dart)
    const val DEF_INTERVAL_SEC = 10
    const val DEF_CORNER_RADIUS_DP = 16
    const val DEF_PADDING_DP = 0
    // ... (todos los defaults de la tabla)

    fun updateAll(context: Context)
    fun scheduleAdvance(context: Context, intervalSec: Int)
    fun cancelAdvance(context: Context)
    fun readCfg(prefs: SharedPreferences): ImageWidgetCfg
    fun buildRemoteViews(context: Context, cfg: ImageWidgetCfg, imagePaths: List<String>): RemoteViews
    fun loadAndProcessBitmap(path: String, cfg: ImageWidgetCfg): Bitmap?
    fun applyCornerRadius(bmp: Bitmap, radiusPx: Float): Bitmap
    fun applyScrim(bmp: Bitmap, colorArgb: Int): Bitmap
    fun applyCaption(bmp: Bitmap, text: String, cfg: ImageWidgetCfg): Bitmap
    fun applyDots(bmp: Bitmap, total: Int, current: Int, cfg: ImageWidgetCfg): Bitmap
    fun applyKenBurns(bmp: Bitmap, index: Int, zoomPct: Int): Bitmap
    fun drawBorder(bmp: Bitmap, colorArgb: Int, thicknessPx: Float): Bitmap
}

data class ImageWidgetCfg(
    val folderPath: String,
    val imageList: List<String>,    // rutas absolutas en internal storage
    val currentIndex: Int,
    val shuffle: Boolean,
    val loop: Boolean,
    val intervalSec: Int,
    val fxType: Int,
    val fxZoomPct: Int,
    val fxColor: Int,
    val cornerRadiusDp: Int,
    val paddingDp: Int,
    val borderShow: Boolean,
    val borderColor: Int,
    val borderThicknessDp: Int,
    val scaleType: Int,
    val scrimShow: Boolean,
    val scrimColor: Int,
    val scrimOpacity: Int,
    val captionShow: Boolean,
    val captionSource: Int,
    val captionColor: Int,
    val captionSizeSp: Int,
    val captionBold: Boolean,
    val captionPosition: Int,
    val captionBg: Int,
    val captionPadDp: Int,
    val dotsShow: Boolean,
    val dotsActiveColor: Int,
    val dotsInactiveColor: Int,
    val dotsSizeDp: Int,
    val dotsSpacingDp: Int,
    val dotsPosition: Int
)
```

### AlarmManager — ciclo de vida

```
onUpdate (widget añadido / boot / intervalo largo Android)
  → scheduleAdvance(intervalSec)
  → buildAndUpdate()

ACTION_ADVANCE (broadcast de AlarmManager)
  → currentIndex = (currentIndex + 1) % imageCount
  → escribir nuevo índice en SharedPreferences
  → buildAndUpdate()
  → scheduleAdvance(intervalSec)   // re-armar para el siguiente

ACTION_PREV / ACTION_NEXT (tap del usuario — solo visibles cuando controles activos)
  → ajustar índice
  → cancelAdvance()
  → buildAndUpdate()
  → scheduleAdvance(intervalSec)   // reiniciar timer desde ahora
  → scheduleHideControls(hideDelaySec)  // re-armar ocultado de controles

ACTION_TOGGLE_CONTROLS (tap en zona central del widget)
  → if controls_visible → ocultar (img_controls_visible=false) + cancelHideControls
  → if !controls_visible → mostrar (img_controls_visible=true) + scheduleHideControls(hideDelaySec)
  → buildAndUpdate()

ACTION_HIDE_CONTROLS (alarm de auto-ocultado)
  → img_controls_visible = false
  → buildAndUpdate()

onDeleted (widget eliminado)
  → cancelAdvance()
  → cancelHideControls()
```

**`hideDelaySec`** es configurable desde el editor (Tab 1 — Fuente), default 5s, rango 2–30s.
Clave prefs: `img_controls_hide_delay_sec`.

**Nota sobre `setExact` vs `setRepeating`:** usar `AlarmManager.setExact` (o
`setExactAndAllowWhileIdle` para Android 6+) y re-armarlo en cada `ACTION_ADVANCE`.
`setRepeating` tiene jitter de hasta 75% del intervalo en Android moderno.

### Layout `widget_image_slideshow.xml`

```xml
<FrameLayout id="widget_root" match_parent match_parent>
    <ImageView id="widget_image" match_parent match_parent scaleType=centerCrop />
    <!-- scrim / overlay -->
    <View id="widget_scrim" match_parent match_parent visibility=gone />
    <!-- pie de foto arriba -->
    <LinearLayout id="widget_caption_top" match_parent wrap_content gravity=top visibility=gone>
        <TextView id="widget_caption_text_top" />
    </LinearLayout>
    <!-- pie de foto abajo -->
    <LinearLayout id="widget_caption_bottom" match_parent wrap_content gravity=bottom visibility=gone>
        <TextView id="widget_caption_text_bottom" />
    </LinearLayout>
    <!-- botones de navegación manual (prev/next) — siempre presentes, tamaño pequeño, esquinas -->
    <ImageView id="widget_prev_btn" 40dp 40dp layout_gravity=center_vertical|start visibility=gone />
    <ImageView id="widget_next_btn" 40dp 40dp layout_gravity=center_vertical|end visibility=gone />
    <!-- zona de tap central (invisible) — dispara ACTION_TOGGLE_CONTROLS -->
    <View id="widget_tap_zone" match_parent match_parent background=@android:color/transparent />
    <!-- botones de navegación manual — visibilidad controlada por img_controls_visible -->
    <ImageView id="widget_prev_btn" 40dp 40dp layout_gravity=center_vertical|start
        src="@drawable/widget_ic_prev" tint="#FFFFFFFF" visibility=gone />
    <ImageView id="widget_next_btn" 40dp 40dp layout_gravity=center_vertical|end
        src="@drawable/widget_ic_next" tint="#FFFFFFFF" visibility=gone />
</FrameLayout>
```

**Estrategia de renderizado:** todo el contenido visual (imagen, scrim, caption, dots, borde,
esquinas redondeadas) se compone en un único `Bitmap` en Kotlin y se envía a `widget_image`
con `setImageViewBitmap`. Los botones prev/next son Views independientes cuya visibilidad
se alterna con `setViewVisibility`. Esto evita problemas de z-order en RemoteViews.

**`widget_tap_zone`** recibe el tap cuando los controles están ocultos; cuando están visibles,
los botones tienen sus propios `PendingIntent` y el tap en la imagen no interfiere.

---

## 6. Especificación detallada: `ImageWidgetService.dart`

```dart
class ImageWidgetCfgModel {
    // campos espejo de ImageWidgetCfg Kotlin
    String folderPath = '';
    List<String> imageList = [];
    int currentIndex = 0;
    bool shuffle = false;
    bool loop = true;
    int intervalSec = 10;
    // efectos
    int fxType = 0;
    int fxZoomPct = 115;
    int fxColor = 0xFF000000;
    // marco
    int cornerRadiusDp = 16;
    int paddingDp = 0;
    bool borderShow = false;
    int borderColor = 0xFFFFFFFF;
    int borderThicknessDp = 2;
    // imagen
    int scaleType = 0;
    bool scrimShow = false;
    int scrimColor = 0x80000000;
    int scrimOpacity = 50;
    // caption
    bool captionShow = false;
    int captionSource = 0;
    int captionColor = 0xFFFFFFFF;
    int captionSizeSp = 14;
    bool captionBold = false;
    int captionPosition = 1;
    int captionBg = 0x99000000;
    int captionPadDp = 8;
    // dots
    bool dotsShow = false;
    int dotsActiveColor = 0xFFFFFFFF;
    int dotsInactiveColor = 0x80FFFFFF;
    int dotsSizeDp = 8;
    int dotsSpacingDp = 6;
    int dotsPosition = 1;
}

class ImageWidgetService {
    static const _channel = MethodChannel('com.example.connect/ble');

    // Defaults espejo de Kotlin (NUNCA cambiar uno sin el otro)
    static const defIntervalSec = 10;
    static const defCornerRadiusDp = 16;
    // ... (todos los defaults)

    static String _k(String prop) => 'widget_cfg_img_$prop';

    static Future<ImageWidgetCfgModel> load();
    static Future<void> setInt(String prop, int v);
    static Future<void> setBool(String prop, bool v);
    static Future<void> setString(String prop, String v);
    static Future<void> resetAll();
    static Future<void> _notify();  // → MethodChannel("updateImageWidget")

    // Gestión de imágenes
    static Future<void> pickFolderAndCopyImages();
    // Usa FilePicker.platform.getDirectoryPath(), luego lee el directorio con dart:io,
    // filtra extensiones de imagen (.jpg .jpeg .png .gif .webp .bmp),
    // copia + redimensiona (máx 800px) a getApplicationFilesPath() + '/image_widget/',
    // guarda la lista JSON en SharedPreferences, llama _notify().

    static Future<String> _getInternalImageDir();
    // MethodChannel call "getInternalFilesDir" → devuelve getFilesDir().absolutePath + "/image_widget/"
    // (añadir este handler en MainActivity también)
}
```

### Método `pickFolderAndCopyImages` — flujo detallado

```
1. FilePicker.platform.getDirectoryPath() → obtiene ruta de la carpeta
2. Directory(path).listSync() → lista de archivos
3. Filtrar por extensión: ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp']
4. MethodChannel("getInternalFilesDir") → obtiene ruta interna de la app
5. Para cada imagen:
   a. Leer bytes con File(path).readAsBytesSync()
   b. Decodificar con dart:ui Image / package:image
   c. Redimensionar si ancho o alto > 800px (mantener proporción)
   d. Codificar como JPEG quality=85
   e. Escribir en internal_dir/image_widget/<nombre_archivo>.jpg
6. Guardar lista de rutas internas como JSON en SharedPreferences
7. Guardar folderPath original para mostrarlo en UI
8. Llamar _notify()
```

**Dependencias a agregar en pubspec.yaml:**
- `package:image: ^4.x` (para resize) — o usar `flutter_image_compress` si ya está.
- Verificar si `image` ya está como dependencia transitiva; si no, añadirla.

---

## 7. Especificación detallada: `image_widget_preview.dart`

```dart
class ImageWidgetPreview extends StatelessWidget {
    final ImageWidgetCfgModel cfg;
    final int? previewImageIndex;  // null = usar cfg.currentIndex

    // Replica visualmente el RemoteViews:
    // - AspectRatio configurable (default 1:1 square, opciones 16:9, 4:3)
    // - ClipRRect(borderRadius) para el corner radius
    // - Image.file() con BoxFit según scaleType
    // - Container overlay (scrim)
    // - Text (caption)
    // - Row de dots en la posición configurada
    // - Border si está habilitado
    // - Muestra la primera imagen disponible de cfg.imageList, o placeholder si vacía
}
```

La preview usa imágenes reales desde internal storage (las mismas que usa el widget nativo),
no datos de ejemplo. Si `imageList` está vacía, muestra un placeholder con icono de imagen.

---

## 8. Especificación detallada: `image_widget_editor_screen.dart`

### Estructura de la pantalla

```
Scaffold
  AppBar "Widget de imágenes" + botón "Restablecer todo"
  NestedScrollView
    headerSliverBuilder: SliverPersistentHeader (sticky)
      ┌─────────────────────────────────────┐
      │   ImageWidgetPreview (tamaño fijo)   │  ← siempre visible al hacer scroll
      │   + NavigationBar izq/der de imágenes│
      └─────────────────────────────────────┘
      TabBar: [Fuente][Transición][Marco][Imagen][Texto][Indicador]
    body: TabBarView
      Tab 0: Fuente
      Tab 1: Transición
      Tab 2: Marco y borde
      Tab 3: Imagen y overlay
      Tab 4: Texto / pie de foto
      Tab 5: Indicador de posición
```

### Controles reutilizables (mismos helpers que widget_editor_screen.dart)

- `_sliderTile(label, value, min, max, onChanged, onChangeEnd)` — slider con valor
- `_colorTile(label, value, onChanged)` — swatch que abre un dialog de color (hex + paleta + alpha)
- `_switchTile(label, value, onChanged)` — ListTile con Switch
- `_segmentedTile(label, options, value, onChanged)` — SegmentedButton horizontal
- `_sectionHeader(text)` — separador con título de sección

---

## 9. Cambios en `AndroidManifest.xml`

```xml
<!-- Permiso de imágenes (Android 13+) — añadir junto a READ_MEDIA_AUDIO -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />

<!-- Receptor del widget — añadir antes del cierre </application> -->
<receiver android:name=".ImageSlideShowWidgetProvider"
    android:enabled="true"
    android:exported="false"
    android:permission="android.permission.BIND_APPWIDGET">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
        <action android:name="com.example.connect.IMAGE_WIDGET_ADVANCE"/>
        <action android:name="com.example.connect.IMAGE_WIDGET_PREV"/>
        <action android:name="com.example.connect.IMAGE_WIDGET_NEXT"/>
    </intent-filter>
    <meta-data android:name="android.appwidget.provider"
        android:resource="@xml/image_slideshow_widget_info"/>
</receiver>
```

---

## 10. Cambios en `MainActivity.kt`

```kotlin
// En el BLE MethodChannel (com.example.connect/ble), dentro del when(method):

"updateImageWidget" -> {
    try {
        ImageSlideShowWidgetProvider.updateAll(applicationContext)
        result.success(true)
    } catch (e: Exception) {
        result.error("ERROR", e.message, null)
    }
}

"getInternalFilesDir" -> {
    try {
        result.success(applicationContext.filesDir.absolutePath)
    } catch (e: Exception) {
        result.error("ERROR", e.message, null)
    }
}
```

---

## 11. Cambios en `settings_screen.dart`

Añadir un `ListTile` en la sección de Widgets del emisor:

```dart
ListTile(
  leading: const Icon(Icons.image_outlined),
  title: const Text('Widget de imágenes'),
  subtitle: const Text('Presentación de fotos en la pantalla de inicio'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const ImageWidgetEditorScreen())),
),
```

---

## 12. Cambios en `main.dart`

```dart
// En el mapa de rutas:
'/image_widget_editor': (context) => const ImageWidgetEditorScreen(),
```

---

## 13. `image_slideshow_widget_info.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/widget_image_slideshow"
    android:minWidth="110dp"
    android:minHeight="110dp"
    android:minResizeWidth="80dp"
    android:minResizeHeight="80dp"
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="0"
    android:widgetCategory="home_screen" />
```

---

## 14. Dependencias a verificar / añadir en `pubspec.yaml`

| Paquete | Ya presente | Acción |
|---|---|---|
| `file_picker: ^8.1.2` | ✅ | Nada |
| `shared_preferences` | ✅ | Nada |
| `image: ^4.x` | ❓ | Verificar; si no está, añadir para resize |
| `path_provider` | ❓ | Verificar; para obtener filesDir en Flutter si se prefiere evitar MethodChannel |

> Verificar con `grep "image:" pubspec.yaml` y `grep "path_provider:" pubspec.yaml`

---

## 15. Checklist de implementación (orden sugerido)

El orden minimiza el tiempo entre "código compilable" y "widget funcional":

### Fase 1 — Infraestructura mínima funcional (widget visible en pantalla de inicio)
- [ ] Crear `widget_image_slideshow.xml` (layout sencillo: solo `ImageView` + `FrameLayout`)
- [ ] Crear `image_slideshow_widget_info.xml`
- [ ] Crear `ImageSlideShowWidgetProvider.kt` — solo `onUpdate` + `buildRemoteViews` básico (imagen hardcodeada o placeholder)
- [ ] Añadir `<receiver>` en `AndroidManifest.xml` + permiso `READ_MEDIA_IMAGES`
- [ ] Añadir `"updateImageWidget"` y `"getInternalFilesDir"` en `MainActivity.kt`
- [ ] Compilar y verificar que el widget aparece en el selector de widgets de Android

### Fase 2 — Selección de carpeta y carga de imágenes
- [ ] Crear `ImageWidgetService.dart` — solo `load()`, `setX()`, `resetAll()`, `_notify()`
- [ ] Implementar `pickFolderAndCopyImages()` con copia y resize
- [ ] `ImageSlideShowWidgetProvider.kt` — leer lista de imágenes de prefs y mostrar la primera
- [ ] Verificar que al seleccionar una carpeta se ven las imágenes en el widget

### Fase 3 — Avance automático (AlarmManager)
- [ ] `scheduleAdvance()` / `cancelAdvance()` / `ACTION_ADVANCE` en el provider
- [ ] Incremento de índice + re-armado del alarm
- [ ] Verificar que el slideshow avanza automáticamente

### Fase 4 — Preview en vivo en Flutter
- [ ] Crear `ImageWidgetPreview` (placeholder con boxes mientras no hay imágenes, imagen real cuando sí hay)
- [ ] Crear `ImageWidgetEditorScreen` — solo Tab 0 (Fuente) con el botón de carpeta y la preview

### Fase 5 — Controles de estilo (tabs 2–6)
- [ ] Tab 2 Marco y borde → aplicar en preview Dart + en bitmap Kotlin
- [ ] Tab 3 Imagen y overlay → aplicar en preview + Kotlin
- [ ] Tab 4 Texto / pie de foto → preview + Kotlin
- [ ] Tab 5 Indicador de posición → preview + Kotlin

### Fase 6 — Efectos de transición (Tab 1)
- [ ] Tab 1 Transición — selector de tipo
- [ ] Ken Burns: offset del crop por índice de imagen
- [ ] Fundido: 3 actualizaciones rápidas con alpha overlay
- [ ] Verificar en widget real

### Fase 7 — Pulido y botones de navegación manual
- [ ] Botones prev/next en el widget (PendingIntent broadcast → ACTION_PREV/NEXT)
- [ ] Conectar tile en `settings_screen.dart`
- [ ] Ruta en `main.dart`
- [ ] Botones de restablecer por sección en el editor
- [ ] Prueba completa en dispositivo físico

---

## 16. Decisiones de diseño — CONFIRMADAS ✅

1. **Estilos:** 1 solo estilo de layout.
2. **Acceso a imágenes:** Copiar al storage interno (mayor compatibilidad con RemoteViews).
3. **Botones prev/next:** Ocultos por defecto. Al tocar el widget se muestran; al tocar de nuevo se ocultan.
   - Implementación: `ACTION_TOGGLE_CONTROLS` → invierte bool `img_controls_visible` en SharedPreferences → repinta.
   - El estado de controles visibles se resetea automáticamente tras N segundos sin interacción (configurable, default 5s), re-programando un alarm de ocultado.
   - Desde el editor en la app: configuraciones de ajuste de imagen (contener, expandir, rellenar, estirar) como propiedad editable.
4. **Resize:** En Flutter usando `package:image` dentro de un `Isolate`, con barra de progreso ("Copiando 12/45 imágenes…").
5. **Efecto fundido:** 3 renders rápidos (~300ms) simulando fade con capas alpha crecientes.

---

## 17. Consideraciones de rendimiento y batería

- **`setExactAndAllowWhileIdle`** consume más batería que `setRepeating`. Para intervalos > 60s usar `setAndAllowWhileIdle` normal.
- **Copia de imágenes:** hacer en un `Isolate` (Flutter) para no bloquear el UI thread.
- **Tamaño máximo de bitmap:** 800px lado mayor + JPEG q=85 ≈ 50–150KB por imagen. Con 100 imágenes ≈ 5–15MB en internal storage (aceptable).
- **El bitmap que va a `setImageViewBitmap`:** máximo ~2MB recomendado para evitar `TransactionTooLargeException`. Si el widget es grande (2×2 celdas = ~320×320dp), el bitmap puede ser de 480×480px a densidad hdpi sin problema.

---

## 18. Estructura de archivos resultante

```
lib/
  services/
    image_widget_service.dart            [NUEVO]
  widgets/
    image_widget_preview.dart            [NUEVO]
  screens/
    emisor/
      image_widget_editor_screen.dart    [NUEVO]
      settings_screen.dart               [MODIFICADO — añadir tile]
  main.dart                              [MODIFICADO — añadir ruta]

android/app/src/main/
  kotlin/com/example/connect/
    ImageSlideShowWidgetProvider.kt      [NUEVO]
    MainActivity.kt                      [MODIFICADO — 2 nuevos cases]
  res/
    layout/
      widget_image_slideshow.xml         [NUEVO]
    xml/
      image_slideshow_widget_info.xml    [NUEVO]
  AndroidManifest.xml                    [MODIFICADO — permiso + receiver]
```

Total: **3 archivos nuevos Flutter, 3 archivos nuevos Android, 3 archivos Android/Flutter modificados**.
