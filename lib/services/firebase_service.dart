import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connect/models/device_data.dart';
import 'package:connect/models/notification_data.dart';
import 'package:connect/services/notification_filters_config_service.dart';
import 'dart:convert';
import 'dart:math';

class FirebaseService {
  static const String _deviceIdKey = 'device_id';
  static const String _lastNotificationKey = 'last_notification_hash';
  static const String _recentNotificationHashesKey = 'recent_notification_hashes_v1';
  static const int _recentNotificationMaxEntries = 2000;
  static const int _recentNotificationTtlMs = 24 * 60 * 60 * 1000;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Método para obtener o generar el ID del dispositivo
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      // Generar un ID numérico de 6 dígitos
      deviceId = _generateDeviceId();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  // Elimina una notificación específica de Firebase
  Future<void> deleteNotification(String notificationId, String dateId) async {
    final deviceId = await getDeviceId();

    // Referencia al documento que contiene la notificación
    final dayDocRef = _firestore
        .collection('dispositivos')
        .doc(deviceId)
        .collection('notificaciones')
        .doc(dateId);

    try {
      // Eliminar la notificación específica usando FieldValue.delete()
      await dayDocRef.update({
        'notificaciones.$notificationId': FieldValue.delete(),
      });

      // print('Notificación eliminada: $notificationId');

      // Verificar si quedan notificaciones en el documento
      final docSnapshot = await dayDocRef.get();
      final data = docSnapshot.data();

      if (data != null && data.containsKey('notificaciones')) {
        final Map<String, dynamic> notificationsMap =
            data['notificaciones'] as Map<String, dynamic>;

        // Si no quedan notificaciones, eliminar el documento del día
        if (notificationsMap.isEmpty) {
          await dayDocRef.delete();
          // print('Documento del día eliminado: $dateId (sin notificaciones)');
        }
      }
    } catch (e) {
      // print('Error al eliminar notificación: $e');
    }
  }

  // Genera un ID numérico de 6 dígitos
  String _generateDeviceId() {
    final random = Random();
    int id = random.nextInt(900000) + 100000; // Asegura que sea de 6 dígitos
    return id.toString();
  }

  // Inicializa la estructura de datos en Firebase si no existe
  Future<void> initializeFirebaseData(bool isServiceRunning) async {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);

