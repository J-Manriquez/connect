import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/services/ble_service.dart';
import 'package:connect/services/floating_ball_service.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/notification_cache_service.dart';
import 'package:connect/services/notification_filter_service.dart';
import 'package:connect/services/preferences_service.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class FloatingBallConversationAutoOpenEntry extends StatefulWidget {
  const FloatingBallConversationAutoOpenEntry({super.key});

  @override
  State<FloatingBallConversationAutoOpenEntry> createState() =>
      _FloatingBallConversationAutoOpenEntryState();
}

class _FloatingBallConversationAutoOpenEntryState
    extends State<FloatingBallConversationAutoOpenEntry> {
  static const MethodChannel _autoOpenChannel =
      MethodChannel('com.example.connect/auto_open');

  Map<String, dynamic>? _data;
  bool _startInConversationMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic> data = <String, dynamic>{};
    try {
      final dynamic res = await _autoOpenChannel.invokeMethod('getAutoOpenPayload');
      if (res is Map) data = Map<String, dynamic>.from(res);
    } catch (_) {}

    final pkg = (data['packageName'] ?? data['paquete'] ?? '').toString().trim();
    final title = (data['title'] ?? data['titulo'] ?? '').toString().trim();

    bool appConversationEnabled = false;
    try {
      final enabled = await PreferencesService.getConversationEnabledPackages();
      appConversationEnabled = enabled.contains(pkg);
    } catch (_) {}
    bool fsConversationEnabled = false;
    try {
      fsConversationEnabled =
          await FloatingBallService.isFullScreenConversationEnabled();
    } catch (_) {}

    final startInConversationMode = pkg.isNotEmpty &&
        title.isNotEmpty &&
        fsConversationEnabled &&
        appConversationEnabled;

    if (!mounted) return;
    setState(() {
      _data = data;
      _startInConversationMode = startInConversationMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF111111),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return FloatingBallConversationScreen(
      notificationData: data,
      startInConversationMode: _startInConversationMode,
      openedFromBackground: true,
    );
  }
}

class FloatingBallConversationScreen extends StatefulWidget {
  final Map<String, dynamic> notificationData;
  final bool startInConversationMode;
  final bool openedFromBackground;

  const FloatingBallConversationScreen({
    super.key,
    required this.notificationData,
    required this.startInConversationMode,
    this.openedFromBackground = false,
  });

  @override
  State<FloatingBallConversationScreen> createState() =>
      _FloatingBallConversationScreenState();
}

