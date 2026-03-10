import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/screens/buscar_emisor_screen.dart';
import 'package:connect/services/ble_service.dart';
import 'package:connect/services/dismissed_notifications_service.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/notification_listener_service.dart';
import 'package:connect/services/preferences_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:connect/services/local_notification_service.dart';
import 'package:connect/screens/receptor/notification_detail_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final ReceptorService _receptorService = ReceptorService();

  bool _isLoading = false;
  List<Map<String, dynamic>> _notifications = [];
  StreamSubscription? _notificationSubscription;
  String? _linkedDeviceId;
  bool _notificationsEnabled = false;
  bool _showLinkDetails = false;
  bool _latestExpanded = true;
  bool _btConnected = false;
  String? _btPeerName;
  bool _internetConnected = false;
  Timer? _hiveRefreshTimer;
  Timer? _mediaRefreshTimer;
  Map<String, dynamic>? _mediaState;
  Map<String, dynamic>? _volumeState;
  bool _showVolume = false;
  bool _isAdjustingVolume = false;
  double? _volumeFraction;
  Timer? _volumeDebounceTimer;
  bool _isSeeking = false;
  double? _seekFraction;
  int? _pendingSeekTargetMs;
  int _pendingSeekAtMs = 0;
  int _pendingSeekUntilMs = 0;
  String _pendingSeekTitle = '';
  String? _artCacheBase64;
  String? _artCacheFilePath;
  String _artCacheTitle = '';
  int _mediaBaseAtMs = 0;
  int _mediaBasePositionMs = 0;
  int _mediaBaseDurationMs = 0;
  bool _mediaBaseIsPlaying = false;
  String _mediaBaseTitle = '';
  String? _lastMediaDebugSig;
  int _lastMediaNullPrintMs = 0;
  int _lastBtStatusPrintMs = 0;
  String? _lastBtStatusSig;
  int _lastBtStatusPollMs = 0;
  int _btConnectedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLinkedDevice();
    _loadNotificationSettings();
    _startHiveRefresh();
    _startMediaRefresh();
    print('[conexion][media] initState: startMediaRefresh');
    _ensureBtServerRunning();

    // ✅ Sincronizar notificaciones canceladas al inicializar
    _syncCancelledNotifications();
  }

  Future<void> _ensureBtServerRunning() async {
    try {
      final enabled = await PreferencesService.getBleEnabled();
      print('[conexion][bt] ensure_server enabled=$enabled');
      if (!enabled) return;

      await BleService.requestPermissions();
      await BleService.startBtServer();
      final status = await BleService.getBtServerStatus();
      final running = status['running'] == true;
      final peers = (status['connectedCount'] as num?)?.toInt() ?? 0;
      print('[conexion][bt] ensure_server result running=$running peers=$peers');
      await _relayDebugToEmisor(
        'receptor_ui',
        'ensure_server result running=$running peers=$peers',
      );
    } catch (_) {
      print('[conexion][bt] ensure_server error');
      await _relayDebugToEmisor('receptor_ui', 'ensure_server error');
    }
  }

  Future<void> _relayDebugToEmisor(String source, String message) async {
    try {
      final status = await BleService.getBtServerStatus();
      final running = status['running'] == true;
      final peers = (status['connectedCount'] as num?)?.toInt() ?? 0;
      if (!running || peers <= 0) return;
      await BleService.sendBtServerMessage({
        'type': 'debug_log',
        'source': source,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  // ✅ Nuevo método para sincronizar notificaciones canceladas
  Future<void> _syncCancelledNotifications() async {
    try {
      await LocalNotificationService.syncCancelledNotificationsWithAndroid();
    } catch (e) {
      // print('Error al sincronizar notificaciones canceladas: $e');
    }
  }

  // Load initial state for the notification toggle
  Future<void> _loadNotificationSettings() async {
    final notificationsEnabled =
        await LocalNotificationService.areNotificationsEnabled();
    setState(() {
      _notificationsEnabled = notificationsEnabled;
    });

    // Iniciar o detener el servicio según el estado del toggle
    await NotificationListenerService.instance.setListeningEnabled(
      notificationsEnabled,
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _hiveRefreshTimer?.cancel();
    _mediaRefreshTimer?.cancel();
    _volumeDebounceTimer?.cancel();
    final path = _artCacheFilePath;
    if (path != null && path.isNotEmpty) {
      try { File(path).delete(); } catch (_) {}
    }
    super.dispose();
  }

  // Cargar el dispositivo vinculado y comenzar a escuchar notificaciones
  Future<void> _loadLinkedDevice() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener el ID del dispositivo emisor vinculado
      final deviceId = await _receptorService.getLinkedDeviceId();
      if (!mounted) return;

      if (deviceId != null) {
        setState(() {
          _linkedDeviceId = deviceId;
        });

        // Iniciar escucha de notificaciones
        _startListeningForReadNotifications();
      } else {
        // Si no hay dispositivo vinculado, redirigir a la pantalla de vinculación
        Navigator.pushReplacementNamed(context, '/receptor');
      }
    } catch (e) {
      // print('Error al cargar dispositivo vinculado: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Iniciar escucha de notificaciones no leídas
  void _startListeningForReadNotifications() {
    _notificationSubscription
        ?.cancel(); // Cancelar suscripción anterior si existe

    _notificationSubscription = _receptorService
        .listenForSeenNotifications()
        .listen(
          (notifications) {
            if (!mounted) return; // Verificar si el widget sigue montado

            if (mounted) {
              // Verificar nuevamente antes de setState
              setState(() {
                _notifications = notifications;
              });
            }
            _mergeHiveSeenIntoState();
          },
          onError: (error) {
          },
        );
  }

  void _startHiveRefresh() {
    _hiveRefreshTimer?.cancel();
    _hiveRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _mergeHiveSeenIntoState();
    });
  }

  void _startMediaRefresh() {
    _mediaRefreshTimer?.cancel();
    _mediaRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _mergeHiveMediaIntoState();
    });
  }

  Future<void> _mergeHiveMediaIntoState() async {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastBtStatusPollMs > 3000) {
        _lastBtStatusPollMs = nowMs;
        try {
          final status = await BleService.getBtServerStatus();
          final running = status['running'] == true;
          final connectedCount =
              (status['connectedCount'] as num?)?.toInt() ?? 0;
          _btConnectedCount = connectedCount;
          final peerName = status['lastPeerName']?.toString() ?? '';
          final sig = 'running=$running peers=$connectedCount peer=$peerName';
          if (sig != _lastBtStatusSig && nowMs - _lastBtStatusPrintMs > 1500) {
            _lastBtStatusSig = sig;
            _lastBtStatusPrintMs = nowMs;
            print('[conexion][bt] status $sig');
            await _relayDebugToEmisor('receptor_ui', 'bt_status $sig');
          }
        } catch (_) {
          _btConnectedCount = 0;
        }
      }

      Map<String, dynamic>? hiveState;
      try {
        hiveState = await BtHiveStorageService.getBtMediaState();
      } catch (_) {
        hiveState = null;
      }

      Map<String, dynamic>? hiveVolume;
      try {
        hiveVolume = await BtHiveStorageService.getBtVolumeState();
      } catch (_) {
        hiveVolume = null;
      }
      if (hiveVolume != null) {
        final nextPct = _toInt(hiveVolume['pct']).clamp(0, 100);
        final currentPct = _toInt(_volumeState?['pct']).clamp(0, 100);
        if (nextPct != currentPct && mounted && !_isAdjustingVolume) {
          setState(() {
            _volumeState = hiveVolume;
          });
        } else if (_volumeState == null && mounted && !_isAdjustingVolume) {
          setState(() {
            _volumeState = hiveVolume;
          });
        }
      }

      Map<String, dynamic>? serviceState;
      int serviceUpdatedAtMs = 0;
      try {
        final cached = await BleService.getLastBtMediaState();
        final cachedJson = (cached?['json'] ?? '').toString();
        serviceUpdatedAtMs = _toInt(cached?['updatedAtMs']);
        if (cachedJson.trim().isNotEmpty) {
          final decoded = jsonDecode(cachedJson);
          if (decoded is Map) {
            final decodedMap = Map<String, dynamic>.from(decoded);
            if ((decodedMap['type'] ?? '').toString() == 'media_state') {
              serviceState = decodedMap;
            }
          }
        }
      } catch (_) {
        serviceState = null;
      }

      Map<String, dynamic>? localServiceState;
      int localServiceUpdatedAtMs = 0;
      try {
        final cached = await BleService.getLastLocalMediaState();
        final cachedJson = (cached?['json'] ?? '').toString();
        localServiceUpdatedAtMs = _toInt(cached?['updatedAtMs']);
        if (cachedJson.trim().isNotEmpty) {
          final decoded = jsonDecode(cachedJson);
          if (decoded is Map) {
            final decodedMap = Map<String, dynamic>.from(decoded);
            if ((decodedMap['type'] ?? '').toString() == 'media_state') {
              localServiceState = decodedMap;
            }
          }
        }
      } catch (_) {
        localServiceState = null;
      }

      if (!mounted) return;
      if (_isSeeking) return;

      final hiveUpdatedAtMs = _toInt(hiveState?['updatedAtMs']);
      final prioritizeLocal = await PreferencesService.getPrioritizeLocalMedia();

      Map<String, dynamic>? remoteCandidate = hiveState;
      int remoteCandidateUpdatedAtMs = hiveUpdatedAtMs;
      if (serviceState != null &&
          serviceUpdatedAtMs > 0 &&
          (remoteCandidate == null ||
              serviceUpdatedAtMs > remoteCandidateUpdatedAtMs + 250)) {
        remoteCandidate = serviceState;
        remoteCandidateUpdatedAtMs = serviceUpdatedAtMs;
      }

      final remoteFresh = remoteCandidate != null &&
          _btConnectedCount > 0 &&
          remoteCandidateUpdatedAtMs > 0 &&
          nowMs - remoteCandidateUpdatedAtMs <= 15000 &&
          (remoteCandidate['title'] ?? '').toString().trim().isNotEmpty;
      if (!remoteFresh) {
        remoteCandidate = null;
        remoteCandidateUpdatedAtMs = 0;
      }

      final localFresh = localServiceState != null &&
          localServiceUpdatedAtMs > 0 &&
          nowMs - localServiceUpdatedAtMs <= 15000 &&
          (localServiceState['title'] ?? '').toString().trim().isNotEmpty;
      final localCandidate = localFresh ? localServiceState : null;

      Map<String, dynamic>? state;
      bool useLocal = false;
      if (prioritizeLocal) {
        if (localCandidate != null) {
          state = localCandidate;
          useLocal = true;
        } else {
          state = remoteCandidate;
        }
      } else {
        if (remoteCandidate != null) {
          state = remoteCandidate;
        } else if (localCandidate != null) {
          state = localCandidate;
          useLocal = true;
        } else {
          state = null;
        }
      }

      if (useLocal) {
        final rawLocalPct = (localServiceState?['volumePct'] as num?)?.toInt() ?? -1;
        if (rawLocalPct >= 0 && rawLocalPct <= 100) {
          final currentPct = _toInt(_volumeState?['pct']).clamp(0, 100);
          if (mounted && !_isAdjustingVolume && rawLocalPct != currentPct) {
            setState(() {
              _volumeState = {'pct': rawLocalPct};
            });
          }
        }
      }

      if (state == null) {
        if (nowMs - _lastMediaNullPrintMs > 5000) {
          _lastMediaNullPrintMs = nowMs;
          print('[conexion][media] hive_state=null');
          await _relayDebugToEmisor('receptor_ui', 'hive_state=null');
        }
        setState(() {
          _mediaState = null;
        });
        return;
      }

      final title = (state['title'] ?? '').toString();
      final appName = (state['appName'] ?? '').toString();
      final isPlaying = _toBool(state['isPlaying']);
      final positionMs = _toInt(state['positionMs']);
      final durationMs = _toInt(state['durationMs']);

      final pendingTarget = _pendingSeekTargetMs;
      if (pendingTarget != null) {
        final expired = nowMs >= _pendingSeekUntilMs;
        final titleChanged = title != _pendingSeekTitle;
        final reached = (positionMs - pendingTarget).abs() <= 1500;
        if (expired || titleChanged || reached) {
          _pendingSeekTargetMs = null;
          _pendingSeekAtMs = 0;
          _pendingSeekUntilMs = 0;
          _pendingSeekTitle = '';
        }
      }

      await _syncArtCache((state['artBase64'] ?? '').toString(), title: title);
      if (title != _mediaBaseTitle ||
          positionMs != _mediaBasePositionMs ||
          durationMs != _mediaBaseDurationMs ||
          isPlaying != _mediaBaseIsPlaying) {
        _mediaBaseAtMs = nowMs;
        _mediaBaseTitle = title;
        _mediaBasePositionMs = positionMs;
        _mediaBaseDurationMs = durationMs;
        _mediaBaseIsPlaying = isPlaying;
      }
      final sig = '$title|$appName|${(positionMs / 1000).floor()}|$isPlaying';
      if (sig != _lastMediaDebugSig) {
        _lastMediaDebugSig = sig;
        final sourceLabel = useLocal ? 'local' : 'emisor';
        print('[conexion][media] $sourceLabel title="$title" app="$appName" posMs=$positionMs playing=$isPlaying');
      }
      setState(() {
        _mediaState = state;
      });
    } catch (_) {}
  }

  Future<void> _sendMediaCommand(String command, {int? positionMs}) async {
    try {
      final enabled = await PreferencesService.getBleEnabled();
      print('[conexion][media][cmd] request command=$command positionMs=${positionMs ?? ""} enabled=$enabled');
      if (!enabled) return;

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final state = _mediaState;
      if (state != null && mounted) {
        final title = (state['title'] ?? '').toString();
        if (command == 'toggle' || command == 'play' || command == 'pause') {
          final currentPlaying = _toBool(state['isPlaying']);
          final nextPlaying = command == 'toggle'
              ? !currentPlaying
              : (command == 'play');
          setState(() {
            _mediaState = {
              ...state,
              'isPlaying': nextPlaying,
            };
          });
          _mediaBaseAtMs = nowMs;
          _mediaBaseTitle = title;
          _mediaBaseIsPlaying = nextPlaying;
          _mediaBasePositionMs = _toInt(state['positionMs']);
          _mediaBaseDurationMs = _toInt(state['durationMs']);
        } else if (command == 'seekTo' && positionMs != null) {
          _pendingSeekTargetMs = positionMs;
          _pendingSeekAtMs = nowMs;
          _pendingSeekUntilMs = nowMs + 8000;
          _pendingSeekTitle = title;
        }
      }

      final payload = <String, dynamic>{
        'type': 'media_command',
        'command': command,
        if (positionMs != null) 'positionMs': positionMs,
        'time': DateTime.now().millisecondsSinceEpoch,
      };

      bool useLocal = false;
      try {
        int connectedCount = 0;
        try {
          final status = await BleService.getBtServerStatus();
          connectedCount = (status['connectedCount'] as num?)?.toInt() ?? 0;
        } catch (_) {}

        final prioritizeLocal = await PreferencesService.getPrioritizeLocalMedia();
        Map<String, dynamic>? remote;
        int remoteAt = 0;
        try {
          final cached = await BleService.getLastBtMediaState();
          remoteAt = _toInt(cached?['updatedAtMs']);
          final raw = (cached?['json'] ?? '').toString();
          if (raw.trim().isNotEmpty) {
            final decoded = jsonDecode(raw);
            if (decoded is Map) remote = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}

        Map<String, dynamic>? local;
        int localAt = 0;
        try {
          final cached = await BleService.getLastLocalMediaState();
          localAt = _toInt(cached?['updatedAtMs']);
          final raw = (cached?['json'] ?? '').toString();
          if (raw.trim().isNotEmpty) {
            final decoded = jsonDecode(raw);
            if (decoded is Map) local = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}

        final remoteFresh = remoteAt > 0 &&
            connectedCount > 0 &&
            nowMs - remoteAt <= 15000 &&
            (remote?['title'] ?? '').toString().trim().isNotEmpty;
        final localFresh = localAt > 0 &&
            nowMs - localAt <= 15000 &&
            (local?['title'] ?? '').toString().trim().isNotEmpty;
        useLocal = prioritizeLocal ? (localFresh || !remoteFresh) : (!remoteFresh && localFresh);
      } catch (_) {}

      if (useLocal) {
        print('[conexion][media][cmd] send via bt_server local');
        await BleService.sendBtServerMessage(payload);
        return;
      }

      try {
        final status = await BleService.getBtServerStatus();
        final running = status['running'] == true;
        final connectedCount = (status['connectedCount'] as num?)?.toInt() ?? 0;
        if (running && connectedCount > 0) {
          print('[conexion][media][cmd] send via bt_server peers=$connectedCount');
          await BleService.sendBtServerMessage(payload);
          return;
        }
      } catch (_) {}

      print('[conexion][media][cmd] send via ble_notification fallback');
      await BleService.sendNotification(payload);
    } catch (_) {}
  }

  Future<void> _sendVolumeRequest() async {
    try {
      final enabled = await PreferencesService.getBleEnabled();
      if (!enabled) return;

      try {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final prioritizeLocal = await PreferencesService.getPrioritizeLocalMedia();
        int connectedCount = 0;
        try {
          final status = await BleService.getBtServerStatus();
          connectedCount = (status['connectedCount'] as num?)?.toInt() ?? 0;
        } catch (_) {}
        final remote = await BleService.getLastBtMediaState();
        final local = await BleService.getLastLocalMediaState();
        final remoteAt = _toInt(remote?['updatedAtMs']);
        final localAt = _toInt(local?['updatedAtMs']);
        final remoteFresh =
            remoteAt > 0 && connectedCount > 0 && nowMs - remoteAt <= 15000;
        final localFresh = localAt > 0 && nowMs - localAt <= 15000;
        final useLocal = prioritizeLocal ? (localFresh || !remoteFresh) : (!remoteFresh && localFresh);
        if (useLocal) return;
      } catch (_) {}

      final payload = <String, dynamic>{
        'type': 'volume_request',
        'time': DateTime.now().millisecondsSinceEpoch,
      };

      try {
        final status = await BleService.getBtServerStatus();
        final running = status['running'] == true;
        final connectedCount = (status['connectedCount'] as num?)?.toInt() ?? 0;
        if (running && connectedCount > 0) {
          await BleService.sendBtServerMessage(payload);
          return;
        }
      } catch (_) {}

      await BleService.sendNotification(payload);
    } catch (_) {}
  }

  Future<void> _sendVolumeCommandPct(int pct) async {
    try {
      final enabled = await PreferencesService.getBleEnabled();
      if (!enabled) return;

      final clamped = pct.clamp(0, 100).toInt();
      final payload = <String, dynamic>{
        'type': 'volume_command',
        'pct': clamped,
        'time': DateTime.now().millisecondsSinceEpoch,
      };

      bool useLocal = false;
      try {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final prioritizeLocal = await PreferencesService.getPrioritizeLocalMedia();
        int connectedCount = 0;
        try {
          final status = await BleService.getBtServerStatus();
          connectedCount = (status['connectedCount'] as num?)?.toInt() ?? 0;
        } catch (_) {}
        final remote = await BleService.getLastBtMediaState();
        final local = await BleService.getLastLocalMediaState();
        final remoteAt = _toInt(remote?['updatedAtMs']);
        final localAt = _toInt(local?['updatedAtMs']);
        final remoteFresh =
            remoteAt > 0 && connectedCount > 0 && nowMs - remoteAt <= 15000;
        final localFresh = localAt > 0 && nowMs - localAt <= 15000;
        useLocal = prioritizeLocal ? (localFresh || !remoteFresh) : (!remoteFresh && localFresh);
      } catch (_) {}

      if (useLocal) {
        await BleService.sendBtServerMessage(payload);
        return;
      }

      try {
        final status = await BleService.getBtServerStatus();
        final running = status['running'] == true;
        final connectedCount = (status['connectedCount'] as num?)?.toInt() ?? 0;
        if (running && connectedCount > 0) {
          await BleService.sendBtServerMessage(payload);
          return;
        }
      } catch (_) {}

      await BleService.sendNotification(payload);
    } catch (_) {}
  }

  void _debounceVolumeSend(int pct) {
    _volumeDebounceTimer?.cancel();
    _volumeDebounceTimer = Timer(const Duration(milliseconds: 120), () async {
      await _sendVolumeCommandPct(pct);
    });
  }

  Future<void> _mergeHiveSeenIntoState() async {
    try {
      final localAll = await BtHiveStorageService.getLocalNotificationsForUi(
        includeVisualized: true,
      );
      final local = localAll
          .where((n) => n['status-visualizacion'] == true)
          .toList();

      if (!mounted) return;

      final Map<String, Map<String, dynamic>> byId = {};
      for (final n in _notifications) {
        final key = (n['notificationId'] ?? n['id'] ?? '').toString();
        if (key.isEmpty) continue;
        byId[key] = n;
      }
      for (final n in local) {
        final key = (n['notificationId'] ?? n['id'] ?? '').toString();
        if (key.isEmpty) continue;
        byId.putIfAbsent(key, () => n);
      }

      final merged = byId.values.toList();
      merged.sort((a, b) {
        final ta = (a['timestamp'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb = (b['timestamp'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });

      setState(() {
        _notifications = merged;
      });
    } catch (_) {}
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    try {
      final notificationId =
          (notification['notificationId'] ?? notification['id'])?.toString();
      if (notificationId == null || notificationId.isEmpty) return;

      await BtHiveStorageService.deleteOutboxEntry(notificationId);
      await DismissedNotificationsService.markAsDismissed(notificationId);
      await LocalNotificationService.cancelNotification(notificationId);

      // Usa tu servicio de Firebase para eliminar
      await FirebaseService().deleteNotification(notificationId, '');
    } catch (e) {
      // print('Error al eliminar notificación: \$e');
    }
  }

  Future<void> _deleteAllNotifications() async {
    try {
      final all = List<Map<String, dynamic>>.from(_notifications);
      for (final n in all) {
        await _deleteNotification(n);
      }
      await LocalNotificationService.syncCancelledNotificationsWithAndroid();
    } catch (_) {}
  }

  Future<void> _toggleLinkDetails() async {
    final next = !_showLinkDetails;
    setState(() {
      _showLinkDetails = next;
    });
    if (next) {
      await _refreshConnectionInfo();
    }
  }

  Future<void> _refreshConnectionInfo() async {
    try {
      final status = await BleService.getBtServerStatus();
      final dynamic rawConnectedCount = status['connectedCount'];
      final connectedCount = rawConnectedCount is int
          ? rawConnectedCount
          : int.tryParse(rawConnectedCount?.toString() ?? '') ?? 0;
      final peerName = status['lastPeerName']?.toString();

      final internet = await FirebaseService().getLinkStatus();
      if (!mounted) return;
      setState(() {
        _btConnected = connectedCount > 0;
        _btPeerName = (peerName != null && peerName.trim().isNotEmpty)
            ? peerName.trim()
            : null;
        _internetConnected = internet;
      });
    } catch (_) {}
  }

  String _connectionMediumLabel() {
    if (_btConnected && _internetConnected) return 'Ambos';
    if (_btConnected) return 'Bluetooth';
    if (_internetConnected) return 'Internet';
    return 'Sin conexión';
  }

  @override
  Widget build(BuildContext context) {
    final latest = List<Map<String, dynamic>>.from(_notifications);
    latest.sort((a, b) {
      final ta = (a['timestamp'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb = (b['timestamp'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    final latestFive = latest.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conexión'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            tooltip: 'Filtros de notificaciones',
            onPressed: () {
              Navigator.pushNamed(context, '/notification_filters');
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _deleteAllNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(5.0),
              child: SingleChildScrollView(
                // Wrap the Column with SingleChildScrollView
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    // card para dispositivo vinculado
                    GestureDetector(
                      onTap: _toggleLinkDetails,
                      child: Card(
                        margin: const EdgeInsets.all(0),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(Icons.link, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Dispositivo vinculado',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                          if (_showLinkDetails)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              child: Text(
                                                'Medio: ${_connectionMediumLabel()}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'ID: $_linkedDeviceId',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        if (_showLinkDetails &&
                                            _btConnected &&
                                            (_btPeerName?.isNotEmpty == true))
                                          Text(
                                            'BT: $_btPeerName',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      margin: const EdgeInsets.all(0),
                      child: ListTile(
                        leading: const Icon(Icons.search),
                        title: const Text('Buscar emisor'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const BuscarEmisorScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      margin: const EdgeInsets.all(0),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Builder(
                          builder: (context) {
                            final state = _mediaState;
                            final title =
                                (state?['title'] ?? '').toString().trim();
                            final appName =
                                (state?['appName'] ?? '').toString().trim();
                            final artist =
                                (state?['artist'] ?? '').toString().trim();
                            final bool isPlaying = _toBool(state?['isPlaying']);
                            final bool canPlayPause =
                                _toBool(state?['canPlayPause'], defaultValue: true);
                            final bool canSkipNext = _toBool(state?['canSkipNext']);
                            final bool canSkipPrev = _toBool(state?['canSkipPrev']);
                            final bool canSeek =
                                _toBool(state?['canSeek'], defaultValue: true);

                            final dynamic durationRaw = state?['durationMs'];
                            final int durationMs = _toInt(durationRaw);

                            final dynamic positionRaw = state?['positionMs'];
                            final int positionMs = _toInt(positionRaw);

                            final hasMedia = title.isNotEmpty;

                            final nowMs = DateTime.now().millisecondsSinceEpoch;
                            final int effectivePositionMs = _effectivePositionMs(
                              title: title,
                              positionMs: positionMs,
                              durationMs: durationMs,
                              isPlaying: isPlaying,
                              nowMs: nowMs,
                            );
                            final int displayPositionMs =
                                (_isSeeking && _seekFraction != null && durationMs > 0)
                                    ? (durationMs * _seekFraction!).round().clamp(0, durationMs).toInt()
                                    : effectivePositionMs;

                            final double progress = (durationMs > 0)
                                ? (displayPositionMs / durationMs)
                                    .clamp(0.0, 1.0)
                                : 0.0;

                            final double sliderValue =
                                (_seekFraction ?? progress).clamp(0.0, 1.0);
                            final artPath = _artCacheFilePath;
                            final hasArt = artPath != null &&
                                artPath.isNotEmpty &&
                                File(artPath).existsSync();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Control multimedia',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (hasArt)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(artPath),
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: Colors.grey.shade200,
                                        ),
                                        child: const Icon(
                                          Icons.music_note,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            hasMedia ? title : 'Sin reproducción',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            hasMedia
                                                ? (() {
                                                    if (artist.isNotEmpty &&
                                                        appName.isNotEmpty) {
                                                      return '$artist • $appName';
                                                    }
                                                    if (artist.isNotEmpty) {
                                                      return artist;
                                                    }
                                                    if (appName.isNotEmpty) {
                                                      return appName;
                                                    }
                                                    return 'Emisor';
                                                  })()
                                                : 'Conecta el emisor para controlar',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (durationMs > 0)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 3,
                                        ),
                                        child: Slider(
                                          value: sliderValue,
                                          onChangeStart: hasMedia && canSeek
                                              ? (_) {
                                                  setState(() {
                                                    _isSeeking = true;
                                                  });
                                                }
                                              : null,
                                          onChanged: hasMedia && canSeek
                                              ? (v) {
                                                  setState(() {
                                                    _seekFraction = v;
                                                  });
                                                }
                                              : null,
                                          onChangeEnd: hasMedia && canSeek
                                              ? (v) async {
                                                  final target = (durationMs * v)
                                                      .round()
                                                      .clamp(0, durationMs)
                                                      .toInt();
                                                  await _sendMediaCommand(
                                                    'seekTo',
                                                    positionMs: target,
                                                  );
                                                  if (!mounted) return;
                                                  setState(() {
                                                    _isSeeking = false;
                                                    _seekFraction = null;
                                                  });
                                                }
                                              : null,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _formatMs(displayPositionMs),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            Text(
                                              _formatMs(durationMs),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  LinearProgressIndicator(
                                    value: hasMedia ? null : 0,
                                    minHeight: 3,
                                  ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.skip_previous),
                                      onPressed: hasMedia && canSkipPrev
                                          ? () => _sendMediaCommand('previous')
                                          : null,
                                      iconSize: 32,
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        isPlaying ? Icons.pause : Icons.play_arrow,
                                      ),
                                      onPressed: hasMedia && canPlayPause
                                          ? () => _sendMediaCommand('toggle')
                                          : null,
                                      iconSize: 44,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.skip_next),
                                      onPressed: hasMedia && canSkipNext
                                          ? () => _sendMediaCommand('next')
                                          : null,
                                      iconSize: 32,
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        _showVolume
                                            ? Icons.volume_up
                                            : Icons.volume_down,
                                      ),
                                      onPressed: () async {
                                        setState(() {
                                          _showVolume = !_showVolume;
                                          _isAdjustingVolume = false;
                                          _volumeFraction = null;
                                        });
                                        if (_showVolume) {
                                          await _sendVolumeRequest();
                                        }
                                      },
                                      iconSize: 32,
                                    ),
                                  ],
                                ),
                                if (_showVolume)
                                  Builder(
                                    builder: (context) {
                                      final int basePct = (() {
                                        final v = _volumeState;
                                        final pct = _toInt(v?['pct']);
                                        if (pct > 0) return pct.clamp(0, 100);
                                        final mpct = _toInt(state?['volumePct']);
                                        return mpct.clamp(0, 100);
                                      })();
                                      final double value = (_isAdjustingVolume &&
                                              _volumeFraction != null)
                                          ? _volumeFraction!.clamp(0.0, 1.0)
                                          : (basePct / 100.0).clamp(0.0, 1.0);
                                      final int shownPct =
                                          (value * 100).round().clamp(0, 100);

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const SizedBox(height: 6),
                                          SliderTheme(
                                            data:
                                                SliderTheme.of(context).copyWith(
                                              trackHeight: 8,
                                            ),
                                            child: Slider(
                                              value: value,
                                              onChangeStart: (_) {
                                                setState(() {
                                                  _isAdjustingVolume = true;
                                                });
                                              },
                                              onChanged: (v) {
                                                setState(() {
                                                  _volumeFraction = v;
                                                });
                                                _debounceVolumeSend(
                                                  (v * 100).round().clamp(0, 100),
                                                );
                                              },
                                              onChangeEnd: (v) async {
                                                await _sendVolumeCommandPct(
                                                  (v * 100).round().clamp(0, 100),
                                                );
                                                if (!mounted) return;
                                                setState(() {
                                                  _isAdjustingVolume = false;
                                                  _volumeFraction = null;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$shownPct%',
                                            textAlign: TextAlign.end,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      margin: const EdgeInsets.all(0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            title: const Text(
                              'Últimas notificaciones',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                _latestExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              onPressed: () {
                                setState(() {
                                  _latestExpanded = !_latestExpanded;
                                });
                              },
                            ),
                          ),
                          if (_latestExpanded)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 8,
                                right: 8,
                                bottom: 8,
                              ),
                              child: latestFive.isEmpty
                                  ? const SizedBox.shrink()
                                  : Column(
                                      children: latestFive.map((notification) {
                                        final notificationId =
                                            (notification['notificationId'] ??
                                                    notification['id'] ??
                                                    '')
                                                .toString();
                                        final timestamp = notification['timestamp'];
                                        final timestampKey =
                                            timestamp is Timestamp
                                                ? timestamp
                                                    .millisecondsSinceEpoch
                                                    .toString()
                                                : timestamp?.toString() ?? '';
                                        final dismissKey = notificationId.isNotEmpty
                                            ? ValueKey(
                                                '$notificationId-$timestampKey',
                                              )
                                            : UniqueKey();

                                        return Dismissible(
                                          key: dismissKey,
                                          direction:
                                              DismissDirection.endToStart,
                                          background: Container(
                                            color: Colors.red,
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: const Icon(
                                              Icons.delete,
                                              color: Colors.white,
                                            ),
                                          ),
                                          onDismissed: (_) async {
                                            await _deleteNotification(
                                              notification,
                                            );
                                          },
                                          child: GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      NotificationDetailScreen(
                                                    notificationData:
                                                        notification,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Card(
                                              margin: const EdgeInsets.only(
                                                bottom: 8.0,
                                                left: 1,
                                                right: 1,
                                              ),
                                              child: ListTile(
                                                title: Text(
                                                  notification['title'] ??
                                                      'Sin título',
                                                ),
                                                subtitle: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      notification['text'] ??
                                                          'Sin contenido',
                                                    ),
                                                    Text(
                                                      'App: ${notification['appName'] ?? notification['packageName'] ?? 'Desconocida'}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                trailing: Text(
                                                  _formatTimestamp(
                                                    notification['timestamp'],
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 3,
            color: customColor[700], // Barra divisoria con customColor
          ),
          BottomNavigationBar(
            currentIndex:
                1, // 0: Configuración, 1: Conexión, 2: Notificaciones
            onTap: (index) {
              switch (index) {
                case 0:
                  Navigator.pushReplacementNamed(context, '/receptor_settings');
                  break;
                case 1:
                  break;
                case 2:
                  Navigator.pushReplacementNamed(
                    context,
                    '/unread_notifications',
                  );
                  break;
              }
            },
            selectedFontSize: 14.0,
            unselectedFontSize: 12.0,
            selectedIconTheme: const IconThemeData(size: 37.5),
            unselectedIconTheme: const IconThemeData(size: 22.5),
            selectedItemColor:
                customColor[700], // Color para el ítem seleccionado
            unselectedItemColor:
                Colors.black, // Color para los ítems no seleccionados
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Configuración',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  Icons.radio_button_checked,
                  color: _notificationsEnabled ? Colors.green : Colors.red,
                ),
                label: 'Conexión',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.mark_email_unread),
                label: 'Notificaciones',
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    return int.tryParse(s) ?? 0;
  }

  bool _toBool(dynamic v, {bool defaultValue = false}) {
    if (v == null) return defaultValue;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toLowerCase();
    if (s.isEmpty) return defaultValue;
    if (s == 'true' || s == '1' || s == 'yes' || s == 'y') return true;
    if (s == 'false' || s == '0' || s == 'no' || s == 'n') return false;
    return defaultValue;
  }

  int _effectivePositionMs({
    required String title,
    required int positionMs,
    required int durationMs,
    required bool isPlaying,
    required int nowMs,
  }) {
    var pos = positionMs;
    if (pos < 0) pos = 0;
    if (durationMs > 0 && pos > durationMs) pos = durationMs;
    if (title.isEmpty) return pos;

    final pendingTarget = _pendingSeekTargetMs;
    if (pendingTarget != null &&
        title == _pendingSeekTitle &&
        nowMs < _pendingSeekUntilMs &&
        _pendingSeekAtMs > 0) {
      final deltaMs = nowMs - _pendingSeekAtMs;
      var effective = pendingTarget + (isPlaying ? deltaMs : 0);
      if (durationMs > 0) {
        effective = effective.clamp(0, durationMs);
      } else if (effective < 0) {
        effective = 0;
      }
      return effective;
    }

    if (!isPlaying) return pos;

    if (_mediaBaseAtMs <= 0 || _mediaBaseTitle != title) return pos;
    final deltaMs = nowMs - _mediaBaseAtMs;
    if (deltaMs <= 0) return pos;

    var effective = _mediaBasePositionMs + deltaMs;
    if (durationMs > 0) {
      effective = effective.clamp(0, durationMs);
    } else if (effective < 0) {
      effective = 0;
    }
    return effective;
  }

  Future<void> _syncArtCache(String artBase64, {required String title}) async {
    final trimmed = artBase64.trim();
    final t = title.trim();

    if (trimmed.isEmpty) {
      if (t.isNotEmpty && t == _artCacheTitle) {
        return;
      }
      final oldPath = _artCacheFilePath;
      _artCacheBase64 = null;
      _artCacheFilePath = null;
      _artCacheTitle = '';
      if (oldPath != null && oldPath.isNotEmpty) {
        try {
          PaintingBinding.instance.imageCache.evict(FileImage(File(oldPath)));
        } catch (_) {}
        try { await File(oldPath).delete(); } catch (_) {}
      }
      return;
    }

    if (trimmed == _artCacheBase64 && t == _artCacheTitle) return;

    List<int>? bytes;
    try {
      bytes = base64Decode(trimmed);
    } catch (_) {
      bytes = null;
    }
    if (bytes == null) return;

    final oldPath = _artCacheFilePath;
    final safePrefix = trimmed.length >= 16 ? trimmed.substring(0, 16) : trimmed;
    final safeId = '${trimmed.length}_${safePrefix.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}';
    final newPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}connect_media_art_$safeId.jpg';
    try {
      final f = File(newPath);
      try {
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
      await f.writeAsBytes(bytes, flush: true);
    } catch (_) {
      return;
    }

    _artCacheBase64 = trimmed;
    _artCacheFilePath = newPath;
    _artCacheTitle = t;

    if (oldPath != null && oldPath.isNotEmpty && oldPath != newPath) {
      try {
        PaintingBinding.instance.imageCache.evict(FileImage(File(oldPath)));
      } catch (_) {}
      try { await File(oldPath).delete(); } catch (_) {}
    }
  }

  String _formatMs(int ms) {
    if (ms <= 0) return '0:00';
    final totalSeconds = (ms / 1000).floor();
    final seconds = totalSeconds % 60;
    final totalMinutes = (totalSeconds / 60).floor();
    final minutes = totalMinutes % 60;
    final hours = (totalMinutes / 60).floor();
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final mm = minutes.toString().padLeft(2, '0');
      return '$hours:$mm:$ss';
    }
    return '$minutes:$ss';
  }

  // Formatear timestamp para mostrar
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    final DateTime date = (timestamp as Timestamp).toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
