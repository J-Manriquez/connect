import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:connect/models/weather_models.dart';
import 'package:connect/services/weather_service.dart';
import 'package:connect/services/weather_store.dart';
import 'package:connect/services/weather_widget_config_service.dart';
import 'package:connect/widgets/weather_background.dart';

/// Widget de clima dinámico para mostrar dentro de la app.
///
/// Es deslizable horizontalmente: cada página muestra distinta información de la
/// ciudad seleccionada:
///   1. Clima actual
///   2. Pronóstico por horas (próximas 24 h, lista vertical)
///   3. Pronóstico por días (7 días)
///
/// Lee los datos del [WeatherStore] (caché local) y el estilo de
/// [WeatherWidgetConfigService] (totalmente personalizable, ver
/// `WeatherWidgetEditorScreen`). Solo va a la red cuando no hay caché o cuando
/// el usuario pulsa refrescar. Al tocar el nombre de la ciudad se abre un menú
/// con las demás ciudades guardadas.
class WeatherWidget extends StatefulWidget {
  /// Callback para abrir la pantalla de configuración desde el estado vacío.
  final VoidCallback? onConfigure;

  const WeatherWidget({super.key, this.onConfigure});

  @override
  State<WeatherWidget> createState() => WeatherWidgetState();
}

class WeatherWidgetState extends State<WeatherWidget> {
  final PageController _pageController = PageController();
  int _page = 0;

  // Estado del modo test del editor: cuando no es null, el fondo usa estos
  // valores en lugar del clima real, permitiendo previsualizar la animación.
  int? _testWeatherCode;
  bool _testIsDay = true;
  double? _testOverrideT;

