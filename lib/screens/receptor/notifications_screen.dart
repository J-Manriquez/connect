import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect/screens/receptor/notification_detail_screen.dart';
import 'package:connect/services/firebase_service.dart';
import 'package:connect/services/local_notification_service.dart';
import 'package:connect/services/notification_cache_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:connect/services/receptor_service.dart';

class UnreadNotificationsScreen extends StatefulWidget {
  const UnreadNotificationsScreen({super.key});

  @override
  State<UnreadNotificationsScreen> createState() =>
      _UnreadNotificationsScreenState();
}

class _UnreadNotificationsScreenState extends State<UnreadNotificationsScreen> {
  final ReceptorService _receptorService = ReceptorService();

  bool _isLoading = false;
  List<Map<String, dynamic>> _unreadNotifications = [];
  List<Map<String, dynamic>> _readNotifications = [];
  StreamSubscription? _unreadSubscription;
  StreamSubscription? _readSubscription;
  bool _notificationsEnabled = false;
  Timer? _hiveRefreshTimer;
  bool _showUnread = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadNotificationSettings();
    _startHiveRefresh();
  }

  Future<void> _loadNotificationSettings() async {
    final notificationsEnabled =
        await LocalNotificationService.areNotificationsEnabled();
    setState(() {
      _notificationsEnabled = notificationsEnabled;
    });
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    _readSubscription?.cancel();
    _hiveRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _startListening();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startListening() {
    _unreadSubscription = _receptorService
        .listenForUnseenNotifications()
        .listen(
          (notifications) {
            setState(() {
              _unreadNotifications = notifications;
            });
            _mergeHiveUnreadIntoState();
          },
          onError: (error) {
          },
        );

    _readSubscription = _receptorService.listenForSeenNotifications().listen(
      (notifications) {
        setState(() {
          _readNotifications = notifications;
        });
        _mergeHiveReadIntoState();
      },
      onError: (_) {},
    );
  }

  void _startHiveRefresh() {
    _hiveRefreshTimer?.cancel();
    _hiveRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _mergeHiveUnreadIntoState();
      await _mergeHiveReadIntoState();
    });
  }

  Future<void> _mergeHiveUnreadIntoState() async {
    try {
      final local = await BtHiveStorageService.getLocalNotificationsForUi(
        includeVisualized: false,
      );
      if (!mounted) return;

      final Map<String, Map<String, dynamic>> byId = {};
      for (final n in _unreadNotifications) {
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
        _unreadNotifications = merged;
      });
    } catch (_) {}
  }

  Future<void> _mergeHiveReadIntoState() async {
    try {
      final local = await BtHiveStorageService.getLocalNotificationsForUi(
        includeVisualized: true,
      );
      final localSeen =
          local.where((n) => n['status-visualizacion'] == true).toList();
      if (!mounted) return;

      final Map<String, Map<String, dynamic>> byId = {};
      for (final n in _readNotifications) {
        final key = (n['notificationId'] ?? n['id'] ?? '').toString();
        if (key.isEmpty) continue;
        byId[key] = n;
      }
      for (final n in localSeen) {
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
        _readNotifications = merged;
      });
    } catch (_) {}
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    try {
      final notificationId =
          (notification['notificationId'] ?? notification['id'])?.toString();
      final timestamp = notification['timestamp'] as Timestamp?;
      if (notificationId == null || notificationId.isEmpty) return;

      await BtHiveStorageService.deleteOutboxEntry(notificationId);

      if (timestamp == null) return;
      final date = timestamp.toDate();
      final dateId =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      await FirebaseService().deleteNotification(notificationId, dateId);
    } catch (_) {}
  }

  // Marcar notificación como leída
  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    try {
      final String notificationId =
          (notification['notificationId'] ?? notification['id'] ?? '').toString();
      if (notificationId.isNotEmpty) {
        await NotificationCacheService.markAsVisualized(notificationId);
        await BtHiveStorageService.markVisualized(notificationId, true);
        await _receptorService.updateNotificationVisualizationStatus(
          notificationId,
          true,
        );

        // Eliminar la notificación de la lista local
        if (!mounted) return;
        setState(() {
          _unreadNotifications.removeWhere(
            (item) =>
                (item['notificationId'] ?? item['id'] ?? '').toString() ==
                notificationId,
          );
        });
      }
    } catch (e) {
      // print('Error al marcar notificación como leída: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al marcar como leída: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _showUnread ? _unreadNotifications : _readNotifications;
    return Scaffold(
      appBar: AppBar(
        title: const Text('notificaciones'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 8) / 2;
                        return ToggleButtons(
                          isSelected: [_showUnread, !_showUnread],
                          onPressed: (index) {
                            setState(() {
                              _showUnread = index == 0;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          constraints: BoxConstraints(
                            minWidth: width,
                            minHeight: 40,
                          ),
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('No leídas'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Leídas'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: notifications.isEmpty
                        ? Center(
                            child: Text(
                              _showUnread
                                  ? 'No hay notificaciones no leídas'
                                  : 'No hay notificaciones leídas',
                            ),
                          )
                        : ListView.builder(
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final notification = notifications[index];
                              final notificationId = (notification['notificationId'] ??
                                      notification['id'] ??
                                      '')
                                  .toString();
                              final timestamp = notification['timestamp'];
                              final timestampKey = timestamp is Timestamp
                                  ? timestamp.millisecondsSinceEpoch.toString()
                                  : timestamp?.toString() ?? '';
                              final dismissKey = notificationId.isNotEmpty
                                  ? ValueKey('$notificationId-$timestampKey')
                                  : UniqueKey();

                              return Dismissible(
                                key: dismissKey,
                                direction: DismissDirection.endToStart,
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
                                  await _deleteNotification(notification);
                                  if (!mounted) return;
                                  setState(() {
                                    if (_showUnread) {
                                      _unreadNotifications.removeWhere((n) {
                                        final id = (n['notificationId'] ??
                                                n['id'] ??
                                                '')
                                            .toString();
                                        return id == notificationId;
                                      });
                                    } else {
                                      _readNotifications.removeWhere((n) {
                                        final id = (n['notificationId'] ??
                                                n['id'] ??
                                                '')
                                            .toString();
                                        return id == notificationId;
                                      });
                                    }
                                  });
                                },
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            NotificationDetailScreen(
                                          notificationData: notification,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.only(
                                      left: 5,
                                      right: 5,
                                      bottom: 5,
                                      top: 5,
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        notification['title'] ?? 'Sin título',
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
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _formatTimestamp(
                                              notification['timestamp'],
                                            ),
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                          if (_showUnread)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.check_circle_outline,
                                              ),
                                              tooltip: 'Marcar como leída',
                                              onPressed: () =>
                                                  _markAsRead(notification),
                                            ),
                                        ],
                                      ),
                                      ),
                                    ),
                                  ),
                                );
                            },
                          ),
                  ),
                ],
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
                2, // 0: Configuración, 1: Conexión, 2: Notificaciones
            onTap: (index) {
              switch (index) {
                case 0:
                  Navigator.pushReplacementNamed(context, '/receptor_settings');
                  break;
                case 1:
                  Navigator.pushReplacementNamed(context, '/notificaciones');
                  break;
                case 2:
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

  // Formatear timestamp para mostrar
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    final DateTime date = (timestamp as Timestamp).toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
