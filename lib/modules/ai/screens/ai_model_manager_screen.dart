// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:url_launcher/url_launcher.dart';

// import '../../../services/device_capability_service.dart';
// import '../models/ai_model_catalog.dart';
// import '../screens/ai_chat_screen.dart';
// import '../screens/ai_model_config_screen.dart';
// import '../services/ai_model_repository.dart';
// import '../services/ai_service.dart';

// class AiModelManagerScreen extends StatefulWidget {
//   const AiModelManagerScreen({super.key});

//   @override
//   State<AiModelManagerScreen> createState() => _AiModelManagerScreenState();
// }

// class _AiModelManagerScreenState extends State<AiModelManagerScreen> {
//   final AiService _ai = AiService.instance;

//   bool _deviceSupported = true;
//   bool _loading = true;
//   String? _activeModelId;
//   Set<String> _downloadedIds = <String>{};
//   String? _downloadingId;
//   int _progress = 0;
//   int? _receivedBytes;
//   int? _totalBytes;
//   AiStorageLocation _storageLocation = AiStorageLocation.internal;
//   String? _storagePath;

//   @override
//   void initState() {
//     super.initState();
//     DeviceCapabilityService.instance.supportsLocalAi().then((supported) {
//       if (!mounted) return;
//       setState(() => _deviceSupported = supported);
//       if (supported) _refresh();
//     });
//   }

//   String _formatBytes(int? bytes) {
//     if (bytes == null) return '--';
//     if (bytes < 1024) return '$bytes B';
//     final kb = bytes / 1024;
//     if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
//     final mb = kb / 1024;
//     if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
//     final gb = mb / 1024;
//     return '${gb.toStringAsFixed(2)} GB';
//   }

//   Future<void> _refresh() async {
//     setState(() => _loading = true);
//     final activeId = await _ai.activeModelId();
//     final downloaded = await _ai.downloadedModelIds();
//     final location = await _ai.storageLocation();
//     final path = await _ai.modelsDirectoryPath();
//     if (!mounted) return;
//     setState(() {
//       _activeModelId = activeId;
//       _downloadedIds = downloaded.toSet();
//       _storageLocation = location;
//       _storagePath = path;
//       _loading = false;
//     });
//   }

//   // ── Selector de ubicación de almacenamiento ──────────────────────────

//   Future<void> _showStorageLocationPicker() async {
//     final result = await showModalBottomSheet<AiStorageLocation>(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) => SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Ubicación de almacenamiento',
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
//               ),
//               const SizedBox(height: 6),
//               const Text(
//                 'Elige dónde se guardarán los modelos descargados.',
//                 style: TextStyle(color: Colors.black54),
//               ),
//               const SizedBox(height: 16),
//               RadioGroup<AiStorageLocation>(
//                 groupValue: _storageLocation,
//                 onChanged: (v) {
//                   if (v != null) Navigator.pop(context, v);
//                 },
//                 child: Column(
//                   children: AiStorageLocation.values
//                       .map(
//                         (loc) => RadioListTile<AiStorageLocation>(
//                           value: loc,
//                           title: Text(loc.label),
//                           subtitle: Text(
//                             loc.description,
//                             style: const TextStyle(fontSize: 12),
//                           ),
//                         ),
//                       )
//                       .toList(),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );

//     if (result == null || result == _storageLocation) return;
//     await _applyStorageLocation(result);
//   }

//   Future<void> _applyStorageLocation(AiStorageLocation location) async {
//     if (location == AiStorageLocation.custom) {
//       await _handleCustomLocation();
//       return;
//     }
//     await _ai.setStorageLocation(location);
//     await _refresh();
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Ubicación cambiada: ${location.label}')),
//     );
//   }

//   Future<void> _handleCustomLocation() async {
//     // 1. Solicitar permiso con explicación clara.
//     final permResult = await _ai.requestStoragePermission();

//     if (!mounted) return;

//     if (permResult == AiStoragePermissionResult.permanentlyDenied) {
//       await _showPermissionDeniedDialog();
//       return;
//     }
//     if (permResult == AiStoragePermissionResult.deniedCanRetry) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text(
//             'Permiso de almacenamiento denegado. '
//             'Vuelve a intentarlo o elige otra ubicación.',
//           ),
//         ),
//       );
//       return;
//     }

//     // 2. Permiso concedido — abrir selector de carpeta.
//     final picked = await _ai.pickCustomDirectory();
//     if (!mounted) return;

//     if (picked == null || picked.trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No se seleccionó ninguna carpeta.')),
//       );
//       return;
//     }

