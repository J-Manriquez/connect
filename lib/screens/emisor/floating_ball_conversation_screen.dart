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
import 'package:connect/widgets/stt_mic_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // Escuchar "newIntentArrived" enviado desde AutoOpenConversationActivity
    // cuando llega una notificación más reciente con singleTask activo.
    _autoOpenChannel.setMethodCallHandler(_onNativeCall);
    _load();
  }

  @override
  void dispose() {
    _autoOpenChannel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'newIntentArrived') {
      final args = call.arguments;
      if (args is Map) {
        await _loadFromData(Map<String, dynamic>.from(args));
      } else {
        await _load();
      }
    }
    return null;
  }

  Future<void> _load() async {
    Map<String, dynamic> data = <String, dynamic>{};
    try {
      final dynamic res = await _autoOpenChannel.invokeMethod('getAutoOpenPayload');
      if (res is Map) data = Map<String, dynamic>.from(res);
    } catch (_) {}
    await _loadFromData(data);
  }

  Future<void> _loadFromData(Map<String, dynamic> data) async {
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
    // ValueKey por notificationId: cuando llega una notificación diferente
    // (onNewIntent → newIntentArrived) Flutter destruye el screen anterior y
    // crea uno nuevo desde cero, disparando initState con el nuevo payload.
    return FloatingBallConversationScreen(
      key: ValueKey(data['notificationId'] ?? data['id'] ?? ''),
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

  /// Estado "¿la notificación sigue en la barra del emisor?":
  /// null = desconocido, true = sigue, false = ya no está.
  bool? _notifStillActive;
  Timer? _notifActiveTimer;
  /// sbnKey de la notificación entrante más reciente de esta conversación.
  /// Se fija al abrir (asumiendo que la notificación que disparó la pantalla
  /// está activa) y se actualiza cada vez que llega un mensaje entrante nuevo,
  /// en vez de recalcularse desde `_pickBestSbnKeyForReply` (que puede tomar
  /// el sbnKey de una respuesta saliente vieja y dejar el indicador
  /// permanentemente desincronizado de la notificación real).
  String _notifActiveSbnKey = '';

  /// id del último mensaje visto en la marca `bt_hive_last_notification`
  /// (puente entre isletas — ver `_pollNewMessages`), para no recargar la
  /// conversación de más cuando no hay nada nuevo relevante.
  String _lastSeenNewMessageId = '';

  @override
  void initState() {
    super.initState();
    _btDebug(
      'pantalla ABIERTA pkg=${_getFieldValue(['packageName', 'paquete'])} '
      'title="${_getFieldValue(['title', 'titulo'])}" '
      'selectedId=${(widget.notificationData['notificationId'] ?? widget.notificationData['id'] ?? '')}',
      sig: 'screenOpen',
      throttleMs: 0,
    );
    WidgetsBinding.instance.addObserver(this);
    _loadStyle();
    _initMediaVisibility();
    _refreshSystemState();
    _systemTick = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshSystemState();
    });
    _conversationScrollController.addListener(_onConversationScroll);
    _initModeAndMaybeLoad();
    // Sondea cada 4s si la notificación sigue en la barra del emisor, y si
    // llegó algún mensaje nuevo mientras la pantalla está abierta.
    _pollNotifActive();
    _notifActiveTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollNotifActive();
      _pollNewMessages();
    });
  }

  /// Detecta mensajes nuevos llegados mientras la pantalla está abierta.
  /// `btHiveMain` (isleta de fondo) escribe en SharedPreferences cada vez que
  /// procesa un `onBtNotification`; acá solo leemos esa marca y, si cambió Y
  /// pertenece a esta conversación (mismo packageName+title), recargamos.
  /// Sin esto, un mensaje nuevo nunca aparecía hasta cerrar y reabrir la
  /// pantalla (no había ningún mecanismo de refresco en vivo).
  Future<void> _pollNewMessages() async {
    if (!_isConversationMode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('bt_hive_last_notification');
      if (raw == null || raw.isEmpty) return;
      final Map<String, dynamic> st = jsonDecode(raw) as Map<String, dynamic>;
      final id = (st['id'] ?? '').toString();
      if (id.isEmpty || id == _lastSeenNewMessageId) return;
      _lastSeenNewMessageId = id;
      final pkg = (st['pkg'] ?? '').toString();
      final title = (st['title'] ?? '').toString();
      if (pkg != _packageName || title != _conversationTitle) {
        _btDebug(
          'pollNewMessages ignorado: otra conversación id=$id pkg=$pkg title="$title"',
          sig: 'pollNewMessages',
          throttleMs: 0,
        );
        return;
      }
      _btDebug('pollNewMessages detectado id=$id => recargando', sig: 'pollNewMessages', throttleMs: 0);
      await _loadConversationMessages();
    } catch (e) {
      _btDebug('pollNewMessages error=$e', sig: 'pollNewMessages', throttleMs: 0);
    }
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
    _btDebug(
      'pantalla CERRADA pkg=$_packageName title="$_conversationTitle"',
      sig: 'screenClose',
      throttleMs: 0,
    );
    WidgetsBinding.instance.removeObserver(this);
    _systemTick?.cancel();
    _systemTick = null;
    _notifActiveTimer?.cancel();
    _notifActiveTimer = null;
    _systemState.dispose();
    _replyStatusTimer?.cancel();
    _replyStatusTimer = null;
    _conversationScrollController.removeListener(_onConversationScroll);
    _conversationScrollController.dispose();
    super.dispose();
  }

  /// Pregunta al emisor (por BT) si la notificación de esta conversación sigue
  /// en su barra, y refresca el indicador con el último estado conocido.
  Future<void> _pollNotifActive() async {
    // Prioriza el sbnKey de la notificación entrante más reciente (fijado al
    // abrir y actualizado en cada carga); solo si no hay ninguno cae al
    // anterior método (último sbnKey disponible en cualquier mensaje,
    // incluyendo respuestas salientes), para no perder el sondeo en
    // conversaciones viejas que no hayan pasado por ese flujo.
    final sbnKey = (_notifActiveSbnKey.isNotEmpty
            ? _notifActiveSbnKey
            : _pickBestSbnKeyForReply())
        .trim();
    if (sbnKey.isEmpty) {
      _btDebug('pollNotifActive skip: sbnKey vacío', sig: 'pollNotifActive', throttleMs: 4000);
      return;
    }
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final query = {
      'type': 'query_notif_active',
      'sbnKey': sbnKey,
      'requestId': requestId,
    };
    // La consulta debe llegar al peer sin importar si ESTE dispositivo es,
    // en este momento, el servidor BT o el cliente: igual que
    // `_sendConversationReply`, se prueba la ruta servidor (peers conectados
    // a nuestro BtClassicServerService) y, si no hay, la ruta cliente
    // (BtClassicClient.send). Antes solo se probaba la ruta servidor: si este
    // dispositivo era el cliente de la conexión, la consulta nunca llegaba al
    // peer y el indicador quedaba gris para siempre.
    bool sentViaServer = false;
    try {
      final status = await BleService.getBtServerStatus();
      final running = status['running'] == true;
      final connectedCount = (status['connectedCount'] as num?)?.toInt() ?? 0;
      if (running && connectedCount > 0) {
        sentViaServer = await BleService.sendBtServerMessage(query);
      }
    } catch (e) {
      _btDebug('pollNotifActive serverSend error=$e', sig: 'pollNotifActive', throttleMs: 0);
    }
    bool sentViaClient = false;
    if (!sentViaServer) {
      try {
        sentViaClient = await BleService.sendNotification(query);
      } catch (e) {
        _btDebug('pollNotifActive clientSend error=$e', sig: 'pollNotifActive', throttleMs: 0);
      }
    }
    _btDebug(
      'pollNotifActive sent sbnKey=$sbnKey requestId=$requestId '
      'viaServer=$sentViaServer viaClient=$sentViaClient',
      sig: 'pollNotifActive',
      throttleMs: 4000,
    );
    try {
      // El nativo guarda la última respuesta en SharedPreferences (puente entre
      // isletas). La respuesta llega async; el próximo tick ya la verá.
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('bt_notif_active_last');
      if (!mounted || raw == null || raw.isEmpty) return;
      final Map<String, dynamic> st = jsonDecode(raw) as Map<String, dynamic>;
      if ((st['sbnKey'] ?? '').toString().trim() != sbnKey) return;
      final active = st['active'] == true;
      _btDebug(
        'pollNotifActive response sbnKey=$sbnKey active=$active prevValue=$_notifStillActive',
        sig: 'pollNotifActiveResp',
        throttleMs: 4000,
      );
      if (_notifStillActive != active) {
        setState(() => _notifStillActive = active);
      }
    } catch (e) {
      _btDebug('pollNotifActive readPrefs error=$e', sig: 'pollNotifActive', throttleMs: 0);
    }
  }

  /// Modal explicativo del indicador de estado de la notificación.
  void _showNotifActiveInfo() {
    final active = _notifStillActive;
    final bgColor = Color(_convBgColor);
    final textColor = Color(_convTextColor);
    final titleColor = Color(_convTitleColor);

    final String statusLabel;
    final Color statusColor;
    final String statusDetail;
    if (active == null) {
      statusLabel = 'Estado desconocido';
      statusColor = Colors.grey;
      statusDetail = 'Aún no se recibió respuesta del emisor. No se sabe si puedes responder.';
    } else if (active) {
      statusLabel = 'Puedes responder';
      statusColor = Colors.green;
      statusDetail = 'La notificación sigue activa en la barra del emisor. La respuesta debería entregarse correctamente.';
    } else {
      statusLabel = 'Respuesta puede no entregarse';
      statusColor = Colors.red;
      statusDetail = 'La notificación ya no está en la barra del emisor. Es posible que la respuesta no se entregue.';
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgColor,
        title: Text('Estado de la notificación', style: TextStyle(color: titleColor)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    Expanded(
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(statusDetail, style: TextStyle(color: textColor)),
                const SizedBox(height: 18),
                Text('Referencia de colores:', style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12)),
                const SizedBox(height: 8),
                _legendRow(Colors.green, 'Verde: notificación activa. Puedes responder.', textColor),
                const SizedBox(height: 8),
                _legendRow(Colors.red, 'Rojo: notificación ya no está. La respuesta puede no entregarse.', textColor),
                const SizedBox(height: 8),
                _legendRow(Colors.grey, 'Gris: estado desconocido, sin respuesta del emisor aún.', textColor),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Entendido', style: TextStyle(color: titleColor)),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String text, [Color? textColor]) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 3, right: 8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(child: Text(text, style: textColor != null ? TextStyle(color: textColor) : null)),
      ],
    );
  }

  Color _notifActiveDotColor() {
    switch (_notifStillActive) {
      case true:
        return Colors.green;
      case false:
        return Colors.red;
      default:
        return Colors.grey;
    }
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

    _btDebug(
      'initMode triggerId=$selectedMessageId pkg="$pkg" title="$title" '
      'startInConv=${widget.startInConversationMode} fsConvEnabled=$fsConversationEnabled '
      'appConvEnabled=$appConversationEnabled => conversationMode=$conversationMode',
      sig: 'initMode',
      throttleMs: 0,
    );

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

    // Si entramos en modo conversación, asumimos optimistamente que la
    // notificación que la disparó sigue en la barra del emisor (verde) hasta
    // que el primer poll real la confirme o la corrija.
    final initialSbnKey = conversationMode ? _extractSbnKey(widget.notificationData) : '';

    if (!mounted) return;
    setState(() {
      _packageName = pkg;
      _conversationTitle = title;
      _selectedMessageId = selectedMessageId;
      _appIconBase64 = iconBase64Clean;
      _appIconBytes = iconBytes;
      _isConversationMode = conversationMode;
      if (initialSbnKey.isNotEmpty) {
        _notifActiveSbnKey = initialSbnKey;
        _notifStillActive = true;
      }
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
    // Imprime local (visible en `flutter run`/logcat del dispositivo que ejecuta
    // esta pantalla) además de reenviar por Bluetooth al peer. El reenvío usa
    // una llamada nativa directa y síncrona (sin Intent/startForegroundService,
    // ver BleService.sendDebugLogToPeers) — la vía anterior con
    // sendBtServerMessage chocaba con el rate-limit de Android al loguear con
    // esta frecuencia.
    print('[floating_ball_conversation] $message');
    try {
      unawaited(BleService.sendDebugLogToPeers('floating_ball_conversation', message));
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
                        maxWidth: (constraints.maxWidth - iconSize - 10 - 28)
                            .clamp(100.0, constraints.maxWidth),
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
              // Indicador "¿notificación aún en la barra del emisor?":
              // verde = sí, rojo = no, gris = desconocido. Toque → explicación.
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _showNotifActiveInfo,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _notifActiveDotColor(),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final totalW = constraints.maxWidth;
                final gap = _convBottomButtonsGapDp.toDouble();
                // Mostrar responder: solo en modo conversación y cuando la
                // notificación está activa (verde) o aún desconocida (gris).
                // Si es roja (false) se oculta con animación; vuelve a aparecer
                // con la misma animación si la notificación regresa a activa.
                final showReply = _isConversationMode && _notifStillActive != false;
                final halfW = (totalW - gap) / 2;

                final closeBtn = _bottomActionButton(
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
                );

                return Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: (_isConversationMode && !showReply) ? totalW : halfW,
                      child: closeBtn,
                    ),
                    if (_isConversationMode)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: showReply ? halfW + gap : 0,
                        clipBehavior: Clip.hardEdge,
                        decoration: const BoxDecoration(),
                        child: Row(
                          children: [
                            SizedBox(width: gap),
                            Expanded(
                              child: _bottomActionButton(
                                onTap: _isReplySending ? null : _openSttReply,
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
                        ),
                      ),
                  ],
                );
              },
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

    _btDebug('deleteMessage start id=$id isReply=$isReply', sig: 'deleteMessage', throttleMs: 0);

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
        // Estos mensajes son mirrored desde el dispositivo receptor vinculado
        // (no desde este dispositivo): hay que borrar bajo SU deviceId, no el
        // propio (`FirebaseService.getDeviceId()`), o la notificación nunca se
        // borra de verdad en Firestore y reaparece en la siguiente recarga.
        final linkedDeviceId = await _receptorService.getLinkedDeviceId();
        if (linkedDeviceId != null && linkedDeviceId.trim().isNotEmpty) {
          await FirebaseService()
              .deleteNotificationForDeviceId(linkedDeviceId.trim(), id);
        }
        await BtHiveStorageService.deleteOutboxEntry(id);
      }
    } catch (e) {
      _btDebug('deleteMessage id=$id storageError=$e', sig: 'deleteMessage', throttleMs: 0);
    }

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
    final bgColor = Color(_convBgColor);
    final textColor = Color(_convTextColor);
    final titleColor = Color(_convTitleColor);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: bgColor,
          title: Text('Opciones', style: TextStyle(color: titleColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.done, color: textColor),
                title: Text('Marcar como leído', style: TextStyle(color: textColor)),
                enabled: !visualized,
                onTap: visualized
                    ? null
                    : () async {
                        Navigator.of(context).pop();
                        await _markNotificationMapAsRead(message);
                      },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: textColor),
                title: Text(isReply ? 'Eliminar respuesta' : 'Eliminar mensaje',
                    style: TextStyle(color: textColor)),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _deleteConversationMessage(message);
                },
              ),
              ListTile(
                leading: Icon(Icons.settings, color: textColor),
                title: Text('Configuración personalizada', style: TextStyle(color: textColor)),
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

  /// Responder ahora abre directamente el modal de voz (sin diálogo de texto
  /// intermedio): el usuario graba o edita el texto transcrito ahí mismo y lo
  /// envía con el botón "Enviar" del propio modal.
  Future<void> _openSttReply() async {
    await showSttReplyModal(
      context,
      accentColor: Color(_convReplyModalTextColor),
      backgroundColor: Color(_convReplyModalBgColor),
      onResult: (text) {
        final trimmed = text.trim();
        if (trimmed.isEmpty) return;
        unawaited(_sendConversationReply(trimmed));
      },
    );
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
    final id = _messageId(message);
    try {
      final notificationId = (message['notificationId'] ?? message['id'])?.toString();
      if (notificationId == null || notificationId.isEmpty) return;
      await NotificationCacheService.markAsVisualized(notificationId);
      await BtHiveStorageService.markVisualized(notificationId, true);
      await _receptorService.updateNotificationVisualizationStatus(
        notificationId,
        true,
      );
      _btDebug('markAsRead id=$id ok', sig: 'markAsRead:$id', throttleMs: 0);
    } catch (e) {
      _btDebug('markAsRead id=$id error=$e', sig: 'markAsRead:$id', throttleMs: 0);
    }
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
      final newStart = (_windowStart - 10).clamp(0, _windowStart);

      _btDebug(
        'paging expandUp windowStart=$_windowStart->$newStart windowEnd=$_windowEnd total=${_allConversationMessages.length}',
        sig: 'pagingUp',
        throttleMs: 0,
      );

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

      final newEnd = (_windowEnd + 10).clamp(
        _windowEnd,
        _allConversationMessages.length,
      );
      _btDebug(
        'paging expandDown windowEnd=$_windowEnd->$newEnd windowStart=$_windowStart total=${_allConversationMessages.length}',
        sig: 'pagingDown',
        throttleMs: 0,
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
      List<Map<String, dynamic>> remote =
          await _receptorService.fetchAllNotificationsAcrossDaysRawOnce();

      // Si Firestore devolvió vacío (sin linkedDeviceId o error de red),
      // usar la cache Hive local que contiene las notificaciones BT entrantes
      // (outbox + firebase_cache), para no mostrar conversación vacía.
      if (remote.isEmpty) {
        try {
          remote = await BtHiveStorageService.getLocalNotificationsForUi(
            includeVisualized: true,
          );
          _btDebug(
            'loadFallbackHive count=${remote.length}',
            sig: 'loadFallbackHive',
            throttleMs: 0,
          );
        } catch (_) {}
      }

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

      final exactMatchCount = filtered.length;
      bool usedFallbackFilter = false;
      if (filtered.length <= 1) {
        usedFallbackFilter = true;
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

      // Inyectar el mensaje disparador si no vino en el set (igual que la
      // pantalla de la app). Sin esto, la notificación que abre la conversación
      // a veces no se visualiza en la bola flotante.
      final currentId = _selectedMessageId;
      if (currentId.isNotEmpty && !byId.containsKey(currentId)) {
        final tsRaw = widget.notificationData['timestamp'];
        final int tsMs;
        if (tsRaw is Timestamp) {
          tsMs = tsRaw.millisecondsSinceEpoch;
        } else {
          tsMs = int.tryParse(currentId.split('_').first) ??
              DateTime.now().millisecondsSinceEpoch;
        }
        byId[currentId] = {
          'notificationId': currentId,
          'id': currentId,
          'title': _conversationTitle,
          'text': _getFieldValue(
                ['text', 'body', 'bigText', 'mensaje', 'contenido'],
              ) ??
              '',
          'packageName': _packageName,
          'appName': '',
          'timestamp': Timestamp.fromMillisecondsSinceEpoch(tsMs),
          'extras': {
            ...Map<String, dynamic>.from(widget.notificationData['extras'] ?? {}),
            // Marca este mensaje como sintetizado: si el real (con su propio
            // id, formato distinto al `currentId` nativo) llega luego desde
            // Firestore/Hive, lo detectamos por contenido y descartamos esta
            // copia para no duplicar visualmente el mensaje que abrió la
            // conversación.
            'synthetic': true,
          },
          'status-visualizacion':
              widget.notificationData['status-visualizacion'] == true,
        };
        _btDebug(
          'load injectedCurrent id=$currentId tsMs=$tsMs',
          sig: 'inject',
          throttleMs: 0,
        );
      }

      // Dedupe por contenido: si el mensaje sintetizado de arriba coincide
      // (mismo autor+texto+minuto) con un mensaje REAL ya presente bajo otro
      // id, nos quedamos con el real (tiene sbnKey/datos completos) y
      // descartamos el sintetizado.
      final syntheticEntry = byId[currentId];
      if (currentId.isNotEmpty &&
          syntheticEntry != null &&
          (syntheticEntry['extras'] as Map?)?['synthetic'] == true) {
        final syntheticKey = _messageDupKey(syntheticEntry);
        for (final entry in byId.entries) {
          if (entry.key == currentId) continue;
          if ((entry.value['extras'] as Map?)?['synthetic'] == true) continue;
          if (_messageDupKey(entry.value) == syntheticKey) {
            byId.remove(currentId);
            _btDebug(
              'load dedupSynthetic removido id=$currentId realId=${entry.key}',
              sig: 'dedupSynthetic',
              throttleMs: 0,
            );
            break;
          }
        }
      }

      final loadNowMs = DateTime.now().millisecondsSinceEpoch;
      final all = byId.values.toList()
        ..sort(
          (a, b) => _sortKeyMs(a, loadNowMs).compareTo(_sortKeyMs(b, loadNowMs)),
        );

      int end = all.length;
      int start = (end - 20).clamp(0, end);

      // Diagnóstico de orden y visibilidad del mensaje disparador.
      final zeroTsCount = all.where((m) => _messageTimestampMs(m) <= 0).length;
      final selectedPresent = _selectedMessageId.isNotEmpty &&
          all.any((m) => _messageId(m) == _selectedMessageId);
      _btDebug(
        'load done total=${all.length} window=$start..$end '
        'remote=${remote.length} localReplies=${localReplies.length} '
        'exactMatch=$exactMatchCount fallbackFilter=$usedFallbackFilter '
        'zeroTs=$zeroTsCount selectedId=$_selectedMessageId selectedPresent=$selectedPresent '
        'firstTs=${all.isEmpty ? 0 : _messageTimestampMs(all.first)} '
        'lastTs=${all.isEmpty ? 0 : _messageTimestampMs(all.last)}',
        sig: 'loadDone',
        throttleMs: 0,
      );

      // Log detallado de CADA mensaje que queda en el set final tras dedupe,
      // para detectar si un mismo mensaje (mismo autor+contenido+hora) se
      // repite con ids distintos. Se reenvía por BT (ver _btDebug) para
      // poder leerlo en el receptor vía `flutter logs > salidaCompilacion.txt`.
      final dupKeyCount = <String, int>{};
      for (final m in all) {
        final dupKey = _messageDupKey(m);
        dupKeyCount[dupKey] = (dupKeyCount[dupKey] ?? 0) + 1;
      }
      for (int i = 0; i < all.length; i++) {
        final m = all[i];
        final dupKey = _messageDupKey(m);
        final dupCount = dupKeyCount[dupKey] ?? 1;
        _btDebug(
          'msg[$i/${all.length}] ${_describeMessage(m)}'
          '${dupCount > 1 ? " [POSIBLE DUPLICADO x$dupCount]" : ""}',
          sig: 'msgDetail:${_messageId(m)}',
          throttleMs: 0,
        );
      }

      // Si llegó un mensaje ENTRANTE nuevo con un sbnKey distinto al que
      // venimos sondeando, es una notificación recién posteada: asumimos
      // optimistamente que está activa y empezamos a sondear esa, en vez de
      // seguir preguntando por una posiblemente vieja/ya removida.
      String? freshIncomingSbnKey;
      for (int i = all.length - 1; i >= 0; i--) {
        final m = all[i];
        final extrasRaw = m['extras'];
        final extras =
            extrasRaw is Map ? Map<String, dynamic>.from(extrasRaw) : <String, dynamic>{};
        if ((extras['direction'] ?? '').toString().trim() == 'out') continue;
        final key = _extractSbnKey(m);
        if (key.isNotEmpty) {
          freshIncomingSbnKey = key;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _allConversationMessages = all;
        _windowStart = start;
        _windowEnd = end;
        _messageKeys.clear();
        if (freshIncomingSbnKey != null && freshIncomingSbnKey != _notifActiveSbnKey) {
          _notifActiveSbnKey = freshIncomingSbnKey;
          _notifStillActive = true;
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
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

  void _scrollToBottom() {
    if (!_conversationScrollController.hasClients) return;
    try {
      _conversationScrollController
          .jumpTo(_conversationScrollController.position.maxScrollExtent);
    } catch (_) {}
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

    // Log de la ventana realmente renderizada (lo que el usuario VE en
    // pantalla), incluyendo ids en orden, para detectar si la duplicación
    // ocurre acá (mismo id dos veces en `messages`) en vez de en la carga.
    final ids = messages.map(_messageId).toList();
    final idCounts = <String, int>{};
    for (final id in ids) {
      idCounts[id] = (idCounts[id] ?? 0) + 1;
    }
    final repeatedIds = idCounts.entries.where((e) => e.value > 1).toList();
    _btDebug(
      'renderWindow count=${messages.length} ids=${ids.join(",")}'
      '${repeatedIds.isNotEmpty ? " [ID REPETIDO EN VENTANA: ${repeatedIds.map((e) => "${e.key}x${e.value}").join(",")}]" : ""}',
      sig: 'renderWindow:${ids.join(",")}',
      throttleMs: 0,
    );
    return items;
  }

  DateTime? _messageTimestamp(Map<String, dynamic> m) {
    final ms = _messageTimestampMs(m);
    if (ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Clave de orden segura: si el mensaje no tiene timestamp derivable (0),
  /// usa [fallbackMs] (capturado una sola vez por carga) en lugar de 0, para
  /// que no salte al inicio de la conversación (época 1970). Determinista para
  /// no romper el contrato del comparador.
  int _sortKeyMs(Map<String, dynamic> m, int fallbackMs) {
    final t = _messageTimestampMs(m);
    return t > 0 ? t : fallbackMs;
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

  /// Clave para detectar duplicados visuales: mismo autor + mismo contenido +
  /// mismo minuto, sin importar el id (dos ids distintos con esta misma clave
  /// se verían como el mismo mensaje repetido en la UI).
  String _messageDupKey(Map<String, dynamic> m) {
    final extrasRaw = m['extras'];
    final extras =
        extrasRaw is Map ? Map<String, dynamic>.from(extrasRaw) : <String, dynamic>{};
    final direction = (extras['direction'] ?? '').toString().trim();
    final content = _extractMessageBody(m);
    final tsMinute = _messageTimestampMs(m) ~/ 60000;
    return '$direction|$content|$tsMinute';
  }

  /// Descripción completa de un mensaje para diagnóstico: id, autor, fecha y
  /// hora, y contenido íntegro (sin truncar) — usado para encontrar la causa
  /// de mensajes repetidos en la pantalla.
  String _describeMessage(Map<String, dynamic> m) {
    final id = _messageId(m);
    final extrasRaw = m['extras'];
    final extras =
        extrasRaw is Map ? Map<String, dynamic>.from(extrasRaw) : <String, dynamic>{};
    final direction = (extras['direction'] ?? '').toString().trim();
    final isReply = extras['isReply'] == true || id.startsWith('reply_');
    final author = direction == 'out'
        ? 'yo${isReply ? "(respuesta)" : ""}'
        : (_stringFromMessage(m, ['appName']).isNotEmpty
            ? _stringFromMessage(m, ['appName'])
            : _conversationTitle);
    final tsMs = _messageTimestampMs(m);
    final fechaHora = tsMs > 0
        ? DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(tsMs))
        : 'sin timestamp';
    final content = _extractMessageBody(m);
    final visualized = m['status-visualizacion'] == true;
    return 'id=$id autor="$author" fecha="$fechaHora" tsMs=$tsMs '
        'visualizado=$visualized contenido="$content"';
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

    _btDebug(
      'sendReply optimistic replyId=$replyId timeMs=$timeMs sbnKey=$sbnKey total_before=${_allConversationMessages.length}',
      sig: 'sendOptimistic',
      throttleMs: 0,
    );

    if (mounted) {
      setState(() {
        _isReplySending = true;
        _selectedMessageId = replyId;
        final next = List<Map<String, dynamic>>.from(_allConversationMessages);
        next.add(optimisticMessage);
        final sortNowMs = DateTime.now().millisecondsSinceEpoch;
        next.sort((a, b) =>
            _sortKeyMs(a, sortNowMs).compareTo(_sortKeyMs(b, sortNowMs)));
        _allConversationMessages = next;
        _windowEnd = next.length;
        _windowStart = (_windowEnd - 20).clamp(0, _windowEnd);
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

      _btDebug(
        'sendReply result replyId=$replyId delivered=$delivered queued=$queued',
        sig: 'sendResult',
        throttleMs: 0,
      );

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
