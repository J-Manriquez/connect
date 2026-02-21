import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/models/device_data.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaReproductionScreen extends StatefulWidget {
  const MediaReproductionScreen({super.key});

  @override
  State<MediaReproductionScreen> createState() =>
      _MediaReproductionScreenState();
}

class _MediaReproductionScreenState extends State<MediaReproductionScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final String _prefsKey = 'media_default_app_package';

  bool _isLoading = true;
  String? _error;
  List<AppData> _apps = [];
  String? _selectedPackage;
  final Map<String, Map<String, dynamic>> _metaByPkg = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedPackage = prefs.getString(_prefsKey);

      await BtHiveStorageService.ensureInitialized();
      final hivePackage = await BtHiveStorageService.getDefaultMediaAppPackage();

      final deviceId = await _firebaseService.getDeviceId();
      String? firebasePackage;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('dispositivos')
            .doc(deviceId)
            .get();
        final raw = (doc.data()?['media_default_app_package'] ?? '')
            .toString()
            .trim();
        firebasePackage = raw.isEmpty ? null : raw;
      } catch (_) {}

      final List<AppData> apps = await _firebaseService.getAppList();
      final Map<String, Map<String, dynamic>> meta = {};
      for (final app in apps) {
        final m = await BtHiveStorageService.getAppMeta(app.packageName);
        if (m != null) meta[app.packageName] = m;
      }

      setState(() {
        _apps = apps;
        _metaByPkg
          ..clear()
          ..addAll(meta);
        _selectedPackage = storedPackage?.trim().isNotEmpty == true
            ? storedPackage!.trim()
            : hivePackage?.trim().isNotEmpty == true
                ? hivePackage!.trim()
                : firebasePackage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar aplicaciones: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSelectedApp(String? packageName) async {
    setState(() {
      _selectedPackage = packageName;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      if (packageName == null || packageName.isEmpty) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, packageName);
      }

      await BtHiveStorageService.setDefaultMediaAppPackage(packageName ?? '');

      final deviceId = await _firebaseService.getDeviceId();
      final docRef = FirebaseFirestore.instance
          .collection('dispositivos')
          .doc(deviceId);

      await docRef.set({
        'media_default_app_package': packageName ?? '',
        'ultima-actualizacion': FieldValue.arrayUnion([
          {
            'fecha': Timestamp.now(),
            'tipo-actualizacion': 'media-default-app',
          },
        ]),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reproducción multimedia'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _apps.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No hay aplicaciones disponibles. Activa el guardado en Firebase y sincroniza la lista de aplicaciones.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _apps.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, thickness: 1),
                      itemBuilder: (context, index) {
                        final app = _apps[index];
                        final isSelected = app.packageName == _selectedPackage;
                        final meta = _metaByPkg[app.packageName];
                        final iconBase64 =
                            (meta?['icon'] ?? '').toString().trim();
                        return ListTile(
                          leading: iconBase64.isEmpty
                              ? const CircleAvatar(child: Icon(Icons.apps))
                              : CircleAvatar(
                                  backgroundColor: Colors.transparent,
                                  child: Image.memory(
                                    UriData.parse('data:image/png;base64,$iconBase64')
                                        .contentAsBytes(),
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.apps),
                                  ),
                                ),
                          title: Text(app.nombre),
                          subtitle: Text(app.packageName),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (_) =>
                                _saveSelectedApp(app.packageName),
                          ),
                          onTap: () => _saveSelectedApp(app.packageName),
                        );
                      },
                    ),
    );
  }
}