  /// Actualiza el fondo del preview para el modo test del editor.
  /// Pasar [weatherCode] = null desactiva el modo test.
  void setTestBackground(int? weatherCode, bool isDay, double? t) {
    setState(() {
      _testWeatherCode = weatherCode;
      _testIsDay = isDay;
      _testOverrideT = t;
    });
  }

  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  // Categoría debug activa ('clear','clouds',etc.) o '' si usa clima real.
  String _debugCategory = '';
  bool _debugIsDay = true;
  WeatherData? _data;
  WeatherCity? _selected;
  List<WeatherCity> _cities = const [];
  WeatherWidgetConfig? _cfg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Recarga pública (la usa la pantalla de configuración tras cambiar ciudad
  /// o tras editar el estilo del widget).
  Future<void> reload() => _load();

  /// Carga desde el caché. Si la ciudad seleccionada no tiene datos en caché,
  /// hace una primera descarga automática.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final cfg = await WeatherWidgetConfigService.load();
    final cities = await WeatherStore.getSavedCities();
    final selected = await WeatherStore.getSelectedCity();
    final debugCat = cfg.animDebugCategory;
    final debugDay = cfg.animDebugIsDay;

    if (selected == null) {
      if (!mounted) return;
      setState(() {
        _cfg = cfg;
        _cities = cities;
        _selected = null;
        _data = null;
        _debugCategory = debugCat;
        _debugIsDay = debugDay;
        _loading = false;
      });
      return;
    }

    final cached = await WeatherStore.getCachedWeather(selected);
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _cfg = cfg;
        _cities = cities;
        _selected = selected;
        _data = cached;
        _debugCategory = debugCat;
        _debugIsDay = debugDay;
        _loading = false;
      });
      // Refresca silenciosamente en segundo plano para mantener el widget
      // nativo actualizado y evitar mostrar datos del día anterior.
      _silentRefresh(selected);
      return;
    }

    // No hay caché todavía: primera descarga.
    try {
      final data = await WeatherStore.refreshWeather(selected);
      if (!mounted) return;
      setState(() {
        _cfg = cfg;
        _cities = cities;
        _selected = selected;
        _data = data;
        _debugCategory = debugCat;
        _debugIsDay = debugDay;
        _loading = false;
      });
    } on WeatherException catch (e) {
      if (!mounted) return;
      setState(() {
        _cfg = cfg;
        _cities = cities;
        _selected = selected;
        _error = e.message;
        _debugCategory = debugCat;
        _debugIsDay = debugDay;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cfg = cfg;
        _cities = cities;
        _selected = selected;
        _error = 'Ocurrió un error al cargar el clima.';
        _debugCategory = debugCat;
        _debugIsDay = debugDay;
        _loading = false;
      });
    }
  }

  /// Refresca desde la red sin spinner. Si falla, los datos del caché siguen visibles.
  Future<void> _silentRefresh(WeatherCity city) async {
    try {
      final data = await WeatherStore.refreshWeather(city);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (_) {
      // Fallo silencioso: el caché sigue mostrándose.
    }
  }

  /// Refresca desde la red la ciudad seleccionada (borra y reescribe el caché).
  /// Si hay debug activo lo limpia primero para volver al clima real.
  Future<void> _refresh() async {
    final selected = _selected;
    if (selected == null || _refreshing) return;
    if (_debugCategory.isNotEmpty) {
      await WeatherWidgetConfigService.clearDebugCategory();
      setState(() => _debugCategory = '');
    }
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final data = await WeatherStore.refreshWeather(selected);
      if (!mounted) return;
      setState(() {
        _data = data;
        _refreshing = false;
      });
    } on WeatherException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Ocurrió un error al actualizar.';
        _refreshing = false;
      });
    }
  }

  Future<void> _switchCity(WeatherCity city) async {
    await WeatherStore.setSelectedCity(city);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg;
    final radius = (cfg?.cornerRadiusDp ?? WeatherWidgetConfigService.defCornerRadiusDp)
        .toDouble();
    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: _buildBackground(cfg)),
          _buildContent(cfg),
        ],
      ),
    );
  }

  /// Mezcla [c] hacia negro en un [pct]% (0-100). Misma idea que el oscurecido
  /// estático del lado nativo, para que ambos coincidan.
  Color _darken(Color c, int pct) =>
      Color.lerp(c, Colors.black, (pct.clamp(0, 100)) / 100.0)!;

  /// Fondo del widget: animado/dinámico según el clima, o un degradado
  /// sólido/personalizado si así lo configuró el usuario.
  Widget _buildBackground(WeatherWidgetConfig? cfg) {
    final data = _data;
    final darken = cfg?.bgDarkenPct ?? 0;

    if (cfg != null && cfg.bgMode == WeatherBgMode.solid) {
      final color = _darken(Color(cfg.bgSolidArgb), darken);
      return DecoratedBox(decoration: BoxDecoration(color: color));
    }

    if (cfg != null && cfg.bgMode == WeatherBgMode.gradient) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _darken(Color(cfg.bgGradientTopArgb), darken),
              _darken(Color(cfg.bgGradientBottomArgb), darken),
            ],
          ),
        ),
      );
    }

    // Modo dinámico (por defecto): según el clima real (o debug), animado o estático.
    // Si hay categoría de debug activa, la usamos en lugar del clima real.
    final debugCode = _debugCategory.isNotEmpty
        ? _categoryToCode(_debugCategory)
        : null;
    final effectiveCode = debugCode ?? data?.current.weatherCode;
    final effectiveIsDay = debugCode != null ? _debugIsDay : (data?.current.isDay ?? true);
    final effectiveWind = debugCode != null ? 0.0 : (data?.current.windSpeed ?? 0.0);

    if (effectiveCode == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A6FA5), Color(0xFF2C3E73)],
          ),
        ),
      );
    }

    final animated = cfg?.animatedBgEnabled ??
        WeatherWidgetConfigService.defAnimatedBgEnabled;
    if (!animated) {
      final colors = WeatherCodeInfo.gradientColors(
        effectiveCode,
        isDay: effectiveIsDay,
      );
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_darken(colors[0], darken), _darken(colors[1], darken)],
          ),
        ),
      );
    }

    // Modo test del editor: usar weather y t overrides si están activos.
    final testCode = _testWeatherCode;
    if (testCode != null) {
      return WeatherBackground(
        weatherCode: testCode,
        isDay: _testIsDay,
        darkenPct: darken,
        overrideT: _testOverrideT,
      );
    }

    return WeatherBackground(
      weatherCode: effectiveCode,
      isDay: effectiveIsDay,
      windSpeed: effectiveWind,
      darkenPct: darken,
    );
  }

  /// Devuelve un código de clima representativo para cada categoría de debug.
  static int _categoryToCode(String category) => switch (category) {
    'clear'   => 0,
    'clouds'  => 3,
    'fog'     => 45,
    'rain'    => 61,
    'snow'    => 71,
    'thunder' => 95,
    _         => 0,
  };

  Widget _buildContent(WeatherWidgetConfig? cfg) {
    if (_loading || cfg == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_selected == null) {
      return _buildEmptyState();
    }
    final data = _data;
    if (data == null) {
      return _buildErrorState();
    }
    return _buildPages(data, cfg);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off, color: Colors.white70, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Sin ciudad seleccionada',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (widget.onConfigure != null)
            FilledButton.tonalIcon(
              onPressed: widget.onConfigure,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Elegir ciudad'),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, color: Colors.white70, size: 48),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _error ?? 'No se pudo cargar el clima.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildPages(WeatherData data, WeatherWidgetConfig cfg) {
    final debugCode = _debugCategory.isNotEmpty
        ? _categoryToCode(_debugCategory)
        : null;
    final debugIsDay = _debugCategory.isNotEmpty ? _debugIsDay : null;
    return Column(
      children: [
        _buildHeader(data, cfg),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _error!,
              style:
                  const TextStyle(color: Colors.amberAccent, fontSize: 11),
            ),
          ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              _CurrentPage(data: data, cfg: cfg,
                  debugCode: debugCode, debugIsDay: debugIsDay),
              _HourlyPage(data: data, cfg: cfg),
              _DailyPage(data: data, cfg: cfg),
            ],
          ),
        ),
        _buildFooter(cfg),
      ],
    );
  }

  Widget _buildHeader(WeatherData data, WeatherWidgetConfig cfg) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
      child: Row(
        children: [
          if (cfg.showLocationPin) ...[
            const Icon(Icons.location_on, color: Colors.white, size: 18),
            const SizedBox(width: 2),
          ],
          // Nombre de ciudad: toca para abrir el menú de ciudades guardadas.
          Flexible(
            child: _buildCityDropdown(data, cfg),
          ),
          const Spacer(),
          Text(
            ['Ahora', 'Por horas', 'Por días'][_page],
            style: TextStyle(
              color: Color(cfg.viewLabelColorArgb),
              fontSize: cfg.viewLabelSizeSp.toDouble(),
            ),
          ),
          IconButton(
            onPressed: _refreshing ? null : _refresh,
            visualDensity: VisualDensity.compact,
            icon: _refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildCityDropdown(WeatherData data, WeatherWidgetConfig cfg) {
    final style = TextStyle(
      color: Color(cfg.cityLabelColorArgb),
      fontSize: cfg.cityLabelSizeSp.toDouble(),
      fontWeight: cfg.cityLabelBold ? FontWeight.w600 : FontWeight.normal,
    );
    // Si solo hay una ciudad, no hay nada que elegir: muestra el nombre plano.
    if (_cities.length <= 1) {
      return Text(
        data.city.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return PopupMenuButton<WeatherCity>(
      tooltip: 'Cambiar ciudad',
      onSelected: _switchCity,
      itemBuilder: (context) => _cities
          .map(
            (c) => PopupMenuItem<WeatherCity>(
              value: c,
              child: Row(
                children: [
                  if (WeatherStore.cityKey(c) ==
                      WeatherStore.cityKey(_selected!))
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Flexible(child: Text(c.name)),
                ],
              ),
            ),
          )
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              data.city.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
        ],
      ),
    );
  }

  Widget _buildFooter(WeatherWidgetConfig cfg) {
    final dotSize = cfg.dotSizeDp.toDouble();
    final arrowSize = cfg.arrowSizeSp.toDouble();
    final arrowColor = Color(cfg.arrowColorArgb);
    final dimColor = arrowColor.withValues(alpha: 0.25);

    final dots = List.generate(3, (i) {
      final active = i == _page;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: active ? dotSize * 3 : dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          color: active
              ? Color(cfg.dotActiveColorArgb)
              : Color(cfg.dotInactiveColorArgb),
          borderRadius: BorderRadius.circular(dotSize / 2),
        ),
      );
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _page > 0
                ? () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: _arrowWidget(
                pngB64: cfg.arrowPrevPng,
                label: '◀',
                color: _page > 0 ? arrowColor : dimColor,
                sizeSp: arrowSize,
              ),
            ),
          ),
          ...dots,
          GestureDetector(
            onTap: _page < 2
                ? () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: _arrowWidget(
                pngB64: cfg.arrowNextPng,
                label: '▶',
                color: _page < 2 ? arrowColor : dimColor,
                sizeSp: arrowSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Página 1: clima actual.
class _CurrentPage extends StatelessWidget {
  final WeatherData data;
  final WeatherWidgetConfig cfg;
  /// Si hay categoría debug activa, sobreescribe el icono (pero no los datos).
  final int? debugCode;
  final bool? debugIsDay;
  const _CurrentPage({
    required this.data,
    required this.cfg,
    this.debugCode,
    this.debugIsDay,
  });

  @override
  Widget build(BuildContext context) {
    final c = data.current;
    final info = WeatherCodeInfo.from(c.weatherCode, isDay: c.isDay);
    // El icono usa la categoría debug si está activa; los datos reales siempre.
    final iconCode = debugCode ?? c.weatherCode;
    final iconIsDay = debugIsDay ?? c.isDay;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${c.temperature.round()}°',
                style: TextStyle(
                  color: Color(cfg.tempColorArgb),
                  fontSize: cfg.tempSizeSp.toDouble(),
                  fontWeight:
                      cfg.tempBold ? FontWeight.bold : FontWeight.w300,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                info.description,
                style: TextStyle(
                  color: Color(cfg.descColorArgb),
                  fontSize: cfg.descSizeSp.toDouble(),
                ),
              ),
              Text(
                'Sensación ${c.apparentTemperature.round()}°',
                style: TextStyle(
                  color: Color(cfg.apparentColorArgb),
                  fontSize: cfg.apparentSizeSp.toDouble(),
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _weatherIconWidget(cfg, iconCode, iconIsDay, cfg.emojiSizeSp.toDouble()),
              const SizedBox(height: 12),
              _MiniStat(
                icon: Icons.water_drop,
                label: '${c.humidity}%',
                sizeSp: cfg.statSizeSp,
                colorArgb: cfg.statColorArgb,
              ),
              const SizedBox(height: 6),
              _MiniStat(
                icon: Icons.air,
                label: '${c.windSpeed.round()} km/h',
                sizeSp: cfg.statSizeSp,
                colorArgb: cfg.statColorArgb,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===== Helpers de icono custom =============================================

/// Devuelve el PNG base64 guardado para la categoría climática, o null.
String? _iconPngForCategory(WeatherWidgetConfig cfg, String category, bool isDay) {
  return switch (category) {
    'clear' => isDay ? cfg.iconClearDayPng : cfg.iconClearNightPng,
    'clouds' => cfg.iconCloudsPng,
    'fog' => cfg.iconFogPng,
    'rain' => cfg.iconRainPng,
    'snow' => cfg.iconSnowPng,
    'thunder' => cfg.iconThunderPng,
    _ => null,
  };
}

/// Renderiza el icono del clima: PNG custom si está disponible, icono Flutter si no.
Widget _weatherIconWidget(WeatherWidgetConfig cfg, int code, bool isDay, double size) {
  final category = WeatherCodeInfo.category(code);
  final pngB64 = _iconPngForCategory(cfg, category, isDay);
  if (pngB64 != null && pngB64.isNotEmpty) {
    try {
      final bytes = base64Decode(pngB64.replaceAll(RegExp(r'\s+'), ''));
      return SizedBox.square(
        dimension: size,
        child: Image.memory(bytes, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _defaultWeatherIcon(code, isDay, size)),
      );
    } catch (_) {}
  }
  return _defaultWeatherIcon(code, isDay, size);
}

Widget _defaultWeatherIcon(int code, bool isDay, double size) {
  final info = WeatherCodeInfo.from(code, isDay: isDay);
  return Icon(info.icon, color: Colors.white, size: size);
}

/// Renderiza una flecha de navegación: PNG custom si existe, texto si no.
/// [label] es el carácter fallback ('◀', '▶', '▲', '▼').
Widget _arrowWidget({
  required String? pngB64,
  required String label,
  required Color color,
  required double sizeSp,
}) {
  if (pngB64 != null && pngB64.isNotEmpty) {
    try {
      final bytes = base64Decode(pngB64.replaceAll(RegExp(r'\s+'), ''));
      return SizedBox.square(
        dimension: sizeSp,
        child: Image.memory(bytes, fit: BoxFit.contain,
            color: color,
            colorBlendMode: BlendMode.srcIn,
            errorBuilder: (_, __, ___) =>
                Text(label, style: TextStyle(color: color, fontSize: sizeSp))),
      );
    } catch (_) {}
  }
  return Text(label, style: TextStyle(color: color, fontSize: sizeSp));
}

// ===== Página 2: por horas ================================================

/// Pronóstico por horas con flechas ▲▼ para desplazar la lista.
class _HourlyPage extends StatefulWidget {
  final WeatherData data;
  final WeatherWidgetConfig cfg;
  const _HourlyPage({required this.data, required this.cfg});

  @override
  State<_HourlyPage> createState() => _HourlyPageState();
}

class _HourlyPageState extends State<_HourlyPage> {
  final ScrollController _scroll = ScrollController();
  bool _canUp = false;
  bool _canDown = true;
  static const _step = 58.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final canUp = _scroll.offset > 0;
    final canDown = _scroll.offset < _scroll.position.maxScrollExtent;
    if (canUp != _canUp || canDown != _canDown) {
      setState(() { _canUp = canUp; _canDown = canDown; });
    }
  }

  void _up() => _scroll.animateTo(
        (_scroll.offset - _step).clamp(0, double.infinity),
        duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);

  void _down() => _scroll.animateTo(
        _scroll.offset + _step,
        duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);

  @override
  Widget build(BuildContext context) {
    final cfg = widget.cfg;
    if (widget.data.hourly.isEmpty) {
      return const Center(child: Text('Sin datos por horas', style: TextStyle(color: Colors.white70)));
    }
    final items = widget.data.hourly.take(12).toList();
    final arrowColor = Color(cfg.arrowColorArgb);
    final dim = arrowColor.withValues(alpha: 0.25);
    final arrowSz = cfg.scrollArrowSizeSp.toDouble();

    return Row(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final h = items[i];
              final isDay = h.time.hour >= 7 && h.time.hour < 20;
              return Padding(
                padding: EdgeInsets.symmetric(vertical: cfg.rowSpacingDp.toDouble()),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(_hourLabel(h.time),
                          style: TextStyle(color: Color(cfg.rowLabelColorArgb),
                              fontSize: cfg.rowLabelSizeSp.toDouble())),
                    ),
                    _weatherIconWidget(cfg, h.weatherCode, isDay, cfg.rowEmojiSizeSp.toDouble()),
                    const SizedBox(width: 8),
                    if (h.precipitationProbability > 0)
                      SizedBox(
                        width: 46,
                        child: Row(children: [
                          Icon(Icons.water_drop, color: Color(cfg.rowPpColorArgb), size: cfg.rowPpSizeSp.toDouble()),
                          const SizedBox(width: 2),
                          Text('${h.precipitationProbability}%',
                              style: TextStyle(color: Color(cfg.rowPpColorArgb), fontSize: cfg.rowPpSizeSp.toDouble())),
                        ]),
                      )
                    else
                      const SizedBox(width: 46),
                    const Spacer(),
                    Text('${h.temperature.round()}°',
                        style: TextStyle(
                          color: Color(cfg.rowValueColorArgb),
                          fontSize: cfg.rowValueSizeSp.toDouble(),
                          fontWeight: cfg.rowValueBold ? FontWeight.w600 : FontWeight.normal,
                        )),
                  ],
                ),
              );
            },
          ),
        ),
        // Flechas ▲▼
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _canUp ? _up : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                child: _arrowWidget(
                  pngB64: cfg.arrowUpPng,
                  label: '▲',
                  color: _canUp ? arrowColor : dim,
                  sizeSp: arrowSz,
                ),
              ),
            ),
            GestureDetector(
              onTap: _canDown ? _down : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                child: _arrowWidget(
                  pngB64: cfg.arrowDownPng,
                  label: '▼',
                  color: _canDown ? arrowColor : dim,
                  sizeSp: arrowSz,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _hourLabel(DateTime t) {
    final now = DateTime.now();
    if (t.hour == now.hour && t.day == now.day) return 'Ahora';
    return '${t.hour.toString().padLeft(2, '0')}:00';
  }
}

// ===== Página 3: por días =================================================

/// Pronóstico por días con flechas ▲▼ para desplazar la lista.
class _DailyPage extends StatefulWidget {
  final WeatherData data;
  final WeatherWidgetConfig cfg;
  const _DailyPage({required this.data, required this.cfg});

  @override
  State<_DailyPage> createState() => _DailyPageState();
}

class _DailyPageState extends State<_DailyPage> {
  final ScrollController _scroll = ScrollController();
  bool _canUp = false;
  bool _canDown = true;
  static const _step = 58.0;

  static const _days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final canUp = _scroll.offset > 0;
    final canDown = _scroll.offset < _scroll.position.maxScrollExtent;
    if (canUp != _canUp || canDown != _canDown) {
      setState(() { _canUp = canUp; _canDown = canDown; });
    }
  }

  void _up() => _scroll.animateTo(
        (_scroll.offset - _step).clamp(0, double.infinity),
        duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);

  void _down() => _scroll.animateTo(
        _scroll.offset + _step,
        duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);

  @override
  Widget build(BuildContext context) {
    final cfg = widget.cfg;
    if (widget.data.daily.isEmpty) {
      return const Center(child: Text('Sin datos por días', style: TextStyle(color: Colors.white70)));
    }
    final arrowColor = Color(cfg.arrowColorArgb);
    final dim = arrowColor.withValues(alpha: 0.25);
    final arrowSz = cfg.scrollArrowSizeSp.toDouble();

    return Row(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            itemCount: widget.data.daily.length,
            itemBuilder: (context, i) {
              final d = widget.data.daily[i];
              return Padding(
                padding: EdgeInsets.symmetric(vertical: cfg.rowSpacingDp.toDouble()),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        i == 0 ? 'Hoy' : _days[(d.date.weekday - 1) % 7],
                        style: TextStyle(color: Color(cfg.rowLabelColorArgb),
                            fontSize: cfg.rowLabelSizeSp.toDouble()),
                      ),
                    ),
                    _weatherIconWidget(cfg, d.weatherCode, true, cfg.rowEmojiSizeSp.toDouble()),
                    const SizedBox(width: 6),
                    if (d.precipitationProbability > 0)
                      SizedBox(
                        width: 42,
                        child: Row(children: [
                          Icon(Icons.water_drop, color: Color(cfg.rowPpColorArgb), size: cfg.rowPpSizeSp.toDouble()),
                          const SizedBox(width: 2),
                          Text('${d.precipitationProbability}%',
                              style: TextStyle(color: Color(cfg.rowPpColorArgb), fontSize: cfg.rowPpSizeSp.toDouble())),
                        ]),
                      )
                    else
                      const SizedBox(width: 42),
                    const Spacer(),
                    Text('${d.tempMin.round()}°',
                        style: TextStyle(
                          color: Color(cfg.rowLabelColorArgb).withValues(alpha: 0.7),
                          fontSize: cfg.rowLabelSizeSp.toDouble(),
                        )),
                    const SizedBox(width: 8),
                    Text('${d.tempMax.round()}°',
                        style: TextStyle(
                          color: Color(cfg.rowValueColorArgb),
                          fontSize: cfg.rowValueSizeSp.toDouble(),
                          fontWeight: cfg.rowValueBold ? FontWeight.w600 : FontWeight.normal,
                        )),
                  ],
                ),
              );
            },
          ),
        ),
        // Flechas ▲▼
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _canUp ? _up : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                child: _arrowWidget(
                  pngB64: cfg.arrowUpPng,
                  label: '▲',
                  color: _canUp ? arrowColor : dim,
                  sizeSp: arrowSz,
                ),
              ),
            ),
            GestureDetector(
              onTap: _canDown ? _down : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                child: _arrowWidget(
                  pngB64: cfg.arrowDownPng,
                  label: '▼',
                  color: _canDown ? arrowColor : dim,
                  sizeSp: arrowSz,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int sizeSp;
  final int colorArgb;
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.sizeSp,
    required this.colorArgb,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Color(colorArgb), size: sizeSp.toDouble() + 3),
        const SizedBox(width: 4),
        Text(label,
            style:
                TextStyle(color: Color(colorArgb), fontSize: sizeSp.toDouble())),
      ],
    );
  }
}