//     await _ai.setStorageLocation(
//       AiStorageLocation.custom,
//       customPath: picked,
//     );
//     await _refresh();
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Carpeta seleccionada: $picked')),
//     );
//   }

//   Future<void> _showPermissionDeniedDialog() async {
//     await showDialog<void>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Permiso denegado'),
//         content: const Text(
//           'El permiso de almacenamiento fue denegado permanentemente. '
//           'Para habilitarlo, ve a Ajustes del sistema → Aplicaciones → '
//           'esta app → Permisos → Almacenamiento.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancelar'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               openAppSettings();
//             },
//             child: const Text('Abrir Ajustes'),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Modelos ──────────────────────────────────────────────────────────

//   Future<void> _showModelDetails(AiModelCatalogEntry entry) async {
//     final isDownloaded = _downloadedIds.contains(entry.id);
//     final action = await showModalBottomSheet<String>(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) => SafeArea(
//         child: SingleChildScrollView(
//           padding: EdgeInsets.only(
//             left: 20,
//             right: 20,
//             top: 20,
//             bottom: MediaQuery.of(context).viewInsets.bottom + 24,
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 entry.displayName,
//                 style: const TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               _StarRating(rating: entry.qualityRating),
//               const SizedBox(height: 12),
//               Text(entry.description),
//               const SizedBox(height: 16),
//               _detailRow('Tamaño de descarga', _formatBytes(entry.approxSizeBytes)),
//               _detailRow('RAM mínima recomendada', '${entry.minRecommendedRamMb} MB'),
//               _detailRow('Formato', entry.fileKind.extension),
//               _detailRow('Token HF requerido', entry.requiresToken ? 'Sí' : 'No'),
//               if (entry.requiresToken) ...[
//                 const SizedBox(height: 12),
//                 _HfTokenField(modelId: entry.id),
//               ],
//               const SizedBox(height: 20),
//               SizedBox(
//                 width: double.infinity,
//                 child: FilledButton.icon(
//                   onPressed: () => Navigator.pop(
//                     context,
//                     isDownloaded ? 'activate' : 'download',
//                   ),
//                   icon: Icon(isDownloaded ? Icons.check_circle : Icons.download),
//                   label: Text(
//                     isDownloaded ? 'Activar este modelo' : 'Descargar este modelo',
//                   ),
//                 ),
//               ),
//               if (isDownloaded) ...[
//                 const SizedBox(height: 8),
//                 SizedBox(
//                   width: double.infinity,
//                   child: OutlinedButton.icon(
//                     onPressed: () => Navigator.pop(context, 'config'),
//                     icon: const Icon(Icons.tune),
//                     label: const Text('Configuración avanzada'),
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 SizedBox(
//                   width: double.infinity,
//                   child: OutlinedButton.icon(
//                     onPressed: () => Navigator.pop(context, 'delete'),
//                     icon: const Icon(Icons.delete_outline),
//                     label: const Text('Eliminar descarga'),
//                     style: OutlinedButton.styleFrom(
//                       foregroundColor: Colors.red,
//                     ),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );

//     if (action == 'download') {
//       await _downloadModel(entry);
//     } else if (action == 'activate') {
//       await _activateModel(entry);
//     } else if (action == 'config') {
//       await _openModelConfig(entry);
//     } else if (action == 'delete') {
//       await _deleteModel(entry);
//     }
//   }

//   Widget _detailRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8),
//       child: Row(
//         children: [
//           SizedBox(
//             width: 180,
//             child: Text(
//               label,
//               style: const TextStyle(fontWeight: FontWeight.w600),
//             ),
//           ),
//           Expanded(child: Text(value)),
//         ],
//       ),
//     );
//   }

//   Future<void> _downloadModel(AiModelCatalogEntry entry) async {
//     debugPrint('[AI][mgr][_downloadModel] START id=${entry.id}  name="${entry.displayName}"  size=${entry.approxSizeBytes}  url=${entry.downloadUrl}');
//     setState(() {
//       _downloadingId = entry.id;
//       _progress = 0;
//       _receivedBytes = 0;
//       _totalBytes = null;
//     });

//     try {
//       debugPrint('[AI][mgr][_downloadModel] llamando AiService.downloadModel...');
//       await _ai.downloadModel(
//         entry.id,
//         onProgress: (progress, received, total) {
//           if (!mounted) return;
//           if (progress % 5 == 0) {
//             debugPrint('[AI][mgr][_downloadModel] ${entry.id}  $progress%  ${received}B / ${total ?? "?"}B');
//           }
//           setState(() {
//             _progress = progress;
//             _receivedBytes = received;
//             _totalBytes = total;
//           });
//         },
//       );
//       debugPrint('[AI][mgr][_downloadModel] descarga completada — activando modelo...');
//       await _activateModel(entry, showSnackbar: false);
//       if (!mounted) return;
//       debugPrint('[AI][mgr][_downloadModel] OK "${entry.displayName}" descargado y activado');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('${entry.displayName} descargado y activado')),
//       );
//     } catch (e, st) {
//       debugPrint('[AI][mgr][_downloadModel] ERROR id=${entry.id}: $e\n$st');
//       if (!mounted) return;
//       final msg = e.toString();
//       final isAuth = msg.contains('401') || msg.contains('403');
//       if (isAuth) {
//         await _showAuthErrorModal(entry);
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             backgroundColor: Colors.red.shade700,
//             duration: const Duration(seconds: 10),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Error al descargar ${entry.displayName}',
//                   style: const TextStyle(
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   msg,
//                   style: const TextStyle(color: Colors.white, fontSize: 12),
//                   maxLines: 3,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ],
//             ),
//           ),
//         );
//       }
//     } finally {
//       debugPrint('[AI][mgr][_downloadModel] finally — limpiando estado downloadingId');
//       if (mounted) {
//         setState(() => _downloadingId = null);
//         await _refresh();
//       }
//     }
//   }

//   Future<void> _activateModel(
//     AiModelCatalogEntry entry, {
//     bool showSnackbar = true,
//   }) async {
//     debugPrint('[AI][mgr][_activateModel] START id=${entry.id}  showSnackbar=$showSnackbar');
//     try {
//       await _ai.setActiveModel(entry.id);
//       debugPrint('[AI][mgr][_activateModel] OK id=${entry.id}');
//     } catch (e, st) {
//       debugPrint('[AI][mgr][_activateModel] ERROR id=${entry.id}: $e\n$st');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error al activar ${entry.displayName}: $e')),
//         );
//       }
//       return;
//     }
//     if (!mounted) return;
//     await _refresh();
//     if (!mounted || !showSnackbar) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('${entry.displayName} activado')),
//     );
//   }

//   Future<void> _deleteModel(AiModelCatalogEntry entry) async {
//     debugPrint('[AI][mgr][_deleteModel] START id=${entry.id}');
//     try {
//       await _ai.deleteModel(entry.id);
//       debugPrint('[AI][mgr][_deleteModel] OK id=${entry.id}');
//     } catch (e, st) {
//       debugPrint('[AI][mgr][_deleteModel] ERROR id=${entry.id}: $e\n$st');
//     }
//     if (!mounted) return;
//     await _refresh();
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('${entry.displayName} eliminado')),
//     );
//   }

