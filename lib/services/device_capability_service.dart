import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceCapabilityService {
  DeviceCapabilityService._();
  static final DeviceCapabilityService instance = DeviceCapabilityService._();

  static const _channel = MethodChannel('com.example.connect/floating_ball');

  bool? _supportsLocalAi;

  /// Devuelve true si el dispositivo tiene soporte arm64-v8a (requerido por flutter_gemma).
  /// El resultado se cachea tras la primera llamada.
  Future<bool> supportsLocalAi() async {
    if (_supportsLocalAi != null) return _supportsLocalAi!;

    // En plataformas no-Android (desktop, web) no hay restricción de ABI.
    if (!defaultTargetPlatform.name.contains('android') &&
        defaultTargetPlatform != TargetPlatform.android) {
      _supportsLocalAi = false;
      return false;
    }

    try {
      final abis = await _channel
              .invokeListMethod<String>('getDeviceAbis')
              .timeout(const Duration(seconds: 2), onTimeout: () => <String>[]) ??
          [];
      debugPrint('[DeviceCapability] ABIs soportadas: $abis');
      _supportsLocalAi = abis.any((a) => a == 'arm64-v8a' || a == 'x86_64');
    } catch (e) {
      debugPrint('[DeviceCapability] Error obteniendo ABIs: $e — asumiendo no soportado');
      _supportsLocalAi = false;
    }

    debugPrint('[DeviceCapability] supportsLocalAi=$_supportsLocalAi');
    return _supportsLocalAi!;
  }

  /// Reinicia el caché (útil en tests).
  void reset() => _supportsLocalAi = null;
}
