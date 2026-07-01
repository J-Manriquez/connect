import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/models/device_data.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/ble_service.dart';
import 'package:connect/services/preferences_service.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaReproductionScreen extends StatefulWidget {
  final bool useLinkedDevice;

  const MediaReproductionScreen({
    super.key,
    this.useLinkedDevice = false,
  });

  @override
  State<MediaReproductionScreen> createState() =>
      _MediaReproductionScreenState();
}

class _MediaReproductionScreenState extends State<MediaReproductionScreen> {
  static const MethodChannel _appListChannel =
      MethodChannel('com.example.connect/app_list');
  final FirebaseService _firebaseService = FirebaseService();
  final ReceptorService _receptorService = ReceptorService();
  final String _prefsKey = 'media_default_app_package';
  final String _prefsIconKey = 'media_default_app_icon_base64';
  final String _prefsInstalledKey = 'media_default_app_installed';
  final String _prefsInstalledPkgKey = 'media_default_app_installed_pkg';

  bool _isLoading = true;
  String? _error;
  List<AppData> _apps = [];
  String? _selectedPackage;
  final Map<String, Map<String, dynamic>> _metaByPkg = {};
  bool _prioritizeLocalMedia = false;
  String? _defaultAppIconBase64FromPrefs;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<String?> _resolveNativeAppIconBase64(String packageName) async {
    try {
      final pkg = packageName.trim();
      if (pkg.isEmpty) return null;
      print('[media_reproduction] resolveNativeAppIconBase64 pkg="$pkg"');
      final res = await _appListChannel.invokeMethod(
        'searchAppByPackage',
        <String, dynamic>{'packageName': pkg},
      );
      final map = res is Map ? Map<String, dynamic>.from(res) : null;
      final icon = (map?['icon'] ?? '').toString().trim();
      print('[media_reproduction] resolveNativeAppIconBase64 got iconLen=${icon.length}');
      if (icon.isEmpty) return null;
      return icon;
    } catch (e) {
      print('[media_reproduction] resolveNativeAppIconBase64 error=$e');
      return null;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await BtHiveStorageService.ensureInitialized();
      _prioritizeLocalMedia = await PreferencesService.getPrioritizeLocalMedia();
      final prefs = await SharedPreferences.getInstance();
      String? storedPackage;
      String? hivePackage;
      if (!widget.useLinkedDevice) {
        storedPackage = prefs.getString(_prefsKey);
        hivePackage = await BtHiveStorageService.getDefaultMediaAppPackage();
      }
      final defaultIcon = prefs.getString(_prefsIconKey);

      final deviceId = widget.useLinkedDevice
          ? await _receptorService.getLinkedDeviceId()
          : await _firebaseService.getDeviceId();
      final targetDeviceId = deviceId?.trim() ?? '';
      if (targetDeviceId.isEmpty) {
        setState(() {
          _error = 'No hay un emisor vinculado.';
          _isLoading = false;
        });
        return;
      }

      String? firebasePackage;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('dispositivos')
            .doc(targetDeviceId)
            .get();
        final raw = (doc.data()?['media_default_app_package'] ?? '')
            .toString()
            .trim();
        firebasePackage = raw.isEmpty ? null : raw;
      } catch (_) {}

      final List<AppData> apps = widget.useLinkedDevice
          ? await _firebaseService.getAppListForDeviceId(targetDeviceId)
          : await _firebaseService.getAppList();
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
        _defaultAppIconBase64FromPrefs =
            defaultIcon?.trim().isEmpty == true ? null : defaultIcon?.trim();
        if (widget.useLinkedDevice) {
          _selectedPackage = firebasePackage;
        } else {
          _selectedPackage = storedPackage?.trim().isNotEmpty == true
              ? storedPackage!.trim()
              : hivePackage?.trim().isNotEmpty == true
                  ? hivePackage!.trim()
                  : firebasePackage;
        }
        _isLoading = false;
      });
      _ensureDefaultIconLoaded();
    } catch (e) {
      setState(() {
        _error = 'Error al cargar aplicaciones: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _ensureDefaultIconLoaded() async {
    try {
      final pkg = _selectedPackage?.trim() ?? '';
      if (pkg.isEmpty) return;
      final hasIcon = (_defaultAppIconBase64FromPrefs?.trim().isNotEmpty == true);
      if (hasIcon) return;
      final native = await _resolveNativeAppIconBase64(pkg);
      if (native == null || native.trim().isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsIconKey, native.trim());
      print('[media_reproduction] ensureDefaultIconLoaded stored iconLen=${native.length} for pkg="$pkg"');
      if (!mounted) return;
      setState(() {
        _defaultAppIconBase64FromPrefs = native.trim();
      });
      try {
        final updated = await BleService.updateWidget();
        print('[media_reproduction] updateWidget after ensureDefaultIconLoaded result=$updated');
      } catch (e) {
        print('[media_reproduction] updateWidget after ensureDefaultIconLoaded error=$e');
      }
    } catch (e) {
      print('[media_reproduction] ensureDefaultIconLoaded error=$e');
    }
  }

  Future<void> _saveSelectedApp(String? packageName) async {
    setState(() {
      _selectedPackage = packageName;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final pkg = packageName?.trim() ?? '';
      print('[media_reproduction] saveSelectedApp pkg="$pkg" useLinkedDevice=${widget.useLinkedDevice}');
      if (pkg.isEmpty) {
        await prefs.remove(_prefsKey);
        await prefs.remove(_prefsIconKey);
        await prefs.remove(_prefsInstalledKey);
        await prefs.remove(_prefsInstalledPkgKey);
        setState(() {
          _defaultAppIconBase64FromPrefs = null;
        });
      } else {
        await prefs.setString(_prefsKey, pkg);
        final meta = _metaByPkg[pkg];
        String iconBase64 = (meta?['icon'] ?? '').toString().trim();
        if (iconBase64.isEmpty) {
          final native = await _resolveNativeAppIconBase64(pkg);
          if (native != null && native.trim().isNotEmpty) {
            iconBase64 = native.trim();
          }
        }
        print('[media_reproduction] saveSelectedApp metaKeys=${meta?.keys.toList() ?? []} iconLen=${iconBase64.length}');
        if (iconBase64.isEmpty) {
          await prefs.remove(_prefsIconKey);
          setState(() {
            _defaultAppIconBase64FromPrefs = null;
          });
        } else {
          await prefs.setString(_prefsIconKey, iconBase64);
          setState(() {
            _defaultAppIconBase64FromPrefs = iconBase64;
          });
        }
        await prefs.setBool(_prefsInstalledKey, true);
        await prefs.setString(_prefsInstalledPkgKey, pkg);
      }

      final targetDeviceId = widget.useLinkedDevice
          ? (await _receptorService.getLinkedDeviceId())?.trim() ?? ''
          : await _firebaseService.getDeviceId();
      if (targetDeviceId.isEmpty) return;

      if (!widget.useLinkedDevice) {
        await BtHiveStorageService.setDefaultMediaAppPackage(packageName ?? '');
      }

      final docRef = FirebaseFirestore.instance
          .collection('dispositivos')
          .doc(targetDeviceId);

      await docRef.set({
        'media_default_app_package': packageName ?? '',
        'ultima-actualizacion': FieldValue.arrayUnion([
          {
            'fecha': Timestamp.now(),
            'tipo-actualizacion': 'media-default-app',
          },
        ]),
      }, SetOptions(merge: true));

      try {
        final updated = await BleService.updateWidget();
        print('[media_reproduction] updateWidget result=$updated');
      } catch (e) {
        print('[media_reproduction] updateWidget error=$e');
      }
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
                      itemCount: _apps.length + 1,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, thickness: 1),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return CheckboxListTile(
                            title: const Text('Priorizar multimedia local'),
                            subtitle: const Text(
                              'Si está activado, los controles también se aplican al contenido multimedia del dispositivo receptor cuando esté reproduciendo.',
                            ),
                            value: _prioritizeLocalMedia,
                            onChanged: (v) async {
                              final next = v == true;
                              setState(() => _prioritizeLocalMedia = next);
                              await PreferencesService.savePrioritizeLocalMedia(next);
                            },
                          );
                        }
                        final app = _apps[index - 1];
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