class _FloatingBallConversationScreenState
    extends State<FloatingBallConversationScreen> with WidgetsBindingObserver {
  static const MethodChannel _floatingBallChannel =
      MethodChannel('com.example.connect/floating_ball');

  final ReceptorService _receptorService = ReceptorService();
  final ValueNotifier<_SystemState> _systemState =
      ValueNotifier<_SystemState>(_SystemState.initial);
  Timer? _systemTick;

  bool _fsBarEnabled = false;
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

  int _notifsBgColor = 0xDD111111;
  int _notifsItemBgColor = 0x22111111;
  int _notifsItemBorderColor = 0x22FFFFFF;
  int _notifsTitleColor = 0xFFFFFFFF;
  int _notifsTextColor = 0xFFFFFFFF;
  int _notifsTitleSizeSp = 16;
  int _notifsTextSizeSp = 14;

  int _convBgColor = 0xDD111111;
  int _convIncomingColor = 0x22111111;
  int _convOutgoingColor = 0x22FFFFFF;
  int _convTextColor = 0xFFFFFFFF;
  int _convTextSizeSp = 14;
  int _convTitleColor = 0xFFFFFFFF;
  int _convTitleSizeSp = 16;

  int _convCloseHeightDp = 52;
  int _convCloseBgColor = 0xFFDC2626;
  int _convCloseTextColor = 0xFFFFFFFF;
  int _convCloseBorderColor = 0x22FFFFFF;
  bool _convCloseHideText = false;
  String _convCloseText = 'Cerrar';
  String? _convCloseIconPngBase64;

  int _convReplyHeightDp = 52;
  int _convReplyBgColor = 0xFF202020;
  int _convReplyTextColor = 0xFFFFFFFF;
  int _convReplyBorderColor = 0x22FFFFFF;
  bool _convReplyHideText = false;
  String _convReplyText = 'Responder';
  String? _convReplyIconPngBase64;
  int _convBottomButtonsGapDp = 10;
  int _convBottomButtonsPaddingHorzDp = 14;
  int _convBottomButtonsPaddingVertDp = 10;
  int _convHeaderAppIconSizeDp = 34;
  int _convCloseIconSizeDp = 20;
  int _convReplyIconSizeDp = 20;
  int _convReplyModalBgColor = 0xFF111111;
  int _convReplyModalTextColor = 0xFFFFFFFF;
  int _convReplyModalTextSizeSp = 16;
  String? _convReplyModalSendIconPngBase64;
  int _convReplyModalSendIconSizeDp = 22;
  int _convReplyModalSendBgColor = 0x00000000;
  int _convReplyModalSendBorderColor = 0x22FFFFFF;

  String _conversationTitle = '';
  String _packageName = '';
  String _appIconBase64 = '';
  Uint8List? _appIconBytes;
  String _selectedMessageId = '';

  bool _isConversationMode = false;
  bool _isConversationLoading = false;
  bool _isConversationPaging = false;
  bool _isReplySending = false;
  String? _replyStatusText;
  Timer? _replyStatusTimer;

  List<Map<String, dynamic>> _allConversationMessages = [];
  int _windowStart = 0;
  int _windowEnd = 0;
  final ScrollController _conversationScrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  bool _visibilityCheckScheduled = false;
  final Set<String> _visibilityMarked = {};
  final Set<String> _hiddenMessageIds = {};
  int _lastBtDebugMs = 0;
  String _lastBtDebugSig = '';

  bool _mediaVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStyle();
    _initMediaVisibility();
    _refreshSystemState();
    _systemTick = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshSystemState();
    });
    _conversationScrollController.addListener(_onConversationScroll);
    _initModeAndMaybeLoad();
  }

  Future<void> _initMediaVisibility() async {
    try {
      final autoShow = await FloatingBallService.isFullScreenMediaAutoShowEnabled();
      print('[floating_ball_conversation] mediaVisible init autoShow=$autoShow');
      if (!mounted) return;
      setState(() {
        _mediaVisible = autoShow;
      });
    } catch (e) {
      print('[floating_ball_conversation] mediaVisible init error=$e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _systemTick?.cancel();
    _systemTick = null;
    _systemState.dispose();
    _replyStatusTimer?.cancel();
    _replyStatusTimer = null;
    _conversationScrollController.removeListener(_onConversationScroll);
    _conversationScrollController.dispose();
    super.dispose();
  }

  void _setReplyStatus(String? text) {
    _replyStatusTimer?.cancel();
    _replyStatusTimer = null;
    if (!mounted) return;
    setState(() {
      _replyStatusText = text;
    });
    if (text == null || text.isEmpty) return;
    _replyStatusTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _replyStatusText = null;
      });
    });
  }

  Future<void> _loadStyle() async {
    try {
      final fsBarEnabled = await FloatingBallService.isFullScreenBarEnabled();
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

      final notifsBgColor = await FloatingBallService.getCustomNotificationsBgColor();
      final notifsItemBgColor =
          await FloatingBallService.getCustomNotificationsItemBgColor();
      final notifsItemBorderColor =
          await FloatingBallService.getCustomNotificationsItemBorderColor();
      final notifsTitleColor =
          await FloatingBallService.getCustomNotificationsTitleColor();
      final notifsTextColor =
          await FloatingBallService.getCustomNotificationsTextColor();
      final notifsTitleSizeSp =
          await FloatingBallService.getCustomNotificationsTitleSizeSp();
      final notifsTextSizeSp =
          await FloatingBallService.getCustomNotificationsTextSizeSp();

      final convBgColor = await FloatingBallService.getConversationBgColor();
      final convIncomingColor = await FloatingBallService.getConversationIncomingColor();
      final convOutgoingColor = await FloatingBallService.getConversationOutgoingColor();
      final convTextColor = await FloatingBallService.getConversationTextColor();
      final convTextSizeSp = await FloatingBallService.getConversationTextSizeSp();
      final convTitleColor = await FloatingBallService.getConversationTitleColor();
      final convTitleSizeSp = await FloatingBallService.getConversationTitleSizeSp();

      final closeHeightDp = await FloatingBallService.getConversationCloseHeightDp();
      final closeBgColor = await FloatingBallService.getConversationCloseBgColor();
      final closeTextColor = await FloatingBallService.getConversationCloseTextColor();
      final closeBorderColor =
          await FloatingBallService.getConversationCloseBorderColor();
      final closeHideText = await FloatingBallService.isConversationCloseHideTextEnabled();
      final closeText = await FloatingBallService.getConversationCloseText();
      final closeIconPngBase64 =
          await FloatingBallService.getConversationCloseIconPngBase64();

      final replyHeightDp = await FloatingBallService.getConversationReplyHeightDp();
      final replyBgColor = await FloatingBallService.getConversationReplyBgColor();
      final replyTextColor = await FloatingBallService.getConversationReplyTextColor();
      final replyBorderColor =
          await FloatingBallService.getConversationReplyBorderColor();
      final replyHideText = await FloatingBallService.isConversationReplyHideTextEnabled();
      final replyText = await FloatingBallService.getConversationReplyText();
      final replyIconPngBase64 =
          await FloatingBallService.getConversationReplyIconPngBase64();
      final bottomButtonsGapDp =
          await FloatingBallService.getConversationBottomButtonsGapDp();
      final bottomButtonsPaddingHorzDp =
          await FloatingBallService.getConversationBottomButtonsPaddingHorzDp();
      final bottomButtonsPaddingVertDp =
          await FloatingBallService.getConversationBottomButtonsPaddingVertDp();
      final headerAppIconSizeDp =
          await FloatingBallService.getConversationHeaderAppIconSizeDp();
      final closeIconSizeDp = await FloatingBallService.getConversationCloseIconSizeDp();
      final replyIconSizeDp = await FloatingBallService.getConversationReplyIconSizeDp();

      final replyModalBgColor =
          await FloatingBallService.getConversationReplyModalBgColor();
      final replyModalTextColor =
          await FloatingBallService.getConversationReplyModalTextColor();
      final replyModalTextSizeSp =
          await FloatingBallService.getConversationReplyModalTextSizeSp();
      final replyModalSendIconPngBase64 =
          await FloatingBallService.getConversationReplyModalSendIconPngBase64();
      final replyModalSendIconSizeDp =
          await FloatingBallService.getConversationReplyModalSendIconSizeDp();
      final replyModalSendBgColor =
          await FloatingBallService.getConversationReplyModalSendBgColor();
      final replyModalSendBorderColor =
          await FloatingBallService.getConversationReplyModalSendBorderColor();

      if (!mounted) return;
      setState(() {
        _fsBarEnabled = fsBarEnabled;
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

        _notifsBgColor = notifsBgColor;
        _notifsItemBgColor = notifsItemBgColor;
        _notifsItemBorderColor = notifsItemBorderColor;
        _notifsTitleColor = notifsTitleColor;
        _notifsTextColor = notifsTextColor;
        _notifsTitleSizeSp = notifsTitleSizeSp;
        _notifsTextSizeSp = notifsTextSizeSp;

        _convBgColor = convBgColor;
        _convIncomingColor = convIncomingColor;
        _convOutgoingColor = convOutgoingColor;
        _convTextColor = convTextColor;
        _convTextSizeSp = convTextSizeSp;
        _convTitleColor = convTitleColor;
        _convTitleSizeSp = convTitleSizeSp;

        _convCloseHeightDp = closeHeightDp;
        _convCloseBgColor = closeBgColor;
        _convCloseTextColor = closeTextColor;
        _convCloseBorderColor = closeBorderColor;
        _convCloseHideText = closeHideText;
        _convCloseText = closeText;
        _convCloseIconPngBase64 = closeIconPngBase64;

        _convReplyHeightDp = replyHeightDp;
        _convReplyBgColor = replyBgColor;
        _convReplyTextColor = replyTextColor;
        _convReplyBorderColor = replyBorderColor;
        _convReplyHideText = replyHideText;
        _convReplyText = replyText;
        _convReplyIconPngBase64 = replyIconPngBase64;
        _convBottomButtonsGapDp = bottomButtonsGapDp;
        _convBottomButtonsPaddingHorzDp = bottomButtonsPaddingHorzDp;
        _convBottomButtonsPaddingVertDp = bottomButtonsPaddingVertDp;
        _convHeaderAppIconSizeDp = headerAppIconSizeDp;
        _convCloseIconSizeDp = closeIconSizeDp;
        _convReplyIconSizeDp = replyIconSizeDp;
        _convReplyModalBgColor = replyModalBgColor;
        _convReplyModalTextColor = replyModalTextColor;
        _convReplyModalTextSizeSp = replyModalTextSizeSp;
        _convReplyModalSendIconPngBase64 = replyModalSendIconPngBase64;
        _convReplyModalSendIconSizeDp = replyModalSendIconSizeDp;
        _convReplyModalSendBgColor = replyModalSendBgColor;
        _convReplyModalSendBorderColor = replyModalSendBorderColor;
      });
    } catch (_) {}
  }

  Future<void> _refreshSystemState() async {
    try {
      final dynamic res =
          await _floatingBallChannel.invokeMethod('getFsBarSystemState');
      final map =
          res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      if (!mounted) return;
      final next = _SystemState(
        wifiEnabled: map['wifiEnabled'] == true,
        btEnabled: map['btEnabled'] == true,
        dataEnabled: map['dataEnabled'] == true,
        locationEnabled: map['locationEnabled'] == true,
        batteryPct: map['batteryPct'] is int ? map['batteryPct'] as int : null,
        showMediaRestore: map['showMediaRestore'] == true,
      );
      if (_systemState.value != next) _systemState.value = next;
    } catch (_) {}
  }

  Future<void> _initModeAndMaybeLoad() async {
    final pkg = _getFieldValue(['packageName', 'paquete'])?.trim() ?? '';
    final title = _getFieldValue(['title', 'titulo'])?.trim() ?? '';
    final selectedMessageId = (widget.notificationData['notificationId'] ??
            widget.notificationData['id'] ??
            '')
        .toString()
        .trim();

    String appIconBase64 =
        (widget.notificationData['appIcon'] ?? widget.notificationData['icon'] ?? '')
            .toString()
            .trim();
    if (appIconBase64.isEmpty && pkg.isNotEmpty) {
      try {
        final List<dynamic> result =
            await NotificationFilterService.platform.invokeMethod(
          'getInstalledApps',
        );
        for (final item in result) {
          final m = Map<String, dynamic>.from(item as Map);
          if ((m['packageName'] ?? '').toString().trim() == pkg) {
            final icon = (m['icon'] ?? '').toString().trim();
            if (icon.isNotEmpty) {
              appIconBase64 = icon;
              break;
            }
          }
        }
      } catch (_) {}
    }

    bool appConversationEnabled = false;
    try {
      final enabled = await PreferencesService.getConversationEnabledPackages();
      appConversationEnabled = enabled.contains(pkg);
    } catch (_) {}
    bool fsConversationEnabled = false;
    try {
      fsConversationEnabled = await FloatingBallService.isFullScreenConversationEnabled();
    } catch (_) {}

    final conversationMode = widget.startInConversationMode &&
        pkg.isNotEmpty &&
        title.isNotEmpty &&
        fsConversationEnabled &&
        appConversationEnabled;

    final iconRaw = appIconBase64.trim();
    final commaIdx = iconRaw.lastIndexOf(',');
    final iconPayload = commaIdx >= 0 ? iconRaw.substring(commaIdx + 1) : iconRaw;
    final iconBase64Clean =
        iconPayload.replaceAll(RegExp(r'\s+'), '').trim();
    Uint8List? iconBytes;
    if (iconBase64Clean.isNotEmpty) {
      try {
        iconBytes = base64Decode(iconBase64Clean);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _packageName = pkg;
      _conversationTitle = title;
      _selectedMessageId = selectedMessageId;
      _appIconBase64 = iconBase64Clean;
      _appIconBytes = iconBytes;
      _isConversationMode = conversationMode;
    });

    _markAsRead();

    if (_isConversationMode) {
      await _loadConversationMessages();
    }
  }

  Future<void> _markAsRead() async {
    try {
      final notificationId =
          (widget.notificationData['notificationId'] ?? widget.notificationData['id'])
              ?.toString();
      if (notificationId != null && notificationId.isNotEmpty) {
        await NotificationCacheService.markAsVisualized(notificationId);
        await BtHiveStorageService.markVisualized(notificationId, true);
        await _receptorService.updateNotificationVisualizationStatus(
          notificationId,
          true,
        );
        widget.notificationData['status-visualizacion'] = true;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {});
  }

  String? _getFieldValue(List<String> fieldNames) {
    for (final fieldName in fieldNames) {
      final value = widget.notificationData[fieldName];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  void _btDebug(
    String message, {
    required String sig,
    required int throttleMs,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (throttleMs > 0) {
      if (_lastBtDebugSig == sig && (now - _lastBtDebugMs) < throttleMs) {
        return;
      }
    }
    _lastBtDebugSig = sig;
    _lastBtDebugMs = now;
    try {
      unawaited(
        BleService.sendBtServerMessage({
          'type': 'debug_log',
          'source': 'floating_ball_conversation',
          'message': message,
          'timestamp': now,
        }),
      );
    } catch (_) {}
  }

  Widget _buildHeader() {
    final title = _getFieldValue(['title', 'titulo']) ?? 'Sin título';
    final titleStyle = TextStyle(
      color:
          _isConversationMode ? Color(_convTitleColor) : Color(_notifsTitleColor),
      fontSize:
          (_isConversationMode ? _convTitleSizeSp : _notifsTitleSizeSp).toDouble(),
      fontWeight: FontWeight.w600,
    );
    final hasIcon = _appIconBase64.isNotEmpty;
    final iconBytes = _appIconBytes;
    final iconSize = _convHeaderAppIconSizeDp.toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (iconBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          iconBytes,
                          width: iconSize,
                          height: iconSize,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                    if (iconBytes == null && hasIcon)
                      SizedBox(width: iconSize, height: iconSize),
                    if (iconBytes != null || hasIcon) const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: (constraints.maxWidth - iconSize - 10)
                            .clamp(120.0, constraints.maxWidth),
                      ),
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: titleStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isConversationMode ? _convBgColor : _notifsBgColor;
    return Scaffold(
      backgroundColor:
          widget.openedFromBackground ? Color(bgColor) : Colors.transparent,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Color(bgColor),
              ),
            ),
            Column(
              children: [
                if (_fsBarEnabled)
                  ValueListenableBuilder<_SystemState>(
                    valueListenable: _systemState,
                    builder: (context, s, _) {
                      return RepaintBoundary(
                        child: _FsBar(
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
                          onMediaPressed: () {
                            final next = !_mediaVisible;
                            print('[floating_ball_conversation] mediaVisible -> $next (from fsBar)');
                            setState(() {
                              _mediaVisible = next;
                            });
                          },
                        ),
                      );
                    },
                  ),
                RepaintBoundary(child: _buildHeader()),
                Expanded(
                  child: _isConversationMode
                      ? _buildConversationBody()
                      : _buildNotificationBody(),
                ),
                _buildBottomBar(),
              ],
            ),
          
          ],
        ),
      ),
    );
  }

  Uint8List? _decodePngBytes(String? raw) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return null;
    final commaIdx = s.lastIndexOf(',');
    final payload = commaIdx >= 0 ? s.substring(commaIdx + 1) : s;
    final cleaned = payload.replaceAll(RegExp(r'\s+'), '').trim();
    if (cleaned.isEmpty) return null;
    try {
      return base64Decode(cleaned);
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
    final bytes = _decodePngBytes(base64Png);
    if (bytes == null) return Icon(fallback, color: tint, size: size);
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

  Widget _bottomActionButton({
    required VoidCallback? onTap,
    required int heightDp,
    required int bgColor,
    required int borderColor,
    required int textColor,
    required bool hideText,
    required String text,
    required String? iconPngBase64,
    required IconData fallback,
    required int iconSizeDp,
  }) {
    final fg = Color(textColor);
    final ink = Ink(
      decoration: BoxDecoration(
        color: Color(bgColor),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(borderColor), width: 1),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: heightDp.toDouble()),
        child: Center(
          child: hideText
              ? _pngOrIcon(
                  base64Png: iconPngBase64,
                  fallback: fallback,
                  tint: fg,
                  size: iconSizeDp.toDouble(),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _pngOrIcon(
                      base64Png: iconPngBase64,
                      fallback: fallback,
                      tint: fg,
                      size: iconSizeDp.toDouble(),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    return Opacity(
      opacity: onTap == null ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ink,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final contentColor =
        _isConversationMode ? Color(_convTextColor) : Color(_notifsTextColor);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _convBottomButtonsPaddingHorzDp.toDouble(),
          vertical: _convBottomButtonsPaddingVertDp.toDouble(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_replyStatusText != null && _replyStatusText!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  _replyStatusText!,
                  style: TextStyle(
                    color: contentColor.withOpacity(0.9),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: _bottomActionButton(
                    onTap: () async {
                      if (widget.openedFromBackground) {
                        SystemNavigator.pop();
                        return;
                      }
                      Navigator.of(context).maybePop();
                    },
                    heightDp: _convCloseHeightDp,
                    bgColor: _convCloseBgColor,
                    borderColor: _convCloseBorderColor,
                    textColor: _convCloseTextColor,
                    hideText: _convCloseHideText,
                    text: _convCloseText,
                    iconPngBase64: _convCloseIconPngBase64,
                    fallback: Icons.close,
                    iconSizeDp: _convCloseIconSizeDp,
                  ),
                ),
                if (_isConversationMode) ...[
                  SizedBox(width: _convBottomButtonsGapDp.toDouble()),
                  Expanded(
                    child: _bottomActionButton(
                      onTap: _isReplySending ? null : _openReplyDialog,
                      heightDp: _convReplyHeightDp,
                      bgColor: _convReplyBgColor,
                      borderColor: _convReplyBorderColor,
                      textColor: _convReplyTextColor,
                      hideText: _convReplyHideText,
                      text: _isReplySending ? 'Enviando…' : _convReplyText,
                      iconPngBase64: _convReplyIconPngBase64,
                      fallback: Icons.reply,
                      iconSizeDp: _convReplyIconSizeDp,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBody() {
    final title = _getFieldValue(['title', 'titulo']) ?? 'Sin título';
    final body =
        _getFieldValue(['text', 'body', 'bigText', 'mensaje', 'contenido']) ??
            'Sin contenido';
    final appName =
        _getFieldValue(['appName', 'aplicacion']) ?? 'Aplicación desconocida';

    String formattedTime = 'Hora no disponible';
    try {
      final notificationId =
          (widget.notificationData['notificationId'] ?? widget.notificationData['id'])
              ?.toString();
      if (notificationId != null) {
        final timestamp = int.tryParse(notificationId.split('_')[0]);
        if (timestamp != null) {
          final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          formattedTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
        }
      }
    } catch (_) {}

    final cardDeco = BoxDecoration(
      color: Color(_notifsItemBgColor),
      border: Border.all(color: Color(_notifsItemBorderColor), width: 1),
      borderRadius: BorderRadius.circular(14),
    );

    final titleStyle = TextStyle(
      color: Color(_notifsTitleColor),
      fontSize: _notifsTitleSizeSp.toDouble(),
      fontWeight: FontWeight.w600,
    );
    final textStyle = TextStyle(
      color: Color(_notifsTextColor),
      fontSize: _notifsTextSizeSp.toDouble(),
    );

    final visualized = widget.notificationData['status-visualizacion'] == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      children: [
        Container(
          decoration: cardDeco,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Contenido Principal', style: titleStyle),
              const SizedBox(height: 10),
              Text('Título', style: titleStyle.copyWith(fontSize: 14)),
              const SizedBox(height: 4),
              Text(title, style: textStyle),
              const SizedBox(height: 10),
              Text('Mensaje', style: titleStyle.copyWith(fontSize: 14)),
              const SizedBox(height: 4),
              Text(body, style: textStyle),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: visualized ? null : _markAsRead,
                  icon: const Icon(Icons.done),
                  label: Text(
                    visualized ? 'Marcado como leído' : 'Marcar como leído',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF202020),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: cardDeco,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Información de la Aplicación', style: titleStyle),
              const SizedBox(height: 10),
              Text('Aplicación: $appName', style: textStyle),
              const SizedBox(height: 6),
              Text('Fecha y Hora: $formattedTime', style: textStyle),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/configure_notification',
                      arguments: widget.notificationData,
                    );
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Configuración personalizada'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF202020),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConversationBody() {
    if (_isConversationLoading && _allConversationMessages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final messages = _currentWindowMessages();
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No hay mensajes para mostrar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(_convTextColor),
              fontSize: _convTextSizeSp.toDouble(),
            ),
          ),
        ),
      );
    }

    final items = _buildConversationItems(messages);

    return Column(
      children: [
        if (_isConversationPaging) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView.builder(
            controller: _conversationScrollController,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item.isDateSeparator) {
                return _buildDateSeparator(item.dateLabel);
              }
              return _buildConversationMessageTile(item.message!);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Color(_convTextColor).withOpacity(0.9),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationMessageTile(Map<String, dynamic> message) {
    final id = _messageId(message);
    final key = _messageKeys.putIfAbsent(id, () => GlobalKey());
    final content = _extractMessageBody(message);
    final time = _formatMessageTime(message);
    final visualized = message['status-visualizacion'] == true;

    final extrasRaw = message['extras'];
    final extras =
        extrasRaw is Map ? Map<String, dynamic>.from(extrasRaw) : <String, dynamic>{};
    final isOutgoing = (extras['direction'] ?? '').toString().trim() == 'out';
    const horizontal = 32.0;

    final bubbleBg = isOutgoing ? Color(_convOutgoingColor) : Color(_convIncomingColor);
    final bubbleTextStyle = TextStyle(
      color: Color(_convTextColor),
      fontSize: _convTextSizeSp.toDouble(),
    );

    return SizedBox(
      key: key,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: GestureDetector(
          onLongPress: () => _showMessageActionsDialog(message),
          child: Row(
            mainAxisAlignment:
                isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  margin: EdgeInsets.only(
                    left: isOutgoing ? horizontal : 0,
                    right: isOutgoing ? 0 : horizontal,
                  ),
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(content, style: bubbleTextStyle),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(_convTextColor).withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            visualized ? Icons.done : Icons.done_outline,
                            size: 16,
                            color: visualized ? Colors.green : Colors.white54,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteConversationMessage(Map<String, dynamic> message) async {
    final id = _messageId(message);
    if (id.isEmpty) return;

    final extrasRaw = message['extras'];
    final extras =
        extrasRaw is Map ? Map<String, dynamic>.from(extrasRaw) : <String, dynamic>{};
    final isReply = extras['isReply'] == true || id.startsWith('reply_');

    _hiddenMessageIds.add(id);
    if (mounted) {
      setState(() {
        _allConversationMessages =
            _allConversationMessages.where((m) => _messageId(m) != id).toList();
        _windowEnd = _allConversationMessages.length;
        _windowStart = (_windowEnd - 15).clamp(0, _windowEnd);
        _messageKeys.clear();
      });
    }

    try {
      if (isReply) {
        await BtHiveStorageService.deleteConversationReplyById(id);
      } else {
        await FirebaseService().deleteNotification(id, '');
        await BtHiveStorageService.deleteOutboxEntry(id);
      }
    } catch (_) {}

    try {
      await _loadConversationMessages();
    } catch (_) {}
  }

  Future<void> _showMessageActionsDialog(Map<String, dynamic> message) async {
    final visualized = message['status-visualizacion'] == true;
    final extrasRaw = message['extras'];
    final extras =
        extrasRaw is Map ? Map<String, dynamic>.from(extrasRaw) : <String, dynamic>{};
    final id = _messageId(message);
    final isReply = extras['isReply'] == true || id.startsWith('reply_');
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('Opciones'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.done),
                title: const Text('Marcar como leído'),
                enabled: !visualized,
                onTap: visualized
                    ? null
                    : () async {
                        Navigator.of(context).pop();
                        await _markNotificationMapAsRead(message);
                      },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: Text(isReply ? 'Eliminar respuesta' : 'Eliminar mensaje'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _deleteConversationMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Configuración personalizada'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.pushNamed(
                    this.context,
                    '/configure_notification',
                    arguments: message,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openReplyDialog() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final controller = TextEditingController();
        final mq = MediaQuery.of(this.context);
        final containerRadius = BorderRadius.circular(18);

        Widget panel() {
          final modalTextColor = Color(_convReplyModalTextColor);
          final modalTextStyle = TextStyle(
            color: modalTextColor,
            fontSize: _convReplyModalTextSizeSp.toDouble(),
          );
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Material(
              color: Color(_convReplyModalBgColor),
              borderRadius: containerRadius,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Responder',
                      style: modalTextStyle.copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            autofocus: true,
                            style: modalTextStyle,
                            decoration: InputDecoration(
                              hintText: 'Escribe una respuesta…',
                              hintStyle: modalTextStyle.copyWith(
                                color: modalTextColor.withOpacity(0.6),
                              ),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) {
                              final trimmed = controller.text.trim();
                              if (trimmed.isEmpty) return;
                              Navigator.of(context).pop(trimmed);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            final trimmed = controller.text.trim();
                            if (trimmed.isEmpty) return;
                            Navigator.of(context).pop(trimmed);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color(_convReplyModalSendBgColor),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Color(_convReplyModalSendBorderColor),
                                width: 1,
                              ),
                            ),
                            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                            alignment: Alignment.center,
                            child: _pngOrIcon(
                              base64Png: _convReplyModalSendIconPngBase64,
                              fallback: Icons.send,
                              tint: modalTextColor,
                              size: _convReplyModalSendIconSizeDp.toDouble(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: SizedBox(
            height: mq.size.height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: panel(),
                ),
              ),
            ),
          ),
        );
      },
    );

    final trimmed = (text ?? '').trim();
    if (trimmed.isEmpty) return;
    await _sendConversationReply(trimmed);
  }

  void _onConversationScroll() {
    _maybeLoadMoreConversation();
    _scheduleVisibilityCheck();
  }

  void _scheduleVisibilityCheck() {
    if (_visibilityCheckScheduled) return;
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      _markVisibleMessagesAsRead();
    });
  }

  void _markVisibleMessagesAsRead() {
    if (!_conversationScrollController.hasClients) return;
    if (_allConversationMessages.isEmpty) return;
    final pos = _conversationScrollController.position;
    final viewport = pos.viewportDimension;
    if (viewport <= 0) return;

    final start = pos.pixels;
    final end = pos.pixels + viewport;
    for (final entry in _messageKeys.entries) {
      final messageId = entry.key;
      if (messageId.isEmpty) continue;
      if (_visibilityMarked.contains(messageId)) continue;
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox) continue;
      final offset = box.localToGlobal(Offset.zero);
      final y = offset.dy;
      final h = box.size.height;
      final visible = (y + h) >= 0 && y <= MediaQuery.sizeOf(context).height;
      if (!visible) continue;
      _visibilityMarked.add(messageId);
      try {
        final msg = _allConversationMessages.firstWhere(
          (m) => _messageId(m) == messageId,
          orElse: () => const <String, dynamic>{},
        );
        if (msg.isNotEmpty) {
          unawaited(_markNotificationMapAsRead(msg));
        }
      } catch (_) {}
    }
    if (start > end) {}
  }

  Future<void> _markNotificationMapAsRead(Map<String, dynamic> message) async {
    if (message['status-visualizacion'] == true) return;
    try {
      final notificationId = (message['notificationId'] ?? message['id'])?.toString();
      if (notificationId == null || notificationId.isEmpty) return;
      await NotificationCacheService.markAsVisualized(notificationId);
      await BtHiveStorageService.markVisualized(notificationId, true);
      await _receptorService.updateNotificationVisualizationStatus(
        notificationId,
        true,
      );
    } catch (_) {}
    message['status-visualizacion'] = true;
    if (!mounted) return;
    setState(() {});
  }

  void _maybeLoadMoreConversation() {
    if (_isConversationLoading) return;
    if (_isConversationPaging) return;
    if (_allConversationMessages.isEmpty) return;
    if (!_conversationScrollController.hasClients) return;

    const threshold = 120.0;
    final pos = _conversationScrollController.position;

    if (pos.pixels <= threshold) {
      final canExpand = _windowStart > 0;
      if (!canExpand) return;

      final prevMax = pos.maxScrollExtent;
      final prevPixels = pos.pixels;
      final newStart = (_windowStart - 5).clamp(0, _windowStart);

      setState(() {
        _isConversationPaging = true;
        _windowStart = newStart;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_conversationScrollController.hasClients) return;
        final newMax = _conversationScrollController.position.maxScrollExtent;
        final delta = newMax - prevMax;
        final target = (prevPixels + delta).clamp(
          0.0,
          _conversationScrollController.position.maxScrollExtent,
        );
        _conversationScrollController.jumpTo(target);
        _scheduleVisibilityCheck();
        if (!mounted) return;
        setState(() {
          _isConversationPaging = false;
        });
      });
    } else if (pos.pixels >= pos.maxScrollExtent - threshold) {
      final canExpand = _windowEnd < _allConversationMessages.length;
      if (!canExpand) return;

      final newEnd = (_windowEnd + 5).clamp(
        _windowEnd,
        _allConversationMessages.length,
      );
      setState(() {
        _isConversationPaging = true;
        _windowEnd = newEnd;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleVisibilityCheck();
        if (!mounted) return;
        setState(() {
          _isConversationPaging = false;
        });
      });
    }
  }

  Future<void> _loadConversationMessages() async {
    if (_isConversationLoading) return;
    setState(() {
      _isConversationLoading = true;
    });

    try {
      _btDebug(
        '_loadConversationMessages start pkg=$_packageName title=$_conversationTitle selectedId=$_selectedMessageId',
        sig: 'loadStart:$_packageName:$_conversationTitle:$_selectedMessageId',
        throttleMs: 0,
      );
      final remote = await _receptorService.fetchAllNotificationsAcrossDaysRawOnce();

      List<Map<String, dynamic>> localReplies = const [];
      try {
        localReplies = await BtHiveStorageService.getConversationRepliesForUi(
          packageName: _packageName,
          conversationTitle: _conversationTitle,
        );
      } catch (_) {
        localReplies = const [];
      }
      if (localReplies.isNotEmpty && _hiddenMessageIds.isNotEmpty) {
        localReplies =
            localReplies.where((m) => !_hiddenMessageIds.contains(_messageId(m))).toList();
      }

      final conversationTitleNorm = _normalizeConversationKey(_conversationTitle);
      List<Map<String, dynamic>> filtered = remote.where((n) {
        if (_hiddenMessageIds.contains(_messageId(n))) return false;
        final pkg = _stringFromMessage(n, ['packageName', 'paquete']);
        final t = _stringFromMessage(n, ['title', 'titulo']);
        return pkg == _packageName && t == _conversationTitle;
      }).map((e) => Map<String, dynamic>.from(e)).toList();

      if (filtered.length <= 1) {
        filtered = remote.where((n) {
          if (_hiddenMessageIds.contains(_messageId(n))) return false;
          final pkg = _stringFromMessage(n, ['packageName', 'paquete']);
          if (pkg != _packageName) return false;
          final t = _stringFromMessage(n, ['title', 'titulo']);
          final tNorm = _normalizeConversationKey(t);
          if (conversationTitleNorm.isEmpty || tNorm.isEmpty) return false;
          if (conversationTitleNorm == tNorm) return true;
          if (conversationTitleNorm.length < 3 || tNorm.length < 3) return false;
          return conversationTitleNorm.contains(tNorm) ||
              tNorm.contains(conversationTitleNorm);
        }).map((e) => Map<String, dynamic>.from(e)).toList();
      }

      filtered.sort((a, b) {
        final at = _messageTimestampMs(a);
        final bt = _messageTimestampMs(b);
        return at.compareTo(bt);
      });

      final byId = <String, Map<String, dynamic>>{};
      for (final n in filtered) {
        final id = _messageId(n);
        if (id.isEmpty) continue;
        byId[id] = n;
      }
      for (final r in localReplies) {
        final m = Map<String, dynamic>.from(r);
        final id = _messageId(m);
        if (id.isEmpty) continue;
        byId[id] = m;
      }

      final all = byId.values.toList()
        ..sort(
          (a, b) => _messageTimestampMs(a).compareTo(_messageTimestampMs(b)),
        );

      final focusIdx = _pickInitialFocusIndex(all);

      int start = 0;
      int end = all.length;
      if (all.isNotEmpty) {
        final idx = focusIdx.clamp(0, all.length - 1);
        _selectedMessageId = _messageId(all[idx]);
        start = (idx - 10).clamp(0, all.length);
        end = (idx + 10).clamp(0, all.length);
        if ((end - start) < 15) {
          start = (end - 15).clamp(0, all.length);
          end = (start + 15).clamp(0, all.length);
        }
      }

      if (!mounted) return;
      setState(() {
        _allConversationMessages = all;
        _windowStart = start;
        _windowEnd = end;
        _messageKeys.clear();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureSelectedVisible();
        if (all.isNotEmpty && focusIdx >= all.length - 1) {
          _scrollToBottom();
        }
        _scheduleVisibilityCheck();
      });
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isConversationLoading = false;
        });
      }
    }
  }

  void _ensureSelectedVisible() {
    if (_selectedMessageId.isEmpty) return;
    if (!_conversationScrollController.hasClients) return;
    final key = _messageKeys[_selectedMessageId];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    try {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    } catch (_) {}
  }

  void _scrollToBottom() {
    if (!_conversationScrollController.hasClients) return;
    try {
      _conversationScrollController
          .jumpTo(_conversationScrollController.position.maxScrollExtent);
    } catch (_) {}
  }

  int _pickInitialFocusIndex(List<Map<String, dynamic>> all) {
    if (all.isEmpty) return 0;

    final byId = all.indexWhere((m) => _messageId(m) == _selectedMessageId);
    if (byId >= 0) return byId;

    final targetTs = _messageTimestampMs(widget.notificationData);
    final targetText =
        _normalizeConversationKey(_extractMessageBody(widget.notificationData));
    if (targetTs <= 0 && targetText.isEmpty) return all.length - 1;

    int bestIdx = all.length - 1;
    num bestScore = double.infinity;

    for (var i = 0; i < all.length; i++) {
      final m = all[i];
      final ts = _messageTimestampMs(m);
      final dt = targetTs > 0 ? (ts - targetTs).abs() : 0;

      num penalty = 0;
      if (targetText.isNotEmpty) {
        final mt = _normalizeConversationKey(_extractMessageBody(m));
        final match = mt.isNotEmpty &&
            (mt.contains(targetText) || targetText.contains(mt));
        if (!match) penalty = 5000000000;
      }

      final score = dt + penalty;
      if (score < bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }

    return bestIdx;
  }

  List<Map<String, dynamic>> _currentWindowMessages() {
    if (_allConversationMessages.isEmpty) return const [];
    final s = _windowStart.clamp(0, _allConversationMessages.length);
    final e = _windowEnd.clamp(0, _allConversationMessages.length);
    if (e <= s) return const [];
    return _allConversationMessages.sublist(s, e);
  }

  List<_ConversationItem> _buildConversationItems(
    List<Map<String, dynamic>> messages,
  ) {
    final items = <_ConversationItem>[];
    DateTime? lastDay;
    for (final m in messages) {
      final ts = _messageTimestamp(m);
      final day = ts == null ? null : DateTime(ts.year, ts.month, ts.day);
      if (day != null && (lastDay == null || day != lastDay)) {
        items.add(_ConversationItem.date(_formatDayLabel(day)));
        lastDay = day;
      } else if (day == null && lastDay != null) {
        items.add(_ConversationItem.date(_formatDayLabel(lastDay)));
      }
      items.add(_ConversationItem.message(m));
    }
    return items;
  }

  DateTime? _messageTimestamp(Map<String, dynamic> m) {
    final ms = _messageTimestampMs(m);
    if (ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  int _messageTimestampMs(Map<String, dynamic> m) {
    final timestampField = m['timestamp'];
    if (timestampField is Timestamp) return timestampField.millisecondsSinceEpoch;
    final time = m['time'];
    if (time is int) return time;
    if (time is String) return int.tryParse(time) ?? 0;
    final timestampMs = m['timestampMs'];
    if (timestampMs is int) return timestampMs;
    if (timestampMs is String) return int.tryParse(timestampMs) ?? 0;

    final id = (m['notificationId'] ?? m['id'] ?? '').toString();
    final idTs = int.tryParse(id.split('_').first) ?? 0;
    if (idTs > 0) return idTs;
    final postTime = m['postTime'];
    if (postTime is int) return postTime;
    return int.tryParse((postTime ?? '').toString()) ?? 0;
  }

  String _formatDayLabel(DateTime day) {
    return DateFormat('dd/MM/yyyy').format(day);
  }

  String _messageId(Map<String, dynamic> m) {
    return (m['notificationId'] ?? m['id'] ?? '').toString().trim();
  }

  String _extractMessageBody(Map<String, dynamic> m) {
    return _stringFromMessage(m, ['text', 'body', 'bigText', 'mensaje', 'contenido']);
  }

  String _formatMessageTime(Map<String, dynamic> m) {
    final ts = _messageTimestamp(m);
    if (ts == null) return '';
    return DateFormat('HH:mm').format(ts);
  }

  String _stringFromMessage(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  String _normalizeConversationKey(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9\\s]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
  }

  String _extractSbnKey(Map<String, dynamic> message) {
    final direct = (message['sbnKey'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final extras = message['extras'];
    if (extras is Map) {
      final v = (extras['sbnKey'] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String _pickBestSbnKeyForReply() {
    for (int i = _allConversationMessages.length - 1; i >= 0; i--) {
      final key = _extractSbnKey(_allConversationMessages[i]);
      if (key.isNotEmpty) return key;
    }
    return _extractSbnKey(widget.notificationData);
  }

  Future<void> _sendConversationReply(String text) async {
    if (text.trim().isEmpty) return;
    if (_isReplySending) return;

    final sbnKey = _pickBestSbnKeyForReply().trim();
    if (sbnKey.isEmpty) {
      _setReplyStatus('No se pudo enviar la respuesta desde el emisor.');
      return;
    }

    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final replyId = 'reply_$requestId';
    final payload = <String, dynamic>{
      'type': 'notif_reply',
      'packageName': _packageName,
      'conversationTitle': _conversationTitle,
      'sbnKey': sbnKey,
      'replyText': text.trim(),
      'requestId': requestId,
      'time': DateTime.now().millisecondsSinceEpoch,
    };
    final timeMs = (payload['time'] as int?) ?? DateTime.now().millisecondsSinceEpoch;

    final optimisticMessage = <String, dynamic>{
      'notificationId': replyId,
      'id': replyId,
      'title': _conversationTitle,
      'text': text.trim(),
      'packageName': _packageName,
      'appName': '',
      'timestamp': Timestamp.fromMillisecondsSinceEpoch(timeMs),
      'extras': <String, dynamic>{
        'direction': 'out',
        'isReply': true,
        'requestId': requestId,
        'sbnKey': sbnKey,
      },
      'status-visualizacion': true,
    };

    if (mounted) {
      setState(() {
        _isReplySending = true;
        _selectedMessageId = replyId;
        final next = List<Map<String, dynamic>>.from(_allConversationMessages);
        next.add(optimisticMessage);
        next.sort((a, b) => _messageTimestampMs(a).compareTo(_messageTimestampMs(b)));
        _allConversationMessages = next;
        _windowEnd = next.length;
        _windowStart = (_windowEnd - 15).clamp(0, _windowEnd);
        _messageKeys.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }

    bool delivered = false;
    bool queued = false;

    try {
      try {
        final status = await BleService.getBtServerStatus();
        final running = status['running'] == true;
        final connectedCount = (status['connectedCount'] as num?)?.toInt() ?? 0;
        if (running && connectedCount > 0) {
          delivered = await BleService.sendBtServerMessage(payload);
        }
      } catch (_) {}

      if (!delivered) {
        try {
          delivered = await BleService.sendNotification(payload);
        } catch (_) {
          delivered = false;
        }
      }

      if (!delivered) {
        await _enqueueReplyInFirestoreFallback(payload);
        queued = true;
      }

      try {
        await NotificationCacheService.recordSentReply(
          packageName: _packageName,
          conversationTitle: _conversationTitle,
          replyText: text.trim(),
          timestampMs: payload['time'] as int?,
        );
      } catch (_) {}

      try {
        await BtHiveStorageService.storeConversationReply(
          requestId: requestId,
          packageName: _packageName,
          conversationTitle: _conversationTitle,
          replyText: text.trim(),
          sbnKey: sbnKey,
          timestampMs: payload['time'] as int?,
        );
      } catch (_) {}

      _selectedMessageId = replyId;
      await _loadConversationMessages();

      if (queued) {
        _setReplyStatus('Respuesta en cola. El emisor aún no la envía.');
      } else if (delivered) {
        _setReplyStatus(null);
      } else {
        _setReplyStatus('No se pudo enviar la respuesta desde el emisor.');
      }
    } catch (_) {
      _setReplyStatus('No se pudo enviar la respuesta desde el emisor.');
    } finally {
      if (mounted) {
        setState(() {
          _isReplySending = false;
        });
      }
    }
  }

  Future<void> _enqueueReplyInFirestoreFallback(
    Map<String, dynamic> payload,
  ) async {
    final linkedDeviceId = await _receptorService.getLinkedDeviceId();
    final target = (linkedDeviceId ?? '').trim();
    if (target.isEmpty) throw Exception('linkedDeviceId vacío');

    final requestId = (payload['requestId'] ?? '').toString().trim();
    if (requestId.isEmpty) throw Exception('requestId vacío');

    await FirebaseFirestore.instance
        .collection('dispositivos')
        .doc(target)
        .collection('replyQueue')
        .doc(requestId)
        .set({
      ...payload,
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });
  }
}

class _ConversationItem {
  final bool isDateSeparator;
  final String dateLabel;
  final Map<String, dynamic>? message;

  const _ConversationItem._({
    required this.isDateSeparator,
    required this.dateLabel,
    required this.message,
  });

  factory _ConversationItem.date(String label) =>
      _ConversationItem._(isDateSeparator: true, dateLabel: label, message: null);

  factory _ConversationItem.message(Map<String, dynamic> message) =>
      _ConversationItem._(isDateSeparator: false, dateLabel: '', message: message);
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
  final VoidCallback? onMediaPressed;

  const _FsBar({
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
    required this.onMediaPressed,
  });

  @override
  State<_FsBar> createState() => _FsBarState();
}

class _FsBarState extends State<_FsBar> {
  Timer? _tick;
  final Map<String, Uint8List?> _pngCache = <String, Uint8List?>{};

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
    final cached = _pngCache[s];
    if (cached != null || _pngCache.containsKey(s)) return cached;
    try {
      final bytes = base64Decode(s);
      _pngCache[s] = bytes;
      return bytes;
    } catch (_) {
      _pngCache[s] = null;
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
      gaplessPlayback: true,
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
            InkWell(
              onTap: widget.onMediaPressed,
              borderRadius: BorderRadius.circular(12),
              child: Container(
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
