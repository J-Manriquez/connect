import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:connect/theme_colors.dart';
import 'package:connect/services/ble_service.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:connect/services/local_notification_service.dart';
import 'package:connect/services/notification_cache_service.dart';
import 'package:connect/services/notification_filter_service.dart';
import 'package:connect/services/preferences_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> notificationData;

  const NotificationDetailScreen({super.key, required this.notificationData});

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  final ReceptorService _receptorService = ReceptorService();
  bool _isMarkingAsRead = false;
  bool _isConversationMode = false;
  bool _isConversationLoading = false;
  bool _isConversationPaging = false;
  bool _isReplySending = false;
  String _conversationTitle = '';
  String _packageName = '';
  String _appName = '';
  String _appIconBase64 = '';
  String _selectedMessageId = '';
  List<Map<String, dynamic>> _allConversationMessages = [];
  int _windowStart = 0;
  int _windowEnd = 0;
  final ScrollController _conversationScrollController = ScrollController();
  final TextEditingController _replyController = TextEditingController();
  final Map<String, GlobalKey> _messageKeys = {};
  bool _visibilityCheckScheduled = false;
  final Set<String> _visibilityMarked = {};
  int _lastBtDebugMs = 0;
  String _lastBtDebugSig = '';

  void _goBackToConexion() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/notificaciones',
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    final notificationId =
        (widget.notificationData['notificationId'] ?? widget.notificationData['id'])
            ?.toString()
            .trim();
    if (notificationId != null && notificationId.isNotEmpty) {
      Timer(const Duration(seconds: 5), () async {
        await LocalNotificationService.cancelNotification(notificationId);
      });
    }
    _btDebug(
      'initState selectedId=${(widget.notificationData['notificationId'] ?? widget.notificationData['id'] ?? '').toString()} pkg=${(widget.notificationData['packageName'] ?? widget.notificationData['paquete'] ?? '').toString()} title=${(widget.notificationData['title'] ?? widget.notificationData['titulo'] ?? '').toString()}',
      sig: 'init',
      throttleMs: 0,
    );
    _markAsRead();
    _initConversation();
    _conversationScrollController.addListener(_onConversationScroll);
  }

  @override
  void dispose() {
    _conversationScrollController.removeListener(_onConversationScroll);
    _conversationScrollController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _initConversation() async {
    final packageName =
        _getFieldValue(['packageName', 'paquete'])?.trim() ?? '';
    final title = _getFieldValue(['title', 'titulo'])?.trim() ?? '';
    final appName =
        _getFieldValue(['appName', 'aplicacion'])?.trim() ?? 'Aplicación desconocida';
    final selectedMessageId = (widget.notificationData['notificationId'] ??
            widget.notificationData['id'] ??
            '')
        .toString()
        .trim();

    _btDebug(
      '_initConversation pkg=$packageName title=$title appName=$appName selectedId=$selectedMessageId',
      sig: 'initConversation:$packageName:$title:$selectedMessageId',
      throttleMs: 0,
    );

    String appIconBase64 =
        (widget.notificationData['appIcon'] ?? widget.notificationData['icon'] ?? '')
            .toString()
            .trim();
    if (appIconBase64.isEmpty && packageName.isNotEmpty) {
      try {
        final List<dynamic> result =
            await NotificationFilterService.platform.invokeMethod(
          'getInstalledApps',
        );
        for (final item in result) {
          final m = Map<String, dynamic>.from(item as Map);
          if ((m['packageName'] ?? '').toString().trim() == packageName) {
            final icon = (m['icon'] ?? '').toString().trim();
            if (icon.isNotEmpty) {
              appIconBase64 = icon;
              break;
            }
          }
        }
      } catch (_) {}
    }

    bool conversationMode = false;
    if (packageName.isNotEmpty && title.isNotEmpty) {
      final enabled =
          await PreferencesService.getConversationEnabledPackages();
      conversationMode = enabled.contains(packageName);
      _btDebug(
        '_initConversation enabledCount=${enabled.length} enabledHasPkg=$conversationMode',
        sig: 'enabled:$packageName:${enabled.length}:$conversationMode',
        throttleMs: 0,
      );
    }

    if (!mounted) return;
    setState(() {
      _packageName = packageName;
      _conversationTitle = title;
      _appName = appName;
      _selectedMessageId = selectedMessageId;
      _appIconBase64 = appIconBase64;
      _isConversationMode = conversationMode;
    });

    if (_isConversationMode) {
      _btDebug(
        '_initConversation conversationMode=ON -> _loadConversationMessages()',
        sig: 'goLoad:$packageName:$title',
        throttleMs: 0,
      );
      await _loadConversationMessages();
    } else {
      _btDebug(
        '_initConversation conversationMode=OFF',
        sig: 'convOff:$packageName:$title',
        throttleMs: 0,
      );
    }
  }

  Future<void> _markAsRead() async {
    if (_isMarkingAsRead) return;

    setState(() {
      _isMarkingAsRead = true;
    });

    try {
      final notificationId = (widget.notificationData['notificationId'] ??
              widget.notificationData['id'])
          ?.toString();
      if (notificationId != null && notificationId.isNotEmpty) {
        await NotificationCacheService.markAsVisualized(notificationId);
        await BtHiveStorageService.markVisualized(notificationId, true);
        await _receptorService.updateNotificationVisualizationStatus(
          notificationId,
          true,
        );
        //// print('Notificación marcada como leída: $notificationId');
      }
    } catch (e) {
      // print('Error al marcar notificación como leída: $e');
    } finally {
      setState(() {
        _isMarkingAsRead = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extraer datos de diferentes campos posibles
    final title = _getFieldValue(['title', 'titulo']) ?? 'Sin título';
    final body =
        _getFieldValue(['text', 'body', 'bigText', 'mensaje', 'contenido']) ??
        'Sin contenido';
    final appName =
        _getFieldValue(['appName', 'aplicacion']) ?? 'Aplicación desconocida';
    final subText = _getFieldValue(['subText', 'subtexto']);
    final summaryText = _getFieldValue(['summaryText', 'resumen']);
    final infoText = _getFieldValue(['infoText', 'info']);
    final contentInfo = _getFieldValue(['contentInfo', 'infoContenido']);

    // Intentar obtener timestamp si está disponible
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
    } catch (e) {
      // print('Error al formatear tiempo: $e');
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBackToConexion();
      },
      child: Scaffold(
        appBar: _isConversationMode
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goBackToConexion,
                ),
                centerTitle: true,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildAppIconForAppBar(),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(title, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(_isConversationPaging ? 2 : 0),
                  child: _isConversationPaging
                      ? const LinearProgressIndicator(minHeight: 2)
                      : const SizedBox.shrink(),
                ),
                backgroundColor: customColor[700],
                foregroundColor: Colors.white,
              )
            : AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goBackToConexion,
                ),
                title: const Text('Detalle de Notificación'),
                backgroundColor: customColor[700],
                foregroundColor: Colors.white,
              ),
        body: _isConversationMode
            ? _buildConversationBody()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.message,
                                  color: customColor[700],
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Contenido Principal',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildContentField('Título', title),
                            const SizedBox(height: 10),
                            _buildContentField('Mensaje', body),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (subText != null ||
                        summaryText != null ||
                        infoText != null ||
                        contentInfo != null) ...[
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: customColor[700],
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Información Adicional',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (subText != null) ...[
                                _buildContentField('Subtexto', subText),
                                const SizedBox(height: 8),
                              ],
                              if (summaryText != null) ...[
                                _buildContentField('Resumen', summaryText),
                                const SizedBox(height: 8),
                              ],
                              if (infoText != null) ...[
                                _buildContentField('Información', infoText),
                                const SizedBox(height: 8),
                              ],
                              if (contentInfo != null) ...[
                                _buildContentField(
                                  'Info del Contenido',
                                  contentInfo,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.apps,
                                  color: customColor[700],
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Información de la Aplicación',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildInfoRow('Aplicación:', appName),
                            _buildInfoRow('Fecha y Hora:', formattedTime),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_isMarkingAsRead)
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              const Text('Marcando como leída...'),
                            ],
                          ),
                        ),
                      )
                    else
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Notificación marcada como leída',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.tune,
                                  color: customColor[700],
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Configuración Personalizada',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Crear configuraciones personalizadas de sonido, vibración o bloqueo para notificaciones similares.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 15),
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
                                label: const Text(
                                  'Configurar Notificación',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: customColor[600],
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
      ),
    );
  }

  // Método auxiliar para obtener valores de diferentes campos
  String? _getFieldValue(List<String> fieldNames) {
    for (final fieldName in fieldNames) {
      final value = widget.notificationData[fieldName];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
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

  Widget _buildAppIconForAppBar() {
    if (_appIconBase64.isEmpty) {
      return const SizedBox(width: 28, height: 28);
    }
    try {
      final bytes = base64Decode(_appIconBase64);
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          bytes,
          width: 28,
          height: 28,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(width: 28, height: 28);
          },
        ),
      );
    } catch (_) {
      return const SizedBox(width: 28, height: 28);
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
      _btDebug(
        '_loadConversationMessages remoteCount=${remote.length}',
        sig: 'remoteCount:${remote.length}',
        throttleMs: 0,
      );
      final conversationTitleNorm = _normalizeConversationKey(_conversationTitle);
      List<Map<String, dynamic>> filtered = remote.where((n) {
        final pkg = _stringFromMessage(n, ['packageName', 'paquete']);
        final t = _stringFromMessage(n, ['title', 'titulo']);
        return pkg == _packageName && t == _conversationTitle;
      }).map((e) => Map<String, dynamic>.from(e)).toList();

      _btDebug(
        '_loadConversationMessages filteredExact=${filtered.length} conversationTitleNorm=$conversationTitleNorm',
        sig: 'exactCount:${filtered.length}:$conversationTitleNorm',
        throttleMs: 0,
      );

      if (filtered.length <= 1) {
        filtered = remote.where((n) {
          final pkg = _stringFromMessage(n, ['packageName', 'paquete']);
          if (pkg != _packageName) return false;
          final t = _stringFromMessage(n, ['title', 'titulo']);
          final tNorm = _normalizeConversationKey(t);
          if (conversationTitleNorm.isEmpty || tNorm.isEmpty) return false;
          if (conversationTitleNorm == tNorm) return true;
          if (conversationTitleNorm.length < 3 || tNorm.length < 3) return false;
          return conversationTitleNorm.contains(tNorm) || tNorm.contains(conversationTitleNorm);
        }).map((e) => Map<String, dynamic>.from(e)).toList();

        _btDebug(
          '_loadConversationMessages filteredFallback=${filtered.length}',
          sig: 'fallbackCount:${filtered.length}:$conversationTitleNorm',
          throttleMs: 0,
        );
      }

      final currentId = _selectedMessageId;
      final hasCurrent = filtered.any((m) => _messageId(m) == currentId);
      _btDebug(
        '_loadConversationMessages hasCurrent=$hasCurrent currentId=$currentId',
        sig: 'hasCurrent:$hasCurrent:$currentId',
        throttleMs: 0,
      );
      if (!hasCurrent && currentId.isNotEmpty) {
        final ts = widget.notificationData['timestamp'];
        Timestamp timestamp;
        if (ts is Timestamp) {
          timestamp = ts;
        } else {
          final parsed = _extractTimestampMsFromId(currentId);
          timestamp = Timestamp.fromMillisecondsSinceEpoch(
            parsed ?? DateTime.now().millisecondsSinceEpoch,
          );
        }
        filtered.add({
          'notificationId': currentId,
          'id': currentId,
          'title': _conversationTitle,
          'text': _getFieldValue(
                ['text', 'body', 'bigText', 'mensaje', 'contenido'],
              ) ??
              '',
          'packageName': _packageName,
          'appName': _appName,
          'timestamp': timestamp,
          'extras': Map<String, dynamic>.from(
            widget.notificationData['extras'] ?? {},
          ),
          'status-visualizacion':
              widget.notificationData['status-visualizacion'] == true,
        });
        _btDebug(
          '_loadConversationMessages injectedCurrent',
          sig: 'inject:$currentId',
          throttleMs: 0,
        );
      }

      filtered.sort((a, b) {
        final ta = _messageTimestamp(a) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb = _messageTimestamp(b) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return ta.compareTo(tb);
      });

      int selectedIndex = filtered.indexWhere((m) => _messageId(m) == currentId);
      if (selectedIndex < 0) {
        selectedIndex = filtered.isNotEmpty ? (filtered.length - 1) : 0;
      }

      int start = (selectedIndex - 2).clamp(0, filtered.length);
      int end = (start + 5).clamp(0, filtered.length);
      start = (end - 5).clamp(0, filtered.length);

      final firstTs = filtered.isNotEmpty ? _messageTimestamp(filtered.first) : null;
      final lastTs = filtered.isNotEmpty ? _messageTimestamp(filtered.last) : null;
      _btDebug(
        '_loadConversationMessages finalCount=${filtered.length} selectedIndex=$selectedIndex window=[$start,$end) firstTs=${firstTs?.toIso8601String()} lastTs=${lastTs?.toIso8601String()}',
        sig: 'final:${filtered.length}:$selectedIndex:$start:$end',
        throttleMs: 0,
      );

      if (!mounted) return;
      setState(() {
        _allConversationMessages = filtered;
        _windowStart = start;
        _windowEnd = end;
        _messageKeys.clear();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureSelectedVisible();
        _markVisibleMessagesAsRead();
      });
    } catch (_) {
    } finally {
      if (!mounted) return;
      setState(() {
        _isConversationLoading = false;
      });
    }
  }

  void _ensureSelectedVisible() {
    final id = _selectedMessageId;
    final key = _messageKeys[id];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
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
      _btDebug(
        '_maybeLoadMoreConversation expandTop prevStart=${_windowStart + 5} newStart=$_windowStart end=$_windowEnd',
        sig: 'expandTop:${_windowStart}:${_windowEnd}',
        throttleMs: 0,
      );

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
      _btDebug(
        '_maybeLoadMoreConversation expandBottom start=$_windowStart prevEnd=${_windowEnd - 5} newEnd=$_windowEnd total=${_allConversationMessages.length}',
        sig: 'expandBottom:${_windowStart}:${_windowEnd}:${_allConversationMessages.length}',
        throttleMs: 0,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleVisibilityCheck();
        if (!mounted) return;
        setState(() {
          _isConversationPaging = false;
        });
      });
    }
  }

  Widget _buildConversationBody() {
    if (_isConversationLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final messages = _currentWindowMessages();
    if (messages.isEmpty) {
      _btDebug(
        '_buildConversationBody empty window=[$_windowStart,$_windowEnd) total=${_allConversationMessages.length}',
        sig: 'empty:$_windowStart:$_windowEnd:${_allConversationMessages.length}',
        throttleMs: 800,
      );
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No hay mensajes para mostrar.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final items = _buildConversationItems(messages);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _conversationScrollController,
            padding: const EdgeInsets.symmetric(vertical: 12),
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
        _buildReplyComposer(),
      ],
    );
  }

  Widget _buildReplyComposer() {
    final canAttemptReply = _packageName.trim().isNotEmpty;
    final enabled = canAttemptReply && !_isReplySending;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) async {
                  await _sendConversationReply();
                },
                decoration: InputDecoration(
                  hintText: 'Escribe una respuesta…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              width: 44,
              child: ElevatedButton(
                onPressed: enabled ? _sendConversationReply : null,
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  backgroundColor: customColor[700],
                  foregroundColor: Colors.white,
                ),
                child: _isReplySending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendConversationReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    if (_isReplySending) return;

    final sbnKey = _pickBestSbnKeyForReply().trim();
    if (sbnKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede responder: falta identificador (sbnKey).'),
        ),
      );
      return;
    }

    setState(() {
      _isReplySending = true;
    });

    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final payload = <String, dynamic>{
      'type': 'notif_reply',
      'packageName': _packageName,
      'sbnKey': sbnKey,
      'replyText': text,
      'requestId': requestId,
      'time': DateTime.now().millisecondsSinceEpoch,
    };

    bool sent = false;
    try {
      try {
        final status = await BleService.getBtServerStatus();
        final running = status['running'] == true;
        final connectedCount = (status['connectedCount'] as num?)?.toInt() ?? 0;
        if (running && connectedCount > 0) {
          sent = await BleService.sendBtServerMessage(payload);
        }
      } catch (_) {}

      if (!sent) {
        try {
          sent = await BleService.sendNotification(payload);
        } catch (_) {
          sent = false;
        }
      }

      if (!sent) {
        await _enqueueReplyInFirestoreFallback(payload);
        sent = true;
      }

      _replyController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Respuesta enviada.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar la respuesta.')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isReplySending = false;
      });
    }
  }

  String _pickBestSbnKeyForReply() {
    for (int i = _allConversationMessages.length - 1; i >= 0; i--) {
      final key = _extractSbnKey(_allConversationMessages[i]);
      if (key.isNotEmpty) return key;
    }
    return _extractSbnKey(widget.notificationData);
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

  Widget _buildDateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: customColor[100],
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: customColor[800],
              fontWeight: FontWeight.w600,
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

    return SizedBox(
      key: key,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: GestureDetector(
          onLongPress: () => _showMessageActionsDialog(message),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: customColor[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: customColor[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      visualized ? Icons.done : Icons.done_outline,
                      size: 16,
                      color: visualized ? Colors.green : Colors.black45,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMessageActionsDialog(Map<String, dynamic> message) async {
    final visualized = message['status-visualizacion'] == true;
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

  Future<void> _markNotificationMapAsRead(Map<String, dynamic> message) async {
    final id = _messageId(message);
    if (id.isEmpty) return;
    if (message['status-visualizacion'] == true) return;

    try {
      await NotificationCacheService.markAsVisualized(id);
      await BtHiveStorageService.markVisualized(id, true);
      await _receptorService.updateNotificationVisualizationStatus(id, true);
    } catch (_) {}

    message['status-visualizacion'] = true;
    if (!mounted) return;
    setState(() {});
  }

  void _markVisibleMessagesAsRead() {
    if (!mounted) return;
    if (_allConversationMessages.isEmpty) return;

    final mediaQuery = MediaQuery.of(context);
    final top = mediaQuery.padding.top + kToolbarHeight;
    final bottom = mediaQuery.size.height - mediaQuery.padding.bottom;

    for (final entry in _messageKeys.entries) {
      final id = entry.key;
      final key = entry.value;
      if (_visibilityMarked.contains(id)) continue;
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final renderObject = ctx.findRenderObject();
      if (renderObject is! RenderBox) continue;
      if (!renderObject.attached) continue;
      final offset = renderObject.localToGlobal(Offset.zero);
      final y = offset.dy;
      final h = renderObject.size.height;
      final isVisible = y < bottom && (y + h) > top;
      if (!isVisible) continue;

      final message = _findMessageById(id);
      if (message == null) continue;
      if (message['status-visualizacion'] == true) {
        _visibilityMarked.add(id);
        continue;
      }

      _visibilityMarked.add(id);
      _markNotificationMapAsRead(message);
    }
  }

  Map<String, dynamic>? _findMessageById(String id) {
    for (final m in _allConversationMessages) {
      if (_messageId(m) == id) return m;
    }
    return null;
  }

  String _messageId(Map<String, dynamic> m) {
    return (m['notificationId'] ?? m['id'] ?? '').toString().trim();
  }

  String _stringFromMessage(Map<String, dynamic> m, List<String> fieldNames) {
    final dynamic rawExtras = m['extras'];
    final Map<dynamic, dynamic>? extras = rawExtras is Map ? rawExtras : null;
    for (final fieldName in fieldNames) {
      final direct = m[fieldName];
      final v = (direct ?? extras?[fieldName])?.toString().trim() ?? '';
      if (v.isNotEmpty && v.toLowerCase() != 'null') return v;
    }
    return '';
  }

  String _normalizeConversationKey(String s) {
    final trimmed = s.trim().toLowerCase();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _btDebug(
    String message, {
    String? sig,
    int throttleMs = 350,
  }) async {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final s = sig ?? message;
      if (throttleMs > 0 &&
          s == _lastBtDebugSig &&
          (nowMs - _lastBtDebugMs) < throttleMs) {
        return;
      }
      _lastBtDebugSig = s;
      _lastBtDebugMs = nowMs;

      print('[detalle_notif] $message');

      final status = await BleService.getBtServerStatus();
      final running = status['running'] == true;
      final peers = (status['connectedCount'] as num?)?.toInt() ?? 0;
      if (!running || peers <= 0) return;
      await BleService.sendBtServerMessage({
        'type': 'debug_log',
        'source': 'receptor_detalle_notif',
        'message': message,
        'timestamp': nowMs,
      });
    } catch (_) {}
  }

  DateTime? _messageTimestamp(Map<String, dynamic> m) {
    final ts = m['timestamp'];
    if (ts is Timestamp) return ts.toDate();
    final time = m['time'];
    if (time is String) {
      final v = int.tryParse(time);
      if (v != null) return DateTime.fromMillisecondsSinceEpoch(v);
    }
    if (time is int) {
      return DateTime.fromMillisecondsSinceEpoch(time);
    }
    final id = _messageId(m);
    final v = _extractTimestampMsFromId(id);
    if (v != null) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  int? _extractTimestampMsFromId(String id) {
    final raw = id.trim();
    if (raw.isEmpty) return null;
    final first = raw.split('_').first;
    final v = int.tryParse(first);
    return v;
  }

  String _extractMessageBody(Map<String, dynamic> m) {
    final candidates = [
      m['text'],
      m['body'],
      m['bigText'],
      m['mensaje'],
      m['contenido'],
    ];
    for (final c in candidates) {
      final v = (c ?? '').toString().trim();
      if (v.isNotEmpty && v.toLowerCase() != 'null') return v;
    }
    return '';
  }

  String _formatMessageTime(Map<String, dynamic> m) {
    final ts = _messageTimestamp(m);
    if (ts == null) return '--:--';
    return DateFormat('HH:mm').format(ts);
  }

  String _formatDayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return 'Hoy';
    if (day == yesterday) return 'Ayer';
    return DateFormat('dd/MM/yyyy').format(day);
  }

  // Método auxiliar para construir campos de contenido
  Widget _buildContentField(String label, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: customColor[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: customColor[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   '$label:',
          //   style: TextStyle(
          //     fontWeight: FontWeight.bold,
          //     color: customColor[700],
          //     fontSize: 14,
          //   ),
          // ),
          // const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: customColor[700],
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
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

  factory _ConversationItem.date(String label) {
    return _ConversationItem._(
      isDateSeparator: true,
      dateLabel: label,
      message: null,
    );
  }

  factory _ConversationItem.message(Map<String, dynamic> message) {
    return _ConversationItem._(
      isDateSeparator: false,
      dateLabel: '',
      message: message,
    );
  }
}
