import 'dart:async';

import 'package:flutter/material.dart';

import 'package:connect/models/weather_models.dart';
import 'package:connect/screens/emisor/weather_widget_editor_screen.dart';
import 'package:connect/services/weather_service.dart';
import 'package:connect/services/weather_store.dart';
import 'package:connect/theme_colors.dart';
import 'package:connect/widgets/weather_widget.dart';

/// Pantalla de configuración del widget de clima: buscar y agregar ciudades,
/// elegir la ciudad activa, ver la vista previa del widget dinámico y gestionar
/// las ciudades guardadas.
class WeatherSettingsScreen extends StatefulWidget {
  const WeatherSettingsScreen({super.key});

  @override
  State<WeatherSettingsScreen> createState() => _WeatherSettingsScreenState();
}

class _WeatherSettingsScreenState extends State<WeatherSettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<WeatherWidgetState> _previewKey =
      GlobalKey<WeatherWidgetState>();

  Timer? _debounce;
  bool _searching = false;
  List<WeatherCity> _results = const [];

  List<WeatherCity> _savedCities = const [];
  WeatherCity? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final cities = await WeatherStore.getSavedCities();
    final selected = await WeatherStore.getSelectedCity();
    if (!mounted) return;
    setState(() {
      _savedCities = cities;
      _selected = selected;
      _loading = false;
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    final cities = await WeatherService.searchCities(query);
    if (!mounted) return;
    setState(() {
      _results = cities;
      _searching = false;
    });
  }

  Future<void> _addCity(WeatherCity city) async {
    final cities = await WeatherStore.addCity(city);
    if (!mounted) return;
    setState(() {
      _savedCities = cities;
      _selected = city;
      _results = const [];
      _searchController.clear();
    });
    FocusScope.of(context).unfocus();
    _previewKey.currentState?.reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ciudad agregada: ${city.name}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _selectCity(WeatherCity city) async {
    await WeatherStore.setSelectedCity(city);
    if (!mounted) return;
    setState(() => _selected = city);
    _previewKey.currentState?.reload();
  }

  Future<void> _removeCity(WeatherCity city) async {
    final cities = await WeatherStore.removeCity(city);
    final selected = await WeatherStore.getSelectedCity();
    if (!mounted) return;
    setState(() {
      _savedCities = cities;
      _selected = selected;
    });
    _previewKey.currentState?.reload();
  }

  bool _isSaved(WeatherCity city) {
    final key = WeatherStore.cityKey(city);
    return _savedCities.any((c) => WeatherStore.cityKey(c) == key);
  }

  Future<void> _openEditor() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WeatherWidgetEditorScreen(),
      ),
    );
    _previewKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget de clima'),
        backgroundColor: customColor[700],
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Vista previa',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Desliza dentro del widget para ver el clima actual, por horas '
                  'y por días. Toca el nombre de la ciudad para cambiar entre las '
                  'guardadas.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                WeatherWidget(key: _previewKey),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openEditor,
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('Personalizar widget'),
                  ),
                ),
                const SizedBox(height: 8),
                if (_savedCities.isNotEmpty) ...[
                  const Text(
                    'Ciudades guardadas',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ..._savedCities.map(_buildSavedTile),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Agregar ciudad',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Ej: Santiago, Valparaíso, Concepción…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _results = const []);
                                },
                              )
                            : null),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._results.map(_buildResultTile),
                if (_results.isEmpty &&
                    _searchController.text.trim().length >= 2 &&
                    !_searching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Sin resultados. Prueba con otro nombre.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Datos meteorológicos por Open-Meteo.com',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSavedTile(WeatherCity city) {
    final isSelected = _selected != null &&
        WeatherStore.cityKey(_selected!) == WeatherStore.cityKey(city);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSelected ? Colors.green : customColor[400],
        ),
        title: Text(city.name,
            style: TextStyle(
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.normal)),
        subtitle: Text(city.displayName,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Quitar ciudad',
          onPressed: () => _removeCity(city),
        ),
        onTap: () => _selectCity(city),
      ),
    );
  }

  Widget _buildResultTile(WeatherCity city) {
    final saved = _isSaved(city);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          saved ? Icons.check_circle : Icons.add_location_alt_outlined,
          color: saved ? Colors.green : customColor[400],
        ),
        title: Text(city.name),
        subtitle:
            Text(city.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: saved ? const Text('Agregada') : null,
        onTap: saved ? () => _selectCity(city) : () => _addCity(city),
      ),
    );
  }
}
