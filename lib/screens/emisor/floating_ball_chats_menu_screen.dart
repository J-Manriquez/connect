import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/screens/emisor/floating_ball_conversation_screen.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/floating_ball_service.dart';
import 'package:connect/services/notification_cache_service.dart';
import 'package:connect/services/notification_filter_service.dart';
import 'package:connect/services/preferences_service.dart';
import 'package:connect/services/receptor_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Menú de chats de la bola flotante: lista todas las conversaciones (agrupadas
/// por paquete + título) de las apps con modo conversación activo y permite
/// abrir la pantalla de conversación de la bola con el chat seleccionado.
///
/// Comparte el sistema de estilos con la pantalla de conversación: todos los
/// colores/medidas se leen de `FloatingBallService.getChats*` (configurables en
/// la pantalla de estilos), nunca se hardcodean.
class FloatingBallChatsMenuScreen extends StatefulWidget {
  const FloatingBallChatsMenuScreen({super.key});

  @override
  State<FloatingBallChatsMenuScreen> createState() =>
      _FloatingBallChatsMenuScreenState();
}

class _ChatEntry {
  final String packageName;
  final String title;
  final String preview;
  final int tsMs;
  final String appName;
  final Uint8List? iconBytes;
  final Map<String, dynamic> message;
  // Todos los mensajes remotos de esta conversación (para marcar como leído /
  // eliminar el chat completo).
  final List<Map<String, dynamic>> messages;

  _ChatEntry({
    required this.packageName,
    required this.title,
    required this.preview,
    required this.tsMs,
    required this.appName,
    required this.iconBytes,
    required this.message,
    required this.messages,
  });
}