//   // ── Modal de error de autenticación (401 / 403) ───────────────────────

//   Future<void> _showAuthErrorModal(AiModelCatalogEntry entry) async {
//     final repoUrl = _hfRepoUrl(entry.downloadUrl);
//     const tokenUrl = 'https://huggingface.co/settings/tokens';

//     await showDialog<void>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: Row(
//           children: [
//             Icon(Icons.lock_outline, color: Colors.orange.shade700),
//             const SizedBox(width: 8),
//             const Expanded(
//               child: Text('Acceso denegado al modelo'),
//             ),
//           ],
//         ),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 'No se pudo descargar "${entry.displayName}" porque requiere '
//                 'autorización en HuggingFace.',
//                 style: const TextStyle(fontWeight: FontWeight.w500),
//               ),
//               const SizedBox(height: 16),
//               const Text(
//                 'Pasos a seguir:',
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 8),
//               _authStep(
//                 '1',
//                 'Crea una cuenta (o inicia sesión) en huggingface.co',
//               ),
//               _authStep(
//                 '2',
//                 'Abre la página del modelo y acepta su licencia pulsando '
//                 '"Agree and access repository".',
//               ),
//               _authStep(
//                 '3',
//                 'Ve a Settings → Access Tokens → New token (tipo Read).',
//               ),
//               _authStep(
//                 '4',
//                 'Copia el token (hf_...) y pégalo en la app tocando el modelo '
//                 'y abriendo su detalle.',
//               ),
//               _authStep('5', 'Intenta la descarga nuevamente.'),
//               const SizedBox(height: 16),
//               Container(
//                 padding: const EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   color: Colors.orange.shade50,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: Colors.orange.shade200),
//                 ),
//                 child: Text(
//                   'Si ya aceptaste la licencia de otro modelo Gemma, puede '
//                   'que este repo específico necesite aceptación por separado.',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: Colors.orange.shade900,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text('Cerrar'),
//           ),
//           OutlinedButton.icon(
//             icon: const Icon(Icons.open_in_browser, size: 16),
//             label: const Text('Crear token HF'),
//             onPressed: () async {
//               await _launchUrl(tokenUrl);
//             },
//           ),
//           FilledButton.icon(
//             icon: const Icon(Icons.open_in_browser, size: 16),
//             label: const Text('Página del modelo'),
//             onPressed: () async {
//               await _launchUrl(repoUrl);
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _authStep(String number, String text) => Padding(
//     padding: const EdgeInsets.only(bottom: 8),
//     child: Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         CircleAvatar(
//           radius: 10,
//           backgroundColor: Colors.blueGrey.shade100,
//           child: Text(
//             number,
//             style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
//           ),
//         ),
//         const SizedBox(width: 8),
//         Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
//       ],
//     ),
//   );

//   Future<void> _launchUrl(String url) async {
//     final uri = Uri.parse(url);
//     if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('No se pudo abrir: $url')),
//         );
//       }
//     }
//   }

//   /// Extrae la URL base del repo de HuggingFace desde la URL de descarga.
//   String _hfRepoUrl(String downloadUrl) {
//     // https://huggingface.co/org/repo/resolve/main/file → https://huggingface.co/org/repo
//     final uri = Uri.parse(downloadUrl);
//     final segments = uri.pathSegments; // [org, repo, resolve, main, file]
//     if (segments.length >= 2) {
//       return 'https://huggingface.co/${segments[0]}/${segments[1]}';
//     }
//     return 'https://huggingface.co';
//   }

//   // ── Config de modelo ──────────────────────────────────────────────────

//   Future<void> _openModelConfig(AiModelCatalogEntry entry) async {
//     await Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => AiModelConfigScreen(entry: entry),
//       ),
//     );
//   }

//   Future<void> _openChat() async {
//     if (_activeModelId == null || !_downloadedIds.contains(_activeModelId)) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Primero descarga y activa un modelo')),
//       );
//       return;
//     }
//     await Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => const AiChatScreen()),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Módulo IA'),
//         actions: [
//           if (_deviceSupported)
//             IconButton(
//               tooltip: 'Abrir chat de prueba',
//               icon: const Icon(Icons.chat_bubble_outline),
//               onPressed: _openChat,
//             ),
//         ],
//       ),
//       body: !_deviceSupported
//           ? const _UnsupportedDeviceBody()
//           : _loading
//           ? const Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 // ── Ubicación de almacenamiento ──────────────────────
//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
//                   child: Card(
//                     margin: EdgeInsets.zero,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: ListTile(
//                       leading: const Icon(Icons.folder_outlined),
//                       title: Text(_storageLocation.label),
//                       subtitle: Text(
//                         _storagePath ?? '...',
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                         style: const TextStyle(fontSize: 11),
//                       ),
//                       trailing: const Icon(Icons.chevron_right),
//                       onTap: _downloadingId != null
//                           ? null
//                           : _showStorageLocationPicker,
//                     ),
//                   ),
//                 ),
//                 // ── Progreso de descarga ─────────────────────────────
//                 if (_downloadingId != null)
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text('Descargando $_downloadingId...'),
//                         const SizedBox(height: 8),
//                         LinearProgressIndicator(value: _progress / 100),
//                         const SizedBox(height: 4),
//                         Text(
//                           '${_formatBytes(_receivedBytes)} / '
//                           '${_formatBytes(_totalBytes)} ($_progress%)',
//                         ),
//                       ],
//                     ),
//                   ),
//                 // ── Lista de modelos ─────────────────────────────────
//                 Expanded(
//                   child: ListView.separated(
//                     padding: const EdgeInsets.all(16),
//                     itemCount: AiModelCatalog.entries.length,
//                     separatorBuilder: (_, __) => const SizedBox(height: 10),
//                     itemBuilder: (context, index) {
//                       final entry = AiModelCatalog.entries[index];
//                       final isDownloaded = _downloadedIds.contains(entry.id);
//                       final isActive = _activeModelId == entry.id;
//                       return Card(
//                         elevation: isActive ? 3 : 1,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(14),
//                           side: isActive
//                               ? BorderSide(
//                                   color: Theme.of(context).colorScheme.primary,
//                                   width: 1.5,
//                                 )
//                               : BorderSide.none,
//                         ),
//                         child: ListTile(
//                           onTap: _downloadingId != null
//                               ? null
//                               : () => _showModelDetails(entry),
//                           title: Text(entry.displayName),
//                           subtitle: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const SizedBox(height: 4),
//                               _StarRating(rating: entry.qualityRating, size: 14),
//                               const SizedBox(height: 4),
//                               Text(_formatBytes(entry.approxSizeBytes)),
//                             ],
//                           ),
//                           trailing: isActive
//                               ? const Chip(label: Text('Activo'))
//                               : isDownloaded
//                                   ? const Icon(Icons.download_done)
//                                   : const Icon(Icons.cloud_download_outlined),
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//               ],
//             ),
//     );
//   }
// }

// /// Campo para guardar/leer el token global de HuggingFace.
// /// Un solo token sirve para descargar todos los modelos con licencia,
// /// siempre que el usuario haya aceptado los términos de cada uno en HF.
// class _HfTokenField extends StatefulWidget {
//   // modelId se mantiene en la firma para compatibilidad con el call-site,
//   // pero el token se guarda globalmente (no por modelo).
//   // ignore: unused_field
//   final String modelId;

//   const _HfTokenField({required this.modelId});

//   @override
//   State<_HfTokenField> createState() => _HfTokenFieldState();
// }

// class _HfTokenFieldState extends State<_HfTokenField> {
//   final TextEditingController _ctrl = TextEditingController();
//   bool _obscure = true;
//   bool _saved = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadToken();
//   }

//   Future<void> _loadToken() async {
//     final token = await AiModelRepository.hfToken();
//     if (!mounted) return;
//     if (token != null && token.isNotEmpty) {
//       _ctrl.text = token;
//       setState(() => _saved = true);
//     }
//   }

//   Future<void> _saveToken() async {
//     final token = _ctrl.text.trim();
//     await AiModelRepository.saveHfToken(token);
//     if (!mounted) return;
//     setState(() => _saved = token.isNotEmpty);
//     FocusScope.of(context).unfocus();
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(token.isEmpty ? 'Token eliminado' : 'Token de HuggingFace guardado'),
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             const Icon(Icons.key, size: 16, color: Colors.orange),
//             const SizedBox(width: 6),
//             const Text(
//               'Token de HuggingFace (global)',
//               style: TextStyle(fontWeight: FontWeight.w600),
//             ),
//             if (_saved) ...[
//               const SizedBox(width: 8),
//               const Icon(Icons.check_circle, size: 14, color: Colors.green),
//               const SizedBox(width: 4),
//               const Text(
//                 'guardado',
//                 style: TextStyle(fontSize: 11, color: Colors.green),
//               ),
//             ],
//           ],
//         ),
//         const SizedBox(height: 4),
//         const Text(
//           'El mismo token sirve para todos los modelos con licencia.\n'
//           '1. Acepta la licencia de este modelo en huggingface.co\n'
//           '2. Ve a Settings → Access Tokens → New token (tipo Read)\n'
//           '3. Pega el token (hf_...) aquí — se guarda encriptado.',
//           style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.5),
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             Expanded(
//               child: TextField(
//                 controller: _ctrl,
//                 obscureText: _obscure,
//                 decoration: InputDecoration(
//                   hintText: 'hf_...',
//                   isDense: true,
//                   suffixIcon: IconButton(
//                     icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
//                     onPressed: () => setState(() => _obscure = !_obscure),
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(width: 8),
//             FilledButton.tonal(
//               onPressed: _saveToken,
//               child: const Text('Guardar'),
//             ),
//           ],
//         ),
//       ],
//     );
//   }
// }

// class _StarRating extends StatelessWidget {
//   final int rating;
//   final double size;

//   const _StarRating({required this.rating, this.size = 16});

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: List.generate(5, (index) {
//         return Icon(
//           index < rating ? Icons.star : Icons.star_border,
//           size: size,
//           color: Colors.amber,
//         );
//       }),
//     );
//   }
// }

// class _UnsupportedDeviceBody extends StatelessWidget {
//   const _UnsupportedDeviceBody();

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(32),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.block, size: 64, color: Colors.grey[400]),
//             const SizedBox(height: 20),
//             const Text(
//               'Dispositivo no compatible',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 12),
//             Text(
//               'El módulo de IA local requiere una arquitectura ARM64 (64 bits).\n\n'
//               'Este dispositivo usa ARM32, que no es compatible con los modelos '
//               'de lenguaje incluidos (Gemma / MediaPipe LiteRT).\n\n'
//               'El resto de la aplicación funciona con normalidad.',
//               style: TextStyle(color: Colors.grey[600], height: 1.5),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
