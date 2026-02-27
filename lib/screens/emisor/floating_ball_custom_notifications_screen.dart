import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:connect/services/floating_ball_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FloatingBallCustomNotificationsScreen extends StatefulWidget {
  const FloatingBallCustomNotificationsScreen({super.key});

  @override
  State<FloatingBallCustomNotificationsScreen> createState() =>
      _FloatingBallCustomNotificationsScreenState();
}

class _FloatingBallCustomNotificationsScreenState
    extends State<FloatingBallCustomNotificationsScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _emisorChannel =
      MethodChannel('com.example.connect/notifications');
  static const MethodChannel _floatingBallChannel =
      MethodChannel('com.example.connect/floating_ball');
  static const EventChannel _activeNotificationsEvents =
      EventChannel('com.example.connect/active_notifications_events');

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  final ValueNotifier<_SystemState> _systemState =
      ValueNotifier<_SystemState>(_SystemState.initial);
  Timer? _systemTick;
  StreamSubscription<dynamic>? _activeNotifsEventsSub;
  Timer? _refreshDebounce;
  final List<Map<String, dynamic>> _pendingNotifsEvents = <Map<String, dynamic>>[];
  bool _refreshing = false;
  bool _liveRefreshEnabled = false;

  bool _fsBarEnabled = false;
  int _fsBgColor = 0xCC111111;
  int _fsContainerPaddingHorzDp = 16;
  int _fsContainerPaddingVertDp = 16;
  int _fsIconSizeDp = 26;
  int _fsTextSizeSp = 14;
  int _fsStickyPaddingDp = 0;
  bool _fsCloseSticky = false;
  bool _fsCloseDisableStickyWhenMediaActive = true;
  int _fsCloseHeightDp = 120;
  int _fsCloseBgColor = 0xFFDC2626;
  int _fsCloseTextColor = 0xFFFFFFFF;
  bool _fsCloseHideText = false;
  String _fsCloseIconId = 'close';
  String? _fsCloseIconPngBase64;
  String _fsCloseText = 'Cerrar';
  int _bottomButtonsIconHeightDp = 34;
  String _deleteButtonIconId = 'delete';
  String? _deleteButtonIconPngBase64;
  String _deleteButtonText = 'Eliminar';

  int _fsBarHeightDp = 54;
  int _fsBarBgColor = 0xCC111111;
  int _fsBarIconSizeDp = 18;
  int _fsBarTextSizeSp = 14;
  int _fsBarPaddingHorzDp = 16;
  int _fsBarPaddingVertDp = 0;
  int _fsBarTimeColor = 0xFFFFFFFF;
  int _fsBarWifiIconColor = 0xFFFFFFFF;
  int _fsBarBtIconColor = 0xFFFFFFFF;
  int _fsBarDataIconColor = 0xFFFFFFFF;
  int _fsBarLocIconColor = 0xFFFFFFFF;
  int _fsBarBatteryIconColor = 0xFFFFFFFF;
  int _fsBarBatteryTextColor = 0xFFFFFFFF;
  int _fsBarRestoreIconColor = 0xFFFFFFFF;
  int _fsBarRestoreBgColor = 0x33FFFFFF;
  String? _fsBarWifiIconPngBase64;
  String? _fsBarBtIconPngBase64;
  String? _fsBarDataIconPngBase64;
  String? _fsBarLocIconPngBase64;
  String? _fsBarBatteryIconPngBase64;
  String? _fsBarRestoreIconPngBase64;

  int _screenBgColor = 0xDD111111;
  int _itemBgColor = 0x22111111;
  int _itemBorderColor = 0x22FFFFFF;
  int _titleColor = 0xFFFFFFFF;
  int _textColor = 0xFFFFFFFF;
  int _titleSizeSp = 16;
  int _textSizeSp = 14;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _liveRefreshEnabled =
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
            WidgetsBinding.instance.lifecycleState != AppLifecycleState.detached;
    if (_liveRefreshEnabled) _startLiveRefresh();
    _loadStyle();
    _refresh();
    _refreshSystemState();
    _systemTick = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshSystemState();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLiveRefresh();
    _refreshDebounce?.cancel();
    _refreshDebounce = null;
    _systemTick?.cancel();
    _systemTick = null;
    _systemState.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final nextEnabled = state == AppLifecycleState.resumed;
    if (nextEnabled == _liveRefreshEnabled) return;
    _liveRefreshEnabled = nextEnabled;
    if (_liveRefreshEnabled) {
      _refresh(showLoading: false);
      _startLiveRefresh();
    } else {
      _stopLiveRefresh();
    }
  }

  void _startLiveRefresh() {
    _activeNotifsEventsSub ??=
        _activeNotificationsEvents.receiveBroadcastStream().listen((event) {
      final map = event is Map ? Map<String, dynamic>.from(event) : null;
      if (map == null) return;
      _pendingNotifsEvents.add(map);
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 110), () {
        if (!mounted || !_liveRefreshEnabled) return;
        _applyPendingNotifsEvents();
      });
    });
  }

  void _stopLiveRefresh() {
    _activeNotifsEventsSub?.cancel();
    _activeNotifsEventsSub = null;
    _refreshDebounce?.cancel();
    _refreshDebounce = null;
    _pendingNotifsEvents.clear();
  }

  void _applyPendingNotifsEvents() {
    if (_pendingNotifsEvents.isEmpty) return;

    final events = List<Map<String, dynamic>>.from(_pendingNotifsEvents);
    _pendingNotifsEvents.clear();

    final nextItems = List<Map<String, dynamic>>.from(_items);
    final indexByKey = <String, int>{};
    for (var i = 0; i < nextItems.length; i++) {
      final k = (nextItems[i]['key'] ?? '').toString();
      if (k.isNotEmpty) indexByKey[k] = i;
    }

    bool changed = false;

    bool sameEntry(Map<String, dynamic> a, Map<String, dynamic> b) {
      return (a['packageName'] ?? '').toString() == (b['packageName'] ?? '').toString() &&
          (a['appName'] ?? '').toString() == (b['appName'] ?? '').toString() &&
          (a['appIcon'] ?? '').toString() == (b['appIcon'] ?? '').toString() &&
          (a['title'] ?? '').toString() == (b['title'] ?? '').toString() &&
          (a['text'] ?? '').toString() == (b['text'] ?? '').toString() &&
          (a['subText'] ?? '').toString() == (b['subText'] ?? '').toString() &&
          ((a['postTime'] is int ? a['postTime'] as int : int.tryParse((a['postTime'] ?? '').toString()) ?? 0)) ==
              ((b['postTime'] is int ? b['postTime'] as int : int.tryParse((b['postTime'] ?? '').toString()) ?? 0));
    }

    for (final e in events) {
      final reason = (e['reason'] ?? '').toString();
      String key = (e['key'] ?? '').toString();

      if (reason == 'removed') {
        final idx = indexByKey[key];
        if (idx != null) {
          nextItems.removeAt(idx);
          changed = true;
          indexByKey.clear();
          for (var i = 0; i < nextItems.length; i++) {
            final k = (nextItems[i]['key'] ?? '').toString();
            if (k.isNotEmpty) indexByKey[k] = i;
          }
        }
        continue;
      }

      final entry = e['entry'];
      if (entry is Map) {
        final m = Map<String, dynamic>.from(entry);
        key = (m['key'] ?? key).toString();
        if (key.isEmpty) continue;

        final idx = indexByKey[key];
        if (idx == null) {
          nextItems.add(m);
          changed = true;
          indexByKey[key] = nextItems.length - 1;
        } else {
          final existing = nextItems[idx];
          if (!sameEntry(existing, m)) {
            nextItems[idx] = m;
            changed = true;
          }
        }
      }
    }

    if (!changed) return;

    nextItems.sort((a, b) {
      final aT = (a['postTime'] is int ? a['postTime'] as int : int.tryParse((a['postTime'] ?? '').toString()) ?? 0);
      final bT = (b['postTime'] is int ? b['postTime'] as int : int.tryParse((b['postTime'] ?? '').toString()) ?? 0);
      return bT.compareTo(aT);
    });

    if (!mounted) return;
    setState(() {
      _items = nextItems;
    });
  }

  Future<void> _loadStyle() async {
    try {
      final fsBarEnabled = await FloatingBallService.isFullScreenBarEnabled();
      final fsBgColor = await FloatingBallService.getFullScreenBgColor();
      final fsContainerPaddingHorzDp =
          await FloatingBallService.getFullScreenContainerPaddingHorzDp();
      final fsContainerPaddingVertDp =
          await FloatingBallService.getFullScreenContainerPaddingVertDp();
      final fsIconSizeDp = await FloatingBallService.getFullScreenIconSizeDp();
      final fsTextSizeSp = await FloatingBallService.getFullScreenTextSizeSp();
      final fsStickyPaddingDp = await FloatingBallService.getFullScreenStickyPaddingDp();
      final fsCloseSticky = await FloatingBallService.isFullScreenCloseStickyEnabled();
      final fsCloseDisableStickyWhenMediaActive =
          await FloatingBallService.isFullScreenCloseDisableStickyWhenMediaActiveEnabled();
      final fsCloseHeightDp = await FloatingBallService.getFullScreenCloseHeightDp();
      final fsCloseBgColor = await FloatingBallService.getFullScreenCloseBgColor();
      final fsCloseTextColor = await FloatingBallService.getFullScreenCloseTextColor();
      final fsCloseHideText = await FloatingBallService.isFullScreenCloseHideTextEnabled();
      final fsCloseIconId = await FloatingBallService.getFullScreenCloseIconId();
      final fsCloseIconPngBase64 = await FloatingBallService.getFullScreenCloseIconPngBase64();
      final fsCloseText = await FloatingBallService.getFullScreenCloseText();
      final bottomButtonsIconHeightDp =
          await FloatingBallService.getCustomNotificationsButtonsIconHeightDp();
      final deleteButtonIconId =
          await FloatingBallService.getCustomNotificationsDeleteIconId();
      final deleteButtonIconPngBase64 =
          await FloatingBallService.getCustomNotificationsDeleteIconPngBase64();
      final deleteButtonText =
          await FloatingBallService.getCustomNotificationsDeleteText();

      final fsBarHeightDp = await FloatingBallService.getFullScreenBarHeightDp();
      final fsBarBgColor = await FloatingBallService.getFullScreenBarBgColor();
      final fsBarIconSizeDp = await FloatingBallService.getFullScreenBarIconSizeDp();
      final fsBarTextSizeSp = await FloatingBallService.getFullScreenBarTextSizeSp();
      final fsBarPaddingHorzDp =
          await FloatingBallService.getFullScreenBarPaddingHorzDp();
      final fsBarPaddingVertDp =
          await FloatingBallService.getFullScreenBarPaddingVertDp();
      final fsBarTimeColor = await FloatingBallService.getFullScreenBarTimeColor();
      final fsBarWifiIconColor =
          await FloatingBallService.getFullScreenBarWifiIconColor();
      final fsBarBtIconColor = await FloatingBallService.getFullScreenBarBtIconColor();
      final fsBarDataIconColor =
          await FloatingBallService.getFullScreenBarDataIconColor();
      final fsBarLocIconColor = await FloatingBallService.getFullScreenBarLocIconColor();
      final fsBarBatteryIconColor =
          await FloatingBallService.getFullScreenBarBatteryIconColor();
      final fsBarBatteryTextColor =
          await FloatingBallService.getFullScreenBarBatteryTextColor();
      final fsBarRestoreIconColor =
          await FloatingBallService.getFullScreenBarRestoreIconColor();
      final fsBarRestoreBgColor =
          await FloatingBallService.getFullScreenBarRestoreBgColor();

      final fsBarWifiIconPngBase64 =
          await FloatingBallService.getFullScreenBarWifiIconPngBase64();
      final fsBarBtIconPngBase64 =
          await FloatingBallService.getFullScreenBarBtIconPngBase64();
      final fsBarDataIconPngBase64 =
          await FloatingBallService.getFullScreenBarDataIconPngBase64();
      final fsBarLocIconPngBase64 =
          await FloatingBallService.getFullScreenBarLocIconPngBase64();
      final fsBarBatteryIconPngBase64 =
          await FloatingBallService.getFullScreenBarBatteryIconPngBase64();
      final fsBarRestoreIconPngBase64 =
          await FloatingBallService.getFullScreenBarMediaRestoreIconPngBase64();

      final screenBgColor = await FloatingBallService.getCustomNotificationsBgColor();
      final itemBgColor = await FloatingBallService.getCustomNotificationsItemBgColor();
      final itemBorderColor =
          await FloatingBallService.getCustomNotificationsItemBorderColor();
      final titleColor = await FloatingBallService.getCustomNotificationsTitleColor();
      final textColor = await FloatingBallService.getCustomNotificationsTextColor();
      final titleSizeSp = await FloatingBallService.getCustomNotificationsTitleSizeSp();
      final textSizeSp = await FloatingBallService.getCustomNotificationsTextSizeSp();

      if (!mounted) return;
      setState(() {
        _fsBarEnabled = fsBarEnabled;
        _fsBgColor = fsBgColor;
        _fsContainerPaddingHorzDp = fsContainerPaddingHorzDp;
        _fsContainerPaddingVertDp = fsContainerPaddingVertDp;
        _fsIconSizeDp = fsIconSizeDp;
        _fsTextSizeSp = fsTextSizeSp;
        _fsStickyPaddingDp = fsStickyPaddingDp;
        _fsCloseSticky = fsCloseSticky;
        _fsCloseDisableStickyWhenMediaActive = fsCloseDisableStickyWhenMediaActive;
        _fsCloseHeightDp = fsCloseHeightDp;
        _fsCloseBgColor = fsCloseBgColor;
        _fsCloseTextColor = fsCloseTextColor;
        _fsCloseHideText = fsCloseHideText;
        _fsCloseIconId = fsCloseIconId;
        _fsCloseIconPngBase64 = fsCloseIconPngBase64;
        _fsCloseText = fsCloseText;
        _bottomButtonsIconHeightDp = bottomButtonsIconHeightDp;
        _deleteButtonIconId = deleteButtonIconId;
        _deleteButtonIconPngBase64 = deleteButtonIconPngBase64;
        _deleteButtonText = deleteButtonText;

        _fsBarHeightDp = fsBarHeightDp;
        _fsBarBgColor = fsBarBgColor;
        _fsBarIconSizeDp = fsBarIconSizeDp;
        _fsBarTextSizeSp = fsBarTextSizeSp;
        _fsBarPaddingHorzDp = fsBarPaddingHorzDp;
        _fsBarPaddingVertDp = fsBarPaddingVertDp;
        _fsBarTimeColor = fsBarTimeColor;
        _fsBarWifiIconColor = fsBarWifiIconColor;
        _fsBarBtIconColor = fsBarBtIconColor;
        _fsBarDataIconColor = fsBarDataIconColor;
        _fsBarLocIconColor = fsBarLocIconColor;
        _fsBarBatteryIconColor = fsBarBatteryIconColor;
        _fsBarBatteryTextColor = fsBarBatteryTextColor;
        _fsBarRestoreIconColor = fsBarRestoreIconColor;
        _fsBarRestoreBgColor = fsBarRestoreBgColor;
        _fsBarWifiIconPngBase64 = fsBarWifiIconPngBase64;
        _fsBarBtIconPngBase64 = fsBarBtIconPngBase64;
        _fsBarDataIconPngBase64 = fsBarDataIconPngBase64;
        _fsBarLocIconPngBase64 = fsBarLocIconPngBase64;
        _fsBarBatteryIconPngBase64 = fsBarBatteryIconPngBase64;
        _fsBarRestoreIconPngBase64 = fsBarRestoreIconPngBase64;
        _screenBgColor = screenBgColor;
        _itemBgColor = itemBgColor;
        _itemBorderColor = itemBorderColor;
        _titleColor = titleColor;
        _textColor = textColor;
        _titleSizeSp = titleSizeSp;
        _textSizeSp = textSizeSp;
      });
    } catch (_) {}
  }

  Future<void> _refreshSystemState() async {
    try {
      final dynamic res =
          await _floatingBallChannel.invokeMethod('getFsBarSystemState');
      final map = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      if (!mounted) return;
      final next = _SystemState(
        wifiEnabled: map['wifiEnabled'] == true,
        btEnabled: map['btEnabled'] == true,
        dataEnabled: map['dataEnabled'] == true,
        locationEnabled: map['locationEnabled'] == true,
        batteryPct: map['batteryPct'] is int ? map['batteryPct'] as int : null,
        showMediaRestore: map['showMediaRestore'] == true,
      );
      final prev = _systemState.value;
      if (prev != next) _systemState.value = next;
    } catch (_) {}
  }

  Future<bool> _ensureEmisorConnected() async {
    try {
      final dynamic enabled =
          await _emisorChannel.invokeMethod('isNotificationServiceEnabled');
      if (enabled != true) return false;

      final dynamic running = await _emisorChannel.invokeMethod('isServiceRunning');
      if (running == true) return true;

      await _emisorChannel.invokeMethod('rebindNotificationListener');
      await _emisorChannel.invokeMethod('startNotificationService');
      await Future.delayed(const Duration(milliseconds: 450));
      final dynamic running2 = await _emisorChannel.invokeMethod('isServiceRunning');
      return running2 == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refresh({bool showLoading = true}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final isRunning = await _ensureEmisorConnected();

      final dynamic res =
          await _emisorChannel.invokeMethod('getActiveNotifications');
      final List<dynamic> list = res is List ? res : <dynamic>[];
      final items = list
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList()
        ..sort((a, b) {
          final aT = (a['postTime'] as int?) ?? 0;
          final bT = (b['postTime'] as int?) ?? 0;
          return bT.compareTo(aT);
        });
      if (!mounted) return;
      setState(() {
        _items = items;
        if (!isRunning && items.isEmpty) {
          _error =
              'Activa el permiso de acceso a notificaciones para ver notificaciones del dispositivo.';
        } else if (showLoading) {
          _error = null;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _clearAll() async {
    try {
      await _ensureEmisorConnected();
      await _emisorChannel.invokeMethod('cancelAllActiveNotifications');
      await Future.delayed(const Duration(milliseconds: 220));
      await _refresh();
    } catch (_) {}
  }

  Future<void> _closeScreen() async {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<bool> _dismissByKey(String key) async {
    try {
      final dynamic ok = await _emisorChannel.invokeMethod(
        'cancelActiveNotification',
        <String, dynamic>{'key': key},
      );
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: Color(_titleColor),
      fontSize: _titleSizeSp.toDouble(),
      fontWeight: FontWeight.w600,
    );
    final textStyle = TextStyle(
      color: Color(_textColor),
      fontSize: _textSizeSp.toDouble(),
    );

    final scrollPadH = _fsContainerPaddingHorzDp.toDouble();
    final scrollPadV = _fsContainerPaddingVertDp.toDouble();
    final stickyPad = _fsStickyPaddingDp.toDouble();

    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: textStyle,
                  ),
                ),
              )
            : _items.isEmpty
                ? Center(
                    child: Text(
                      '',
                      style: textStyle,
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      scrollPadV,
                      0,
                      scrollPadV +
                          (_fsCloseSticky
                              ? (_fsCloseHeightDp.toDouble() + stickyPad + 16)
                              : 0),
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final key = (item['key'] ?? '').toString();
                      final appName = (item['appName'] ?? '').toString().trim();
                      final appIconBase64 =
                          (item['appIcon'] ?? '').toString().trim();
                      final title = (item['title'] ?? '').toString().trim();
                      final text = (item['text'] ?? '').toString().trim();
                      final subText = (item['subText'] ?? '').toString().trim();

                      final dismissKey = key.isNotEmpty ? ValueKey(key) : UniqueKey();
                      final lines = <String>[
                        if (title.isNotEmpty) title,
                        if (text.isNotEmpty) text,
                        if (subText.isNotEmpty) subText,
                      ];

                      Uint8List? appIconBytes;
                      if (appIconBase64.isNotEmpty) {
                        try {
                          appIconBytes = base64Decode(appIconBase64);
                        } catch (_) {}
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Dismissible(
                          key: dismissKey,
                          direction: DismissDirection.endToStart,
                          background: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            if (key.isEmpty) return false;
                            final ok = await _dismissByKey(key);
                            return ok;
                          },
                          onDismissed: (_) {
                            setState(() {
                              _items.removeAt(index);
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color(_itemBgColor),
                              border: Border.all(
                                color: Color(_itemBorderColor),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: scrollPadH, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (appIconBytes != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.memory(
                                      appIconBytes,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                if (appIconBytes != null) const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        appName.isNotEmpty ? appName : 'Notificación',
                                        style: titleStyle,
                                      ),
                                      if (lines.isNotEmpty) const SizedBox(height: 6),
                                      for (final line in lines)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(line, style: textStyle),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Color(_screenBgColor),
              ),
            ),
            Column(
              children: [
                if (_fsBarEnabled)
                  ValueListenableBuilder<_SystemState>(
                    valueListenable: _systemState,
                    builder: (context, s, _) {
                      return _FsBar(
                        heightDp: _fsBarHeightDp,
                        bgColor: _fsBarBgColor,
                        iconSizeDp: _fsBarIconSizeDp,
                        textSizeSp: _fsBarTextSizeSp,
                        paddingHorzDp: _fsBarPaddingHorzDp,
                        paddingVertDp: _fsBarPaddingVertDp,
                        timeColor: _fsBarTimeColor,
                        wifiIconColor: _fsBarWifiIconColor,
                        btIconColor: _fsBarBtIconColor,
                        dataIconColor: _fsBarDataIconColor,
                        locIconColor: _fsBarLocIconColor,
                        batteryIconColor: _fsBarBatteryIconColor,
                        batteryTextColor: _fsBarBatteryTextColor,
                        restoreIconColor: _fsBarRestoreIconColor,
                        restoreBgColor: _fsBarRestoreBgColor,
                        wifiIconPngBase64: _fsBarWifiIconPngBase64,
                        btIconPngBase64: _fsBarBtIconPngBase64,
                        dataIconPngBase64: _fsBarDataIconPngBase64,
                        locIconPngBase64: _fsBarLocIconPngBase64,
                        batteryIconPngBase64: _fsBarBatteryIconPngBase64,
                        restoreIconPngBase64: _fsBarRestoreIconPngBase64,
                        wifiEnabled: s.wifiEnabled,
                        btEnabled: s.btEnabled,
                        dataEnabled: s.dataEnabled,
                        locationEnabled: s.locationEnabled,
                        batteryPct: s.batteryPct,
                        showMediaRestore: s.showMediaRestore,
                      );
                    },
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: content is ListView
                        ? content
                        : ListView(
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.7,
                                child: content,
                              ),
                            ],
                          ),
                  ),
                ),
                if (!_fsCloseSticky)
                  ValueListenableBuilder<_SystemState>(
                    valueListenable: _systemState,
                    builder: (context, s, _) {
                      final closeEnabled =
                          !s.showMediaRestore || !_fsCloseDisableStickyWhenMediaActive;
                      if (!closeEnabled) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.fromLTRB(stickyPad, 0, stickyPad, stickyPad),
                        child: _BottomButtonsRow(
                          heightDp: _fsCloseHeightDp,
                          bgColor: _fsCloseBgColor,
                          textColor: _fsCloseTextColor,
                          hideText: _fsCloseHideText,
                          iconHeightDp: _bottomButtonsIconHeightDp,
                          closeIconId: _fsCloseIconId,
                          closeIconPngBase64: _fsCloseIconPngBase64,
                          closeText: _fsCloseText,
                          deleteIconId: _deleteButtonIconId,
                          deleteIconPngBase64: _deleteButtonIconPngBase64,
                          deleteText: _deleteButtonText,
                          textSizeSp: _fsTextSizeSp,
                          onClose: _closeScreen,
                          onClearAll: _clearAll,
                        ),
                      );
                    },
                  ),
              ],
            ),
            if (_fsCloseSticky)
              ValueListenableBuilder<_SystemState>(
                valueListenable: _systemState,
                builder: (context, s, _) {
                  final stickyCloseEnabled = _fsCloseSticky &&
                      (!s.showMediaRestore || !_fsCloseDisableStickyWhenMediaActive);
                  if (!stickyCloseEnabled) return const SizedBox.shrink();
                  return Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(stickyPad, 0, stickyPad, stickyPad),
                      child: _BottomButtonsRow(
                        heightDp: _fsCloseHeightDp,
                        bgColor: _fsCloseBgColor,
                        textColor: _fsCloseTextColor,
                        hideText: _fsCloseHideText,
                        iconHeightDp: _bottomButtonsIconHeightDp,
                        closeIconId: _fsCloseIconId,
                        closeIconPngBase64: _fsCloseIconPngBase64,
                        closeText: _fsCloseText,
                        deleteIconId: _deleteButtonIconId,
                        deleteIconPngBase64: _deleteButtonIconPngBase64,
                        deleteText: _deleteButtonText,
                        textSizeSp: _fsTextSizeSp,
                        onClose: _closeScreen,
                        onClearAll: _clearAll,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SystemState {
  final bool wifiEnabled;
  final bool btEnabled;
  final bool dataEnabled;
  final bool locationEnabled;
  final int? batteryPct;
  final bool showMediaRestore;

  const _SystemState({
    required this.wifiEnabled,
    required this.btEnabled,
    required this.dataEnabled,
    required this.locationEnabled,
    required this.batteryPct,
    required this.showMediaRestore,
  });

  static const _SystemState initial = _SystemState(
    wifiEnabled: false,
    btEnabled: false,
    dataEnabled: false,
    locationEnabled: false,
    batteryPct: null,
    showMediaRestore: false,
  );

  @override
  bool operator ==(Object other) {
    return other is _SystemState &&
        wifiEnabled == other.wifiEnabled &&
        btEnabled == other.btEnabled &&
        dataEnabled == other.dataEnabled &&
        locationEnabled == other.locationEnabled &&
        batteryPct == other.batteryPct &&
        showMediaRestore == other.showMediaRestore;
  }

  @override
  int get hashCode => Object.hash(
        wifiEnabled,
        btEnabled,
        dataEnabled,
        locationEnabled,
        batteryPct,
        showMediaRestore,
      );
}

class _FsBar extends StatefulWidget {
  final int heightDp;
  final int bgColor;
  final int iconSizeDp;
  final int textSizeSp;
  final int paddingHorzDp;
  final int paddingVertDp;
  final int timeColor;
  final int wifiIconColor;
  final int btIconColor;
  final int dataIconColor;
  final int locIconColor;
  final int batteryIconColor;
  final int batteryTextColor;
  final int restoreIconColor;
  final int restoreBgColor;
  final String? wifiIconPngBase64;
  final String? btIconPngBase64;
  final String? dataIconPngBase64;
  final String? locIconPngBase64;
  final String? batteryIconPngBase64;
  final String? restoreIconPngBase64;
  final bool wifiEnabled;
  final bool btEnabled;
  final bool dataEnabled;
  final bool locationEnabled;
  final int? batteryPct;
  final bool showMediaRestore;

  const _FsBar({
    super.key,
    required this.heightDp,
    required this.bgColor,
    required this.iconSizeDp,
    required this.textSizeSp,
    required this.paddingHorzDp,
    required this.paddingVertDp,
    required this.timeColor,
    required this.wifiIconColor,
    required this.btIconColor,
    required this.dataIconColor,
    required this.locIconColor,
    required this.batteryIconColor,
    required this.batteryTextColor,
    required this.restoreIconColor,
    required this.restoreBgColor,
    required this.wifiIconPngBase64,
    required this.btIconPngBase64,
    required this.dataIconPngBase64,
    required this.locIconPngBase64,
    required this.batteryIconPngBase64,
    required this.restoreIconPngBase64,
    required this.wifiEnabled,
    required this.btEnabled,
    required this.dataEnabled,
    required this.locationEnabled,
    required this.batteryPct,
    required this.showMediaRestore,
  });

  @override
  State<_FsBar> createState() => _FsBarState();
}

class _FsBarState extends State<_FsBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _tick = null;
    super.dispose();
  }

  String _formatTime(DateTime now) {
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Uint8List? _decodePng(String? raw) {
    final s = raw?.replaceAll(RegExp(r'\s+'), '').trim();
    if (s == null || s.isEmpty) return null;
    try {
      return base64Decode(s);
    } catch (_) {
      return null;
    }
  }

  Widget _pngOrIcon({
    required String? base64Png,
    required IconData fallback,
    required Color tint,
    required double size,
  }) {
    final bytes = _decodePng(base64Png);
    if (bytes == null) {
      return Icon(fallback, color: tint, size: size);
    }
    return Image.memory(
      bytes,
      width: size,
      height: size,
      color: tint,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (context, error, stackTrace) {
        return Icon(fallback, color: tint, size: size);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.iconSizeDp.toDouble();
    final now = DateTime.now();
    final time = _formatTime(now);
    final pctText =
        widget.batteryPct == null ? '—' : '${widget.batteryPct}%';

    return Container(
      height: widget.heightDp.toDouble(),
      color: Color(widget.bgColor),
      padding: EdgeInsets.symmetric(
        horizontal: widget.paddingHorzDp.toDouble(),
        vertical: widget.paddingVertDp.toDouble(),
      ),
      child: Row(
        children: [
          Text(
            time,
            style: TextStyle(
              color: Color(widget.timeColor),
              fontSize: widget.textSizeSp.toDouble(),
            ),
          ),
          const SizedBox(width: 10),
          if (widget.showMediaRestore)
            Container(
              width: size + 10,
              height: size + 10,
              decoration: BoxDecoration(
                color: Color(widget.restoreBgColor),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: _pngOrIcon(
                base64Png: widget.restoreIconPngBase64,
                fallback: Icons.play_arrow,
                tint: Color(widget.restoreIconColor),
                size: size,
              ),
            ),
          const Spacer(),
          if (widget.wifiEnabled)
            _pngOrIcon(
              base64Png: widget.wifiIconPngBase64,
              fallback: Icons.wifi,
              tint: Color(widget.wifiIconColor),
              size: size,
            ),
          if (widget.wifiEnabled) const SizedBox(width: 10),
          if (widget.btEnabled)
            _pngOrIcon(
              base64Png: widget.btIconPngBase64,
              fallback: Icons.bluetooth,
              tint: Color(widget.btIconColor),
              size: size,
            ),
          if (widget.btEnabled) const SizedBox(width: 10),
          if (widget.dataEnabled)
            _pngOrIcon(
              base64Png: widget.dataIconPngBase64,
              fallback: Icons.network_cell,
              tint: Color(widget.dataIconColor),
              size: size,
            ),
          if (widget.dataEnabled) const SizedBox(width: 10),
          if (widget.locationEnabled)
            _pngOrIcon(
              base64Png: widget.locIconPngBase64,
              fallback: Icons.location_on,
              tint: Color(widget.locIconColor),
              size: size,
            ),
          if (widget.locationEnabled) const SizedBox(width: 10),
          _pngOrIcon(
            base64Png: widget.batteryIconPngBase64,
            fallback: Icons.battery_full,
            tint: Color(widget.batteryIconColor),
            size: size,
          ),
          const SizedBox(width: 2),
          Text(
            pctText,
            style: TextStyle(
              color: Color(widget.batteryTextColor),
              fontSize: widget.textSizeSp.toDouble(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomButtonsRow extends StatelessWidget {
  final int heightDp;
  final int bgColor;
  final int textColor;
  final bool hideText;
  final int iconHeightDp;
  final String closeIconId;
  final String? closeIconPngBase64;
  final String closeText;
  final String deleteIconId;
  final String? deleteIconPngBase64;
  final String deleteText;
  final int textSizeSp;
  final VoidCallback onClose;
  final VoidCallback onClearAll;

  const _BottomButtonsRow({
    required this.heightDp,
    required this.bgColor,
    required this.textColor,
    required this.hideText,
    required this.iconHeightDp,
    required this.closeIconId,
    required this.closeIconPngBase64,
    required this.closeText,
    required this.deleteIconId,
    required this.deleteIconPngBase64,
    required this.deleteText,
    required this.textSizeSp,
    required this.onClose,
    required this.onClearAll,
  });

  Uint8List? _decodePng(String? raw) {
    final s = raw?.replaceAll(RegExp(r'\s+'), '').trim();
    if (s == null || s.isEmpty) return null;
    try {
      return base64Decode(s);
    } catch (_) {
      return null;
    }
  }

  Widget _iconWidget({
    required String iconId,
    required String? base64Png,
    required IconData fallback,
  }) {
    final bytes = _decodePng(base64Png);
    final tint = Color(textColor);
    final size = iconHeightDp.toDouble();
    if (bytes == null) {
      return Icon(fallback, color: tint, size: size);
    }
    return Image.memory(
      bytes,
      width: size,
      height: size,
      color: tint,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (context, error, stackTrace) {
        return Icon(fallback, color: tint, size: size);
      },
    );
  }

  Widget _button({
    required VoidCallback onTap,
    required String text,
    required bool hideText,
    required String iconId,
    required String? iconPngBase64,
    required IconData fallback,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: heightDp.toDouble(),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Color(bgColor),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x22FFFFFF), width: 1),
        ),
        alignment: Alignment.center,
        child: hideText
            ? _iconWidget(
                iconId: iconId,
                base64Png: iconPngBase64,
                fallback: fallback,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _iconWidget(
                    iconId: iconId,
                    base64Png: iconPngBase64,
                    fallback: fallback,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(textColor),
                        fontSize: textSizeSp.toDouble(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _button(
            onTap: onClose,
            text: closeText,
            hideText: hideText,
            iconId: closeIconId,
            iconPngBase64: closeIconPngBase64,
            fallback: Icons.close,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _button(
            onTap: onClearAll,
            text: deleteText,
            hideText: hideText,
            iconId: deleteIconId,
            iconPngBase64: deleteIconPngBase64,
            fallback: Icons.delete_forever,
          ),
        ),
      ],
    );
  }
}