    // Verificar si el documento ya existe
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) {
      // Crear el documento con la estructura inicial
      final DeviceData deviceData = DeviceData(
        id: deviceId,
        statusServicio: isServiceRunning,
        ultimaActualizacion: [
          ActualizacionData(
            fecha: DateTime.now(),
            tipoActualizacion: 'inicialización',
          ),
        ],
        listaApps: [],
      );

      await docRef.set(deviceData.toMap());
      // print('Documento inicializado en Firebase con ID: $deviceId');
    } else {
      // print('El documento ya existe en Firebase con ID: $deviceId');
    }
  }

  // Actualiza el estado del servicio
  Future<void> updateServiceStatus(bool isRunning) async {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);

    await docRef.update({
      'status-servicio': isRunning,
      'ultima-actualizacion': FieldValue.arrayUnion([
        {
          'fecha': Timestamp.now(),
          'tipo-actualizacion': 'cambio-estado-servicio',
        },
      ]),
    });

    // print('Estado del servicio actualizado: $isRunning');
  }

  // Actualiza el estado de vinculación
  Future<void> updateLinkStatus(bool isLinked, String deviceId) async {
    // final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);

    await docRef.update({
      'status-vinculacion': isLinked,
      'ultima-actualizacion': FieldValue.arrayUnion([
        {
          'fecha': Timestamp.now(),
          'tipo-actualizacion': 'cambio-estado-vinculacion',
        },
      ]),
    });

    // print('Estado de vinculación actualizado: $isLinked');
  }

  // Actualiza el estado de guardado
  Future<void> updateSaveStatus(bool isSaving) async {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);

    await docRef.update({
      'status-guardado': isSaving,
      'ultima-actualizacion': FieldValue.arrayUnion([
        {
          'fecha': Timestamp.now(),
          'tipo-actualizacion': 'cambio-estado-guardado',
        },
      ]),
    });

    // print('Estado de guardado actualizado: $isSaving');
  }

  // Actualiza la lista de aplicaciones
  Future<void> updateAppList(List<AppData> apps) async {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);

    try {
      // Verificar si el guardado está habilitado
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final isSaving = data?['status-guardado'] ?? false;

        if (!isSaving) {
          // print(            'Guardado en Firebase no está habilitado, omitiendo actualización de apps',          );
          return;
        }
      }

      // Actualizar la lista de aplicaciones
      await docRef.update({
        'lista-apps': apps.map((app) => app.toMap()).toList(),
        'ultima-actualizacion': FieldValue.arrayUnion([
          {
            'fecha': Timestamp.now(),
            'tipo-actualizacion': 'actualizacion-lista-apps',
          },
        ]),
      });

      // print(        'Lista de aplicaciones actualizada en Firebase: ${apps.length} apps',      );
    } catch (e) {
      // print('Error al actualizar lista de aplicaciones en Firebase: $e');
      rethrow;
    }
  }

  // Obtiene la lista de aplicaciones
  Future<List<AppData>> getAppList() async {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);

    try {
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        return [];
      }

      final data = docSnapshot.data();
      if (data == null || !data.containsKey('lista-apps')) {
        return [];
      }

      final List<dynamic> appsList = data['lista-apps'];
      return appsList.map((appData) => AppData.fromMap(appData)).toList();
    } catch (e) {
      // print('Error al obtener lista de aplicaciones desde Firebase: $e');
      return [];
    }
  }

  Future<List<AppData>> getAppListForDeviceId(String deviceId) async {
    final id = deviceId.trim();
    if (id.isEmpty) return [];
    final docRef = _firestore.collection('dispositivos').doc(id);

    try {
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        return [];
      }

      final data = docSnapshot.data();
      if (data == null || !data.containsKey('lista-apps')) {
        return [];
      }

      final List<dynamic> appsList = data['lista-apps'];
      return appsList.map((appData) => AppData.fromMap(appData)).toList();
    } catch (_) {
      return [];
    }
  }

  // Obtiene el estado de guardado
  Future<bool> getSaveStatus() async {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('dispositivos').doc(deviceId);

    try {
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        return false;
      }

      final data = docSnapshot.data();
      return data?['status-guardado'] ?? false;
    } catch (e) {
      // print('Error al obtener estado de guardado desde Firebase: $e');
      return false;
    }
  }

  // Obtiene el estado de vinculación
  Future<bool> getLinkStatus() async {
    final deviceId = await getDeviceId();
    // print('[DEBUG] getLinkStatus: deviceId = \$deviceId');
    final docRef = _firestore.collection('dispositivos').doc(deviceId);
    try {
      final docSnapshot = await docRef.get();
      // print(        '[DEBUG] getLinkStatus: docSnapshot.exists = \${docSnapshot.exists}',      );
      if (!docSnapshot.exists) {
        return false;
      }
      final data = docSnapshot.data();
      final status = data?['status-vinculacion'] ?? false;
      // print('[DEBUG] getLinkStatus: status-vinculacion = \$status');
      return status;
    } catch (e) {
      // print('Error al obtener estado de vinculación desde Firebase: \$e');
      return false;
    }
  }

  // Método mejorado para verificar si una notificación debe ser filtrada
  Future<bool> _shouldFilterNotification(Map<String, dynamic> notification) async {
    final config = await NotificationFiltersConfigService.getConfig();
    final String packageName = notification['packageName'] ?? '';

    // Filtro universal: Notificaciones vacías (aplicar a todas las aplicaciones)
    String clean(dynamic v) {
      final raw = (v ?? '').toString().trim();
      final lower = raw.toLowerCase();
      if (lower == 'null' || lower == 'undefined') return '';
      return raw;
    }

    final String title = clean(notification['title']);
    final String text = clean(notification['text']);
    final String bigText = clean(notification['bigText']);
    final String subText = clean(notification['subText']);
    final String summaryText = clean(notification['summaryText']);
    final String infoText = clean(notification['infoText']);
    final String contentInfo = clean(notification['contentInfo']);
    final String body = clean(notification['body']);
    final String mensaje = clean(notification['mensaje']);
    final String contenido = clean(notification['contenido']);
    
    final bool hasAnyBody =
        title.isNotEmpty ||
        text.isNotEmpty ||
        bigText.isNotEmpty ||
        subText.isNotEmpty ||
        summaryText.isNotEmpty ||
        infoText.isNotEmpty ||
        contentInfo.isNotEmpty ||
        body.isNotEmpty ||
        mensaje.isNotEmpty ||
        contenido.isNotEmpty;
    if (config.isEnabled('filter_empty', fallback: true) && !hasAnyBody) {
      return true;
    }

    final List<String> allTexts = [
      clean(notification['title']),
      clean(notification['text']),
      clean(notification['bigText']),
      clean(notification['subText']),
      clean(notification['summaryText']),
      clean(notification['infoText']),
      clean(notification['contentInfo']),
      clean(notification['body']),
      clean(notification['mensaje']),
      clean(notification['contenido']),
      clean(notification['titulo']),
    ];
    
    final String allContent = allTexts.join(' ').toLowerCase();
    final String normalizedContent = allContent
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    if (config.isEnabled('filter_global_message_patterns', fallback: true)) {
      final List<RegExp> globalMessagePatterns = [
        RegExp(r'\b\d+\s*mensajes?\s*nuevos?\b'),
        RegExp(r'\b\d+\s*new\s*messages?\b'),
      ];
      for (final pattern in globalMessagePatterns) {
        if (pattern.hasMatch(normalizedContent)) {
          return true;
        }
      }
    }
    
    // Solo aplicar filtros a WhatsApp e Instagram
    if (packageName == 'com.whatsapp' || packageName == 'com.whatsapp.w4b' || 
        packageName == 'com.instagram.android') {
      // print('Contenido normalizado para filtro: "$normalizedContent"');
      
      // Filtros específicos para Instagram
      if (packageName == 'com.instagram.android') {
        // Filtro 1: Subida de contenido multimedia
        if (config.isEnabled('instagram_filter_upload', fallback: true)) {
          final List<String> uploadKeywords = [
            'subiendo contenido multimedia',
            'uploading media content',
            'subiendo contenido',
            'uploading content',
          ];
          
          for (final keyword in uploadKeywords) {
            if (normalizedContent.contains(keyword)) {
              // print('Notificación filtrada: Subida de contenido - "$normalizedContent"');
              return true;
            }
          }
        }
        
        // Filtro 2: Historias
        if (config.isEnabled('instagram_filter_story', fallback: true)) {
          final List<String> storyKeywords = [
            'subiendo historia',
            'uploading story',
            'se subio la historia',
            'story uploaded',
            'historia subida',
            'story posted',
          ];
          
          for (final keyword in storyKeywords) {
            if (normalizedContent.contains(keyword)) {
              // print('Notificación filtrada: Historia - "$normalizedContent"');
              return true;
            }
          }
        }
        
        // Filtro 3: Llamadas y videollamadas (similar a WhatsApp)
        if (config.isEnabled('instagram_filter_calls', fallback: true)) {
          final List<String> callKeywords = [
            'llamando',
            'llamada en curso',
            'calling',
            'llamada entrante',
            'incoming call',
            'llamada perdida',
            'missed call',
            'llamada de',
            'call from',
            'videollamada',
            'video call',
            'video calling',
            'llamada de video',
          ];
          
          for (final keyword in callKeywords) {
            if (normalizedContent.contains(keyword)) {
              // print('Notificación filtrada: Llamada Instagram - "$normalizedContent"');
              return true;
            }
          }
        }
      }
      
      // Filtros existentes para WhatsApp (mantener como están)
      if (packageName == 'com.whatsapp' || packageName == 'com.whatsapp.w4b') {
        if (config.isEnabled('whatsapp_filter_sending', fallback: true)) {
          final List<String> sendingKeywords = [
            'enviando',
            'sending',
          ];
          for (final keyword in sendingKeywords) {
            if (normalizedContent.contains(keyword)) {
              return true;
            }
          }
        }

        // Filtro 1: Resúmenes de mensajes
        if (config.isEnabled('whatsapp_filter_message_summary', fallback: true)) {
          final List<RegExp> messagePatterns = [
            RegExp(r'\d+\s*mensajes?\s*de\s*\d+\s*chats?'),
            RegExp(r'\d+\s*mensajes?\s*de\s*\d+\s*chat\s*s?'),
            RegExp(r'\d+\s*messages?\s*from\s*\d+\s*chats?'),
            RegExp(r'\d+\s*nuevos?\s*mensajes?'),
            RegExp(r'\d+\s*new\s*messages?'),
            RegExp(r'\d+\s*mensajes?\s*nuevos?'), // Nuevo filtro
            RegExp(r'\d+\s*mensajes?\s*nuevos?\s*de\s*\d+\s*chats?'),
            RegExp(r'\d+\s*mensajes?\s*nuevos?\s*\d+\s*chats?'),
            RegExp(r'\d+\s*mensajes?\s*en\s*\d+\s*chats?'),
            RegExp(r'\d+\s*messages?\s*in\s*\d+\s*chats?'),
            RegExp(r'\d+\s*new\s*messages?\s*\d+\s*chats?'),
          ];
          
          for (final pattern in messagePatterns) {
            if (pattern.hasMatch(normalizedContent)) {
              // print('Notificación filtrada: Resumen de mensajes - "$normalizedContent"');
              return true;
            }
          }

          if (normalizedContent.contains('mensajes') &&
              normalizedContent.contains('chat') &&
              RegExp(r'\b\d+\s*mensajes?\b').hasMatch(normalizedContent) &&
              RegExp(r'\b\d+\s*chat').hasMatch(normalizedContent)) {
            return true;
          }
        }
        
        // Filtro 2: Llamadas
        if (config.isEnabled('whatsapp_filter_calls', fallback: true)) {
          final List<String> callKeywords = [
            'llamando',
            'llamada',
            'llamada en curso',
            'calling',
            'llamada entrante',
            'incoming call',
            'llamada perdida',
            'missed call',
            'llamada de',
            'call from',
            'videollamada',
            'video call',
          ];
          
          for (final keyword in callKeywords) {
            if (normalizedContent.contains(keyword)) {
              // print('Notificación filtrada: Llamada - "$normalizedContent"');
              return true;
            }
          }
        }
        
        // Filtro 3: Copias de seguridad
        if (config.isEnabled('whatsapp_filter_backup', fallback: true)) {
          final List<String> backupKeywords = [
            'copia de seguridad',
            'backup',
            'respaldo',
            'copia de seg',
            'backing up',
            'guardando copia',
          ];
          
          for (final keyword in backupKeywords) {
            if (normalizedContent.contains(keyword)) {
              // print('Notificación filtrada: Copia de seguridad - "$normalizedContent"');
              return true;
            }
          }
        }

        if (config.isEnabled('whatsapp_filter_checking', fallback: true)) {
          if (normalizedContent.contains('comprobando si hay mensajes nuevos') ||
              normalizedContent.contains('checking for new messages')) {
            return true;
          }
        }
        
        // Filtro 4: Notificaciones genéricas y contenido no disponible (NUEVOS FILTROS)
        if (config.isEnabled('whatsapp_filter_generic', fallback: true)) {
          final List<String> genericKeywords = [
            'nueva notificacion',
            'new notification',
            'contenido no disponible',
            'content not available',
            'content unavailable',
            'mensaje no disponible',
            'message not available',
            'sin contenido',
            'no content',
          ];
          
          for (final keyword in genericKeywords) {
            if (normalizedContent.contains(keyword)) {
              // print('Notificación filtrada: Contenido genérico - "$normalizedContent"');
              return true;
            }
          }
        }
      }
    }

    if (NotificationFiltersConfigService.shouldFilterByCustomRules(
      config: config,
      packageName: packageName,
      normalizedContent: normalizedContent,
    )) {
      return true;
    }
    
    return false;
  }

  // Método para generar un hash único de la notificación
  String _generateNotificationHash(Map<String, dynamic> notification) {
    // Crear un string único basado en los campos principales de la notificación
    final String packageName = notification['packageName'] ?? '';
    final String title = notification['title'] ?? '';
    final String text = notification['text'] ?? '';
    final String bigText = notification['bigText'] ?? '';
    final String body = notification['body'] ?? '';
    final String mensaje = notification['mensaje'] ?? '';
    final String contenido = notification['contenido'] ?? '';
    
    // Combinar todos los campos relevantes
    final String combinedContent = '$packageName|$title|$text|$bigText|$body|$mensaje|$contenido';
    
    // Generar hash simple (puedes usar crypto para algo más robusto)
    return combinedContent.hashCode.toString();
  }

  String _extractStableSbnKey(Map<String, dynamic> notification) {
    String clean(dynamic v) {
      final raw = (v ?? '').toString().trim();
      final lower = raw.toLowerCase();
      if (lower == 'null' || lower == 'undefined') return '';
      return raw;
    }

    final direct = clean(notification['sbnKey']);
    if (direct.isNotEmpty) return direct;
    final alt = clean(notification['key']);
    if (alt.isNotEmpty) return alt;

    final nested = notification['extras'];
    if (nested is Map) {
      final m = Map<String, dynamic>.from(nested);
      final nestedKey = clean(m['sbnKey']);
      if (nestedKey.isNotEmpty) return nestedKey;
      final nestedAlt = clean(m['key']);
      if (nestedAlt.isNotEmpty) return nestedAlt;
    }

    return '';
  }

  String _fnv1a32Hex(String input) {
    final data = utf8.encode(input);
    int hash = 0x811c9dc5;
    for (final b in data) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _generateStableSignatureId(Map<String, dynamic> notification) {
    final pkg = (notification['packageName'] ?? '').toString().trim();
    final normalized =
        NotificationFiltersConfigService.normalizedNotificationContent(notification);
    final source = '$pkg|$normalized';
    return _fnv1a32Hex(source);
  }

  // Método para verificar si la notificación es duplicada
  Future<bool> _isDuplicateNotification(Map<String, dynamic> notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String currentHash = _generateNotificationHash(notification);
      final String stableKey = _extractStableSbnKey(notification);
      final String signatureId = _generateStableSignatureId(notification);
      final String stableKeyEntry = stableKey.isEmpty ? '' : 'k:$stableKey';
      final String signatureEntry = signatureId.isEmpty ? '' : 's:$signatureId';

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final raw = prefs.getString(_recentNotificationHashesKey);
      Map<String, dynamic> map;
      try {
        map = raw == null || raw.isEmpty
            ? <String, dynamic>{}
            : (jsonDecode(raw) as Map).cast<String, dynamic>();
      } catch (_) {
        map = <String, dynamic>{};
      }

      final cutoffMs = nowMs - _recentNotificationTtlMs;
      final keysToRemove = <String>[];
      for (final entry in map.entries) {
        final ts = entry.value;
        final tsMs = ts is int ? ts : int.tryParse(ts.toString());
        if (tsMs == null || tsMs < cutoffMs) {
          keysToRemove.add(entry.key);
        }
      }
      for (final k in keysToRemove) {
        map.remove(k);
      }

      if (map.containsKey(currentHash) ||
          (stableKeyEntry.isNotEmpty && map.containsKey(stableKeyEntry)) ||
          (signatureEntry.isNotEmpty && map.containsKey(signatureEntry))) {
        await prefs.setString(_lastNotificationKey, currentHash);
        await prefs.setString(_recentNotificationHashesKey, jsonEncode(map));
        return true;
      }

      map[currentHash] = nowMs;
      if (stableKeyEntry.isNotEmpty) map[stableKeyEntry] = nowMs;
      if (signatureEntry.isNotEmpty) map[signatureEntry] = nowMs;
      if (map.length > _recentNotificationMaxEntries) {
        final sorted = map.entries.toList()
          ..sort((a, b) {
            final ta = a.value is int ? a.value as int : int.tryParse(a.value.toString()) ?? 0;
            final tb = b.value is int ? b.value as int : int.tryParse(b.value.toString()) ?? 0;
            return ta.compareTo(tb);
          });
        final toDrop = sorted.length - _recentNotificationMaxEntries;
        for (var i = 0; i < toDrop; i++) {
          map.remove(sorted[i].key);
        }
      }

      await prefs.setString(_lastNotificationKey, currentHash);
      await prefs.setString(_recentNotificationHashesKey, jsonEncode(map));
      return false;
    } catch (e) {
      // print('Error al verificar notificación duplicada: $e');
      return false;
    }
  }

  // Guarda una notificación en Firebase
  Future<void> saveNotification(Map<String, dynamic> notification) async {
    // Verificar si la notificación debe ser filtrada
    if (await _shouldFilterNotification(notification)) {
      // print('Notificación filtrada, no se guardará en Firebase');
      return;
    }

    // Verificar si es una notificación duplicada
    if (await _isDuplicateNotification(notification)) {
      // print('Notificación duplicada, no se guardará en Firebase');
      return;
    }

    final deviceId = await getDeviceId();
    final stableKey = _extractStableSbnKey(notification);
    final signatureId = _generateStableSignatureId(notification);
    if (stableKey.isNotEmpty && (notification['sbnKey'] ?? '').toString().trim().isEmpty) {
      notification['sbnKey'] = stableKey;
    }
    if (signatureId.isNotEmpty &&
        (notification['signatureId'] ?? '').toString().trim().isEmpty) {
      notification['signatureId'] = signatureId;
    }
    final notificationData = NotificationData.fromNotificationMap(notification);

    // Obtener la fecha actual en formato YYYY-MM-DD para usar como ID del documento
    final DateTime now = DateTime.now();
    final String dateId =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Referencia al documento que agrupa las notificaciones del día
    final dayDocRef = _firestore
        .collection('dispositivos')
        .doc(deviceId)
        .collection('notificaciones')
        .doc(dateId);

    // Verificar si necesitamos crear el documento del día
    final dayDoc = await dayDocRef.get();
    if (!dayDoc.exists) {
      await dayDocRef.set({
        'fecha': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
      });
    } else {
      try {
        final data = dayDoc.data();
        if (data != null && data.containsKey('notificaciones')) {
          final existing = Map<String, dynamic>.from(data['notificaciones'] as Map);

          String clean(dynamic v) {
            final raw = (v ?? '').toString().trim();
            final lower = raw.toLowerCase();
            if (lower == 'null' || lower == 'undefined') return '';
            return raw;
          }

          for (final entry in existing.values) {
            if (entry is! Map) continue;
            final m = Map<String, dynamic>.from(entry);
            final extras = m['extras'];
            Map<String, dynamic>? em;
            if (extras is Map) em = Map<String, dynamic>.from(extras);

            final existingKey = clean(m['sbnKey']);
            final nestedKey = em == null ? '' : clean(em['sbnKey']);
            final keyToCompare = existingKey.isNotEmpty ? existingKey : nestedKey;
            if (stableKey.isNotEmpty && keyToCompare == stableKey) {
              return;
            }

            final existingSig = clean(m['signatureId']);
            final nestedSig = em == null ? '' : clean(em['signatureId']);
            final sigToCompare = existingSig.isNotEmpty ? existingSig : nestedSig;
            if (signatureId.isNotEmpty && sigToCompare == signatureId) {
              return;
            }
          }
        }
      } catch (_) {}
    }

    // Guardar la notificación como un campo en el documento del día
    await dayDocRef.update({
      'notificaciones.${notificationData.id}': notificationData.toMap(),
    });

    // print('Notificación guardada con ID: ${notificationData.id}');
  }

  // Actualiza el estado de visualización de una notificación
  Future<void> updateNotificationVisualizationStatus(
    String notificationId,
    String dateId,
    bool visualizado,
  ) async {
    final deviceId = await getDeviceId();

    // Referencia al documento que contiene la notificación
    final dayDocRef = _firestore
        .collection('dispositivos')
        .doc(deviceId)
        .collection('notificaciones')
        .doc(dateId);

    // Actualizar solo el campo de estado de visualización
    await dayDocRef.update({
      'notificaciones.$notificationId.status-visualizacion': visualizado,
    });

    // print(      'Estado de visualización actualizado para notificación $notificationId: $visualizado',    );
  }

  Future<bool> updateNotificationVisualizationStatusForDevice(
    String deviceId,
    String notificationId,
    String dateId,
    bool visualizado,
  ) async {
    final dayDocRef = _firestore
        .collection('dispositivos')
        .doc(deviceId)
        .collection('notificaciones')
        .doc(dateId);

    try {
      final dayDoc = await dayDocRef.get();
      if (!dayDoc.exists) {
        final parts = dateId.split('-');
        final int? year = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
        final int? month = parts.length >= 2 ? int.tryParse(parts[1]) : null;
        final int? day = parts.length >= 3 ? int.tryParse(parts[2]) : null;

        await dayDocRef.set({
          if (year != null && month != null && day != null)
            'fecha': Timestamp.fromDate(DateTime(year, month, day)),
        });
      }

      await dayDocRef.update({
        'notificaciones.$notificationId.status-visualizacion': visualizado,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // Obtiene todas las notificaciones almacenadas para el dispositivo
  Future<List<NotificationData>> getStoredNotifications() async {
    final deviceId = await getDeviceId();
    final List<NotificationData> allNotifications = [];

    try {
      // Obtener todos los documentos de la colección de notificaciones
      final querySnapshot = await _firestore
          .collection('dispositivos')
          .doc(deviceId)
          .collection('notificaciones')
          .get();

      // Iterar sobre cada documento (cada día)
      for (final dayDoc in querySnapshot.docs) {
        final data = dayDoc.data();
        if (data.containsKey('notificaciones')) {
          // Convertir el mapa de notificaciones a una lista de NotificationData
          final Map<String, dynamic> notificationsMap =
              data['notificaciones'] as Map<String, dynamic>;

          notificationsMap.forEach((notificationId, notificationData) {
            try {
              if (notificationData == null ||
                  notificationData is! Map<String, dynamic>) {
                return;
              }

              final Map<String, dynamic> notificationDataMap =
                  Map<String, dynamic>.from(notificationData);
              notificationDataMap['dateId'] = dayDoc.id;

              if (notificationDataMap.containsKey('timestamp') &&
                  notificationDataMap['timestamp'] is Timestamp) {
                allNotifications.add(
                  NotificationData.fromMap(notificationDataMap),
                );
              }
            } catch (_) {}
          });
        }
      }

      // Ordenar las notificaciones por fecha, más recientes primero
      allNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // // print('Notificaciones procesadas correctamente: ${allNotifications.length}');
      return allNotifications;
    } catch (e) {
      // print('Error al obtener notificaciones almacenadas: $e');
      return [];
    }
  }
}
