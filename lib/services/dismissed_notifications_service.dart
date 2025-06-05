import 'package:shared_preferences/shared_preferences.dart';

class DismissedNotificationsService {
  static const String _keyDismissedNotifications = 'dismissed_notifications';
  static const String _keyDismissedTimestamp = 'dismissed_timestamp';
  
  // Marcar una notificación como eliminada
  static Future<void> markAsDismissed(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedList = prefs.getStringList(_keyDismissedNotifications) ?? [];
    
    if (!dismissedList.contains(notificationId)) {
      dismissedList.add(notificationId);
      await prefs.setStringList(_keyDismissedNotifications, dismissedList);
      await prefs.setInt('${_keyDismissedTimestamp}_$notificationId', DateTime.now().millisecondsSinceEpoch);
      print('Notificación marcada como eliminada: $notificationId');
    }
  }
  
  // Verificar si una notificación fue eliminada
  static Future<bool> isDismissed(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedList = prefs.getStringList(_keyDismissedNotifications) ?? [];
    return dismissedList.contains(notificationId);
  }
  
  // Limpiar notificaciones eliminadas antiguas (más de 7 días)
  static Future<void> cleanOldDismissedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedList = prefs.getStringList(_keyDismissedNotifications) ?? [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final sevenDaysAgo = now - (7 * 24 * 60 * 60 * 1000); // 7 días en milisegundos
    
    final updatedList = <String>[];
    
    for (final notificationId in dismissedList) {
      final timestamp = prefs.getInt('${_keyDismissedTimestamp}_$notificationId') ?? now;
      if (timestamp > sevenDaysAgo) {
        updatedList.add(notificationId);
      } else {
        // Eliminar timestamp de notificación antigua
        await prefs.remove('${_keyDismissedTimestamp}_$notificationId');
      }
    }
    
    await prefs.setStringList(_keyDismissedNotifications, updatedList);
    print('Limpieza completada. Notificaciones eliminadas: ${dismissedList.length - updatedList.length}');
  }
  
  // Limpiar todas las notificaciones eliminadas
  static Future<void> clearAllDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedList = prefs.getStringList(_keyDismissedNotifications) ?? [];
    
    // Eliminar todos los timestamps
    for (final notificationId in dismissedList) {
      await prefs.remove('${_keyDismissedTimestamp}_$notificationId');
    }
    
    await prefs.remove(_keyDismissedNotifications);
    print('Todas las notificaciones eliminadas han sido limpiadas');
  }
}