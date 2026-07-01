// MÓDULO IA — NO ELIMINAR: desactivado para reducir APK. Reactivar junto con flutter_gemma.
// import 'package:connect/modules/ai/screens/ai_model_manager_screen.dart';
import 'package:connect/screens/dictionary_screen.dart';
import 'package:connect/screens/emisor/calculator_screen.dart';
import 'package:connect/screens/emisor/lector_tts_screen.dart';
import 'package:connect/screens/emisor/remote_control_screen.dart';
import 'package:connect/screens/translation_screen.dart';
// MÓDULO IA — NO ELIMINAR: reactivar cuando se reactive flutter_gemma.
// import 'package:connect/services/device_capability_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';

class HerramientasScreen extends StatefulWidget {
  const HerramientasScreen({super.key});

  @override
  State<HerramientasScreen> createState() => _HerramientasScreenState();
}

class _HerramientasScreenState extends State<HerramientasScreen> {
  // MÓDULO IA — NO ELIMINAR: reactivar cuando se reactive flutter_gemma.
  // bool? _aiSupported;

  @override
  void initState() {
    super.initState();
    // MÓDULO IA — NO ELIMINAR: reactivar junto con _aiSupported y flutter_gemma.
    // DeviceCapabilityService.instance.supportsLocalAi().then((v) {
    //   if (mounted) setState(() => _aiSupported = v);
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Herramientas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tool(
            context,
            icon: Icons.calculate,
            title: 'Calculadora',
            subtitle: 'Calcula expresiones con paréntesis y consulta el historial de ejercicios',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalculatorScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _tool(
            context,
            icon: Icons.record_voice_over,
            title: 'Lector TTS',
            subtitle: 'Pega un texto y escúchalo línea a línea en voz alta',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LectorTtsScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _tool(
            context,
            icon: Icons.menu_book,
            title: 'Diccionario',
            subtitle: 'Busca el significado de palabras en español o inglés',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DictionaryScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _tool(
            context,
            icon: Icons.translate,
            title: 'Traductor',
            subtitle: 'Traduce texto entre español e inglés',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TranslationScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _tool(
            context,
            icon: Icons.mouse,
            title: 'Control remoto',
            subtitle: 'Usa el teléfono como touchpad y teclado de otro dispositivo',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RemoteControlScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _aiModuleTile(context),
        ],
      ),
    );
  }

  // MÓDULO IA — NO ELIMINAR: desactivado para reducir APK (~190 MB de libs nativas flutter_gemma).
  // Para reactivar: descomentar el import de ai_model_manager_screen.dart al inicio del archivo,
  // reactivar flutter_gemma en pubspec.yaml y descomentar el cuerpo de este método.
  Widget _aiModuleTile(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.psychology, color: Colors.grey[400], size: 28),
        ),
        title: const Text(
          'Módulo IA',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Desactivado temporalmente (disponible en próxima versión)'),
        trailing: const Icon(Icons.block, size: 18, color: Colors.grey),
        onTap: null,
      ),
    );
    // — CÓDIGO ORIGINAL (NO ELIMINAR) —
    // if (supported == null) {
    //   return _tool(context, icon: Icons.psychology, title: 'Módulo IA',
    //       subtitle: 'Cargando información del dispositivo...', onTap: null);
    // }
    // if (!supported) { ... _showUnsupportedDialog ... }
    // return _tool(context, icon: Icons.psychology, title: 'Módulo IA',
    //     subtitle: 'Configura una ruta compartida para descargar y reutilizar el mismo modelo entre apps',
    //     onTap: () => Navigator.push(context,
    //         MaterialPageRoute(builder: (_) => const AiModelManagerScreen())));
  }

  void _showUnsupportedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dispositivo no compatible'),
        content: const Text(
          'El módulo de IA local requiere una arquitectura ARM64 (64 bits).\n\n'
          'Este dispositivo usa ARM32, que no es compatible con los modelos '
          'de lenguaje incluidos (Gemma / MediaPipe LiteRT).\n\n'
          'El resto de la aplicación funciona con normalidad.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _tool(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: customColor[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: customColor[500], size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: onTap != null
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : null,
        onTap: onTap,
      ),
    );
  }
}