class _FloatingBallChatsMenuScreenState
    extends State<FloatingBallChatsMenuScreen> {
  final ReceptorService _receptorService = ReceptorService();

  bool _loading = true;
  List<_ChatEntry> _chats = <_ChatEntry>[];

  // Estilos (mismos defaults que FloatingBallService).
  int _bgColor = 0xDD111111;
  int _itemBgColor = 0x22111111;
  int _itemBorderColor = 0x22FFFFFF;
  int _titleColor = 0xFFFFFFFF;
  int _titleSizeSp = 16;
  int _textColor = 0xFFFFFFFF;
  int _textSizeSp = 14;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final bgColor = await FloatingBallService.getChatsBgColor();
      final itemBgColor = await FloatingBallService.getChatsItemBgColor();
      final itemBorderColor = await FloatingBallService.getChatsItemBorderColor();
      final titleColor = await FloatingBallService.getChatsTitleColor();
      final titleSizeSp = await FloatingBallService.getChatsTitleSizeSp();
      final textColor = await FloatingBallService.getChatsTextColor();
      final textSizeSp = await FloatingBallService.getChatsTextSizeSp();

      final chats = await _loadChats();

      if (!mounted) return;
      setState(() {
        _bgColor = bgColor;
        _itemBgColor = itemBgColor;
        _itemBorderColor = itemBorderColor;
        _titleColor = titleColor;
        _titleSizeSp = titleSizeSp;
        _textColor = textColor;
        _textSizeSp = textSizeSp;
        _chats = chats;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<List<_ChatEntry>> _loadChats() async {
    // Solo apps con modo conversación activo.
    Set<String> enabled = <String>{};
    try {
      enabled = (await PreferencesService.getConversationEnabledPackages())
          .toSet();
    } catch (_) {}
    if (enabled.isEmpty) return <_ChatEntry>[];

    // Misma fuente que la pantalla de conversación: Firestore con fallback a la
    // cache Hive local (notificaciones BT entrantes) si Firestore vino vacío.
    List<Map<String, dynamic>> remote = const [];
    try {
      remote = await _receptorService.fetchAllNotificationsAcrossDaysRawOnce();
    } catch (_) {
      remote = const [];
    }
    if (remote.isEmpty) {
      try {
        remote = await BtHiveStorageService.getLocalNotificationsForUi(
          includeVisualized: true,
        );
      } catch (_) {}
    }

    // Iconos de las apps instaladas, por paquete.
    final Map<String, Uint8List> iconByPkg = <String, Uint8List>{};
    try {
      final List<dynamic> result = await NotificationFilterService.platform
          .invokeMethod('getInstalledApps');
      for (final item in result) {
        final m = Map<String, dynamic>.from(item as Map);
        final pkg = (m['packageName'] ?? '').toString().trim();
        final icon = (m['icon'] ?? '').toString().trim();
        if (pkg.isEmpty || icon.isEmpty) continue;
        try {
          iconByPkg[pkg] = base64Decode(icon);
        } catch (_) {}
      }
    } catch (_) {}

    // Agrupar por (paquete, título normalizado) y quedarse con el mensaje más
    // reciente de cada conversación como representante.
    final Map<String, List<Map<String, dynamic>>> msgsByKey =
        <String, List<Map<String, dynamic>>>{};
    final Map<String, String> pkgByKey = <String, String>{};
    for (final raw in remote) {
      final m = Map<String, dynamic>.from(raw);
      final pkg = _stringFrom(m, ['packageName', 'paquete']);
      final title = _stringFrom(m, ['title', 'titulo']);
      if (pkg.isEmpty || title.isEmpty) continue;
      if (!enabled.contains(pkg)) continue;

      final key = '$pkg${_normalizeConversationKey(title)}';
      (msgsByKey[key] ??= <Map<String, dynamic>>[]).add(m);
      pkgByKey[key] = pkg;
    }

    final list = <_ChatEntry>[];
    msgsByKey.forEach((key, msgs) {
      msgs.sort(
          (a, b) => _messageTimestampMs(a).compareTo(_messageTimestampMs(b)));
      final latest = msgs.last;
      final pkg = pkgByKey[key]!;
      list.add(_ChatEntry(
        packageName: pkg,
        title: _stringFrom(latest, ['title', 'titulo']),
        preview: _extractBody(latest),
        tsMs: _messageTimestampMs(latest),
        appName: _stringFrom(latest, ['appName']),
        iconBytes: iconByPkg[pkg],
        message: latest,
        messages: msgs,
      ));
    });
    list.sort((a, b) => b.tsMs.compareTo(a.tsMs));
    return list;
  }

  Future<void> _openChat(_ChatEntry entry) async {
    final data = Map<String, dynamic>.from(entry.message);
    data['packageName'] = entry.packageName;
    data['title'] = entry.title;
    if (entry.appName.isNotEmpty) data['appName'] = entry.appName;
    if (!mounted) return;
    // openedFromBackground: true => fondo sólido y el botón "Cerrar" de la
    // conversación finaliza la Activity (vuelve a la app previa), igual que en
    // la auto-apertura. El gesto "atrás" sobre la conversación hace pop normal
    // de la ruta y regresa a esta lista de chats.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FloatingBallConversationScreen(
          notificationData: data,
          startInConversationMode: true,
          openedFromBackground: true,
        ),
      ),
    );
    // Al volver, refrescar por si llegaron mensajes nuevos.
    if (mounted) _load();
  }

  // ===== Menú contextual del chat (long-press) =====
  // Copia adaptada del modal de opciones de la pantalla de conversación de la
  // bola, con el diseño (colores) de esta pantalla.
  Future<void> _showChatOptions(_ChatEntry entry) async {
    final bg = Color(_bgColor);
    final titleColor = Color(_titleColor);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        Widget option({
          required IconData icon,
          required String label,
          required VoidCallback onTap,
          Color? color,
        }) {
          final c = color ?? titleColor;
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Color(_itemBgColor),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(_itemBorderColor)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: c, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: c,
                        fontSize: _titleSizeSp.toDouble(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: (_titleSizeSp + 2).toDouble(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              option(
                icon: Icons.done_all,
                label: 'Marcar como leído',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _markChatAsRead(entry);
                },
              ),
              option(
                icon: Icons.delete_outline,
                label: 'Eliminar chat',
                color: const Color(0xFFEF5350),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _confirmDeleteChat(entry);
                },
              ),
              option(
                icon: Icons.settings_outlined,
                label: 'Configuración personalizada',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _openChatConfig(entry);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Marca como leídos TODOS los mensajes del chat y cancela su notificación de
  /// la barra del dispositivo (si existe).
  Future<void> _markChatAsRead(_ChatEntry entry) async {
    for (final m in entry.messages) {
      final id = (m['notificationId'] ?? m['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      if (m['status-visualizacion'] == true) continue;
      try {
        await NotificationCacheService.markAsVisualized(id);
        await BtHiveStorageService.markVisualized(id, true);
        await _receptorService.updateNotificationVisualizationStatus(id, true);
      } catch (_) {}
    }
    try {
      await FloatingBallService.cancelChatNotifications(
        entry.packageName,
        entry.title,
      );
    } catch (_) {}
    if (mounted) {
      _showSnack('Chat marcado como leído');
      _load();
    }
  }

  Future<void> _confirmDeleteChat(_ChatEntry entry) async {
    final ok = await _showStyledConfirm(
      title: 'Eliminar chat',
      message:
          'Se eliminarán todos los mensajes de "${entry.title}" guardados en Firebase y en el dispositivo. Esta acción no se puede deshacer.',
    );
    if (ok != true) return;
    await _deleteChat(entry);
  }

  /// Elimina en cascada todos los mensajes del chat (Firebase + outbox local) y
  /// sus respuestas locales.
  Future<void> _deleteChat(_ChatEntry entry) async {
    // Optimista: quitar de la lista de inmediato.
    if (mounted) {
      setState(() {
        _chats = _chats
            .where((c) =>
                !(c.packageName == entry.packageName && c.title == entry.title))
            .toList();
      });
    }

    // Estos mensajes son mirrored desde el dispositivo receptor vinculado (no
    // desde este dispositivo): hay que borrar bajo SU deviceId
    // (`getLinkedDeviceId()`), no el propio (`FirebaseService.getDeviceId()`),
    // o la notificación nunca se borra de verdad en Firestore y el chat
    // reaparece en la siguiente recarga aunque el snackbar diga "eliminado".
    final linkedDeviceId = await _receptorService.getLinkedDeviceId();
    for (final m in entry.messages) {
      final id = (m['notificationId'] ?? m['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      try {
        if (linkedDeviceId != null && linkedDeviceId.trim().isNotEmpty) {
          await FirebaseService()
              .deleteNotificationForDeviceId(linkedDeviceId.trim(), id);
        }
        await BtHiveStorageService.deleteOutboxEntry(id);
      } catch (_) {}
    }

    try {
      final replies = await BtHiveStorageService.getConversationRepliesForUi(
        packageName: entry.packageName,
        conversationTitle: entry.title,
      );
      for (final r in replies) {
        final id = (r['notificationId'] ?? r['id'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        try {
          await BtHiveStorageService.deleteConversationReplyById(id);
        } catch (_) {}
      }
    } catch (_) {}

    try {
      await FloatingBallService.cancelChatNotifications(
        entry.packageName,
        entry.title,
      );
    } catch (_) {}

    if (mounted) {
      _showSnack('Chat eliminado');
      _load();
    }
  }

  /// Abre la pantalla de configurar notificación con el paquete y el título del
  /// chat, SIN contenido (un chat no permite seleccionar un mensaje concreto;
  /// esa opción ya existe desde la pantalla de conversación de la bola).
  void _openChatConfig(_ChatEntry entry) {
    Navigator.of(context).pushNamed(
      '/configure_notification',
      arguments: <String, dynamic>{
        'packageName': entry.packageName,
        'title': entry.title,
        'appName': entry.appName,
      },
    );
  }

  void _showSnack(String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool?> _showStyledConfirm({
    required String title,
    required String message,
  }) {
    final bg = Color(_bgColor);
    final titleColor = Color(_titleColor);
    final textColor = Color(_textColor);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        title: Text(title, style: TextStyle(color: titleColor)),
        content: Text(message, style: TextStyle(color: textColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: textColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Color(0xFFEF5350)),
            ),
          ),
        ],
      ),
    );
  }

  // Esta pantalla se abre como una Activity propia (FloatingBallChatsActivity)
  // por ENCIMA de otra app. Cerrar debe FINALIZAR la Activity para volver a la
  // app previa, NO hacer pop de la ruta Flutter: el initialRoute deja la ruta
  // '/' (EmisorScreen) debajo en el stack, así que un pop revelaría el home del
  // emisor en lugar de cerrar el overlay. Ver skill floating-ball-overlay-screen.
  void _close() {
    SystemNavigator.pop();
  }

  // ===== Helpers de mensajes (replican la pantalla de conversación) =====

  String _stringFrom(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  String _extractBody(Map<String, dynamic> m) {
    return _stringFrom(m, ['text', 'body', 'bigText', 'mensaje', 'contenido']);
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

  String _normalizeConversationKey(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _formatTime(int tsMs) {
    if (tsMs <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(tsMs);
    final now = DateTime.now();
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    return sameDay
        ? DateFormat('HH:mm').format(dt)
        : DateFormat('dd/MM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final bg = Color(_bgColor);
    final titleColor = Color(_titleColor);
    final textColor = Color(_textColor);
    final scaffold = Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chats',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: (_titleSizeSp + 4).toDouble(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: titleColor),
                    onPressed: _loading ? null : _load,
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: titleColor),
                    onPressed: _close,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _chats.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No hay chats disponibles.\nActiva el modo conversación en al menos una app.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor.withValues(alpha:0.8),
                                fontSize: _textSizeSp.toDouble(),
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                            itemCount: _chats.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) =>
                                _buildChatTile(_chats[index]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
    // canPop:false + finalizar la Activity: el gesto "atrás" cierra el overlay y
    // vuelve a la app previa, en lugar de hacer pop a la ruta '/' (EmisorScreen)
    // que el initialRoute deja debajo en el stack.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: scaffold,
    );
  }

  Widget _buildChatTile(_ChatEntry entry) {
    final titleColor = Color(_titleColor);
    final textColor = Color(_textColor);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openChat(entry),
        onLongPress: () => _showChatOptions(entry),
        child: Container(
          decoration: BoxDecoration(
            color: Color(_itemBgColor),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(_itemBorderColor)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildIcon(entry, titleColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: _titleSizeSp.toDouble(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry.preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor.withValues(alpha:0.85),
                          fontSize: _textSizeSp.toDouble(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(entry.tsMs),
                style: TextStyle(
                  color: textColor.withValues(alpha:0.6),
                  fontSize: (_textSizeSp - 2).clamp(8, 40).toDouble(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(_ChatEntry entry, Color fallbackColor) {
    final bytes = entry.iconBytes;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallbackIcon(fallbackColor),
        ),
      );
    }
    return _fallbackIcon(fallbackColor);
  }

  Widget _fallbackIcon(Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.chat_bubble_outline, color: color, size: 22),
    );
  }
}
