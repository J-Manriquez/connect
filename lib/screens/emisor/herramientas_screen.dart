import 'package:connect/modules/ai/screens/ai_model_manager_screen.dart';
import 'package:connect/screens/dictionary_screen.dart';
import 'package:connect/screens/emisor/lector_tts_screen.dart';
import 'package:connect/screens/translation_screen.dart';
import 'package:connect/services/device_capability_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';

class HerramientasScreen extends StatefulWidget {
  const HerramientasScreen({super.key});

  @override
  State<HerramientasScreen> createState() => _HerramientasScreenState();
}

class _HerramientasScreenState extends State<HerramientasScreen> {
  bool? _aiSupported;

  @override
  void initState() {
    super.initState();
    DeviceCapabilityService.instance.supportsLocalAi().then((v) {
      if (mounted) setState(() => _aiSupported = v);
    });
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
          _aiModuleTile(context),
        ],
      ),
    );
  }

  Widget _aiModuleTile(BuildContext context) {
    final supported = _aiSupported;

    // Mientras carga, muestra el tile normal sin badge.
    if (supported == null) {
      return _tool(
        context,
        icon: Icons.psychology,
        title: 'Módulo IA',
        subtitle: 'Cargando información del dispositivo...',
        onTap: null,
      );
    }

    if (!supported) {
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
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.psychology, color: Colors.grey[400], size: 28),
          ),
          title: const Text(
            'Módulo IA',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'No disponible — este dispositivo requiere procesador ARM64',
          ),
          trailing: const Icon(Icons.block, size: 18, color: Colors.grey),
          onTap: () => _showUnsupportedDialog(context),
        ),
      );
    }

    return _tool(
      context,
      icon: Icons.psychology,
      title: 'Módulo IA',
      subtitle:
          'Configura una ruta compartida para descargar y reutilizar el mismo modelo entre apps',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AiModelManagerScreen()),
      ),
    );
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
