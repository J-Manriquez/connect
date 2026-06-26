import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Información de una actualización disponible (APK de Android).
class UpdateInfo {
  final String version;
  final String assetApiUrl;
  final String assetName;
  UpdateInfo({
    required this.version,
    required this.assetApiUrl,
    required this.assetName,
  });
}

/// Servicio de auto-actualización vía GitHub Releases. Solo para Android:
/// descarga el `.apk` publicado como asset del release de mayor versión y lo
/// abre con el instalador del sistema.
class UpdateService {
  static const String _owner = 'J-Manriquez';
  static const String _repo = 'connect';
  static const Duration _timeout = Duration(seconds: 10);

  static const MethodChannel _abiChannel =
      MethodChannel('com.example.connect/floating_ball');

  static String get _token => dotenv.env['GITHUB_UPDATE_TOKEN'] ?? '';

  /// ABIs soportadas por el dispositivo en orden de preferencia
  /// (Build.SUPPORTED_ABIS). Vacío si falla.
  static Future<List<String>> _deviceAbis() async {
    try {
      final abis = await _abiChannel.invokeListMethod<String>('getDeviceAbis');
      return abis ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// Elige el APK adecuado para la arquitectura del dispositivo cuando el
  /// release trae varios (compilados con `flutter build apk --split-per-abi`).
  /// El match es por substring de la ABI en el nombre del asset
  /// (p. ej. `...armeabi-v7a...apk`). Si solo hay un APK, lo usa tal cual.
  static Future<Map<String, dynamic>?> _pickApkForDevice(
      List<Map<String, dynamic>> apkAssets) async {
    if (apkAssets.length == 1) return apkAssets.first;

    String nameOf(Map<String, dynamic> a) =>
        (a['name'] as String? ?? '').toLowerCase();

    // 1) Match por ABL del dispositivo, en orden de preferencia.
    final abis = await _deviceAbis();
    for (final abi in abis) {
      final token = abi.toLowerCase();
      for (final a in apkAssets) {
        if (nameOf(a).contains(token)) return a;
      }
    }

    // 2) Sin match: preferir un APK universal/fat si existe.
    for (final a in apkAssets) {
      if (nameOf(a).contains('universal')) return a;
    }
    // 3) Último recurso: un APK que no nombre ninguna ABI conocida
    //    (suele ser el universal) o, si no, el primero.
    const known = ['armeabi-v7a', 'arm64-v8a', 'x86_64', 'x86', 'armeabi'];
    for (final a in apkAssets) {
      final n = nameOf(a);
      if (!known.any((k) => n.contains(k))) return a;
    }
    return apkAssets.first;
  }

  static Future<UpdateInfo?> checkForUpdate() async {
    // Solo Android; en cualquier otra plataforma no hay actualización gestionada.
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    if (_token.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/$_owner/$_repo/releases?per_page=100',
        ),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/vnd.github+json',
        },
      ).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final List<dynamic> releases = jsonDecode(response.body) as List<dynamic>;
      Map<String, dynamic>? mejor;
      String mejorVersion = '';
      for (final r in releases.cast<Map<String, dynamic>>()) {
        if (r['draft'] == true || r['prerelease'] == true) continue;
        final String tag = (r['tag_name'] as String?) ?? '';
        final String version = tag.startsWith('v') ? tag.substring(1) : tag;
        if (mejor == null || _esVersionMasNueva(version, mejorVersion)) {
          mejor = r;
          mejorVersion = version;
        }
      }
      if (mejor == null) return null;

      final info = await PackageInfo.fromPlatform();
      if (!_esVersionMasNueva(mejorVersion, info.version)) return null;

      final List<dynamic> assets = (mejor['assets'] as List?) ?? [];
      final apkAssets = assets
          .cast<Map<String, dynamic>>()
          .where((a) =>
              (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'))
          .toList();
      if (apkAssets.isEmpty) return null;

      final asset = await _pickApkForDevice(apkAssets);
      if (asset == null || asset.isEmpty) return null;

      return UpdateInfo(
        version: mejorVersion,
        assetApiUrl: asset['url'] as String,
        assetName: asset['name'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  /// Compara "X.Y.Z". true si [remota] > [actual].
  static bool _esVersionMasNueva(String remota, String actual) {
    List<int> parse(String v) =>
        v.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final r = parse(remota), a = parse(actual);
    final n = r.length > a.length ? r.length : a.length;
    for (var i = 0; i < n; i++) {
      final rv = i < r.length ? r[i] : 0;
      final av = i < a.length ? a[i] : 0;
      if (rv != av) return rv > av;
    }
    return false;
  }

  static Future<File> downloadAsset(
      UpdateInfo info, void Function(double) onProgress) async {
    final request = http.Request('GET', Uri.parse(info.assetApiUrl));
    request.headers['Authorization'] = 'Bearer $_token';
    request.headers['Accept'] = 'application/octet-stream'; // descarga binaria
    final resp = await http.Client().send(request);
    if (resp.statusCode != 200) {
      throw Exception('Descarga falló: ${resp.statusCode}');
    }
    final int total = resp.contentLength ?? 0;
    int recibido = 0;
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${info.assetName}');
    final sink = file.openWrite();
    await resp.stream.listen((chunk) {
      recibido += chunk.length;
      sink.add(chunk);
      if (total > 0) onProgress(recibido / total);
    }).asFuture<void>();
    await sink.close();
    return file;
  }

  /// Abre el APK con el instalador del sistema. Requiere que el usuario tenga
  /// concedido el permiso "Instalar apps desconocidas" para esta app.
  static Future<void> installAndroid(File apk) async {
    await OpenFilex.open(apk.path);
  }
}
