import 'package:flutter/material.dart';

import '../models/ai_model_catalog.dart';
import '../models/ai_model_config.dart';
import '../services/ai_service.dart';

/// Pantalla de configuración avanzada para un modelo descargado.
/// Permite cambiar template de chat, system instruction, temperatura,
/// max tokens y topK.
class AiModelConfigScreen extends StatefulWidget {
  final AiModelCatalogEntry entry;

  const AiModelConfigScreen({super.key, required this.entry});

  @override
  State<AiModelConfigScreen> createState() => _AiModelConfigScreenState();
}

class _AiModelConfigScreenState extends State<AiModelConfigScreen> {
  late AiModelConfig _cfg;
  bool _loading = true;
  bool _dirty = false;

  final TextEditingController _systemCtrl = TextEditingController();
  final TextEditingController _customTemplateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await AiService.instance.modelConfig(widget.entry.id);
    if (!mounted) return;
    setState(() {
      _cfg = cfg;
      _systemCtrl.text = cfg.systemInstruction;
      _customTemplateCtrl.text = cfg.customTemplate;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final updated = _cfg.copyWith(
      systemInstruction: _systemCtrl.text.trim(),
      customTemplate: _customTemplateCtrl.text,
    );
    await AiService.instance.saveModelConfig(updated);
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración guardada')),
    );
  }

  Future<void> _reset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar defaults'),
        content: const Text(
          '¿Restaurar toda la configuración de este modelo a los valores por defecto?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final fresh = AiModelConfig(modelId: widget.entry.id);
    await AiService.instance.saveModelConfig(fresh);
    if (!mounted) return;
    setState(() {
      _cfg = fresh;
      _systemCtrl.text = fresh.systemInstruction;
      _customTemplateCtrl.text = fresh.customTemplate;
      _dirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración restaurada')),
    );
  }

  void _mark() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _systemCtrl.dispose();
    _customTemplateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Config — ${widget.entry.displayName}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Config — ${widget.entry.displayName}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Restaurar defaults',
            icon: const Icon(Icons.restart_alt),
            onPressed: _reset,
          ),
          FilledButton.tonal(
            onPressed: _dirty ? _save : null,
            child: const Text('Guardar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Template de chat ───────────────────────────────────────────
          _SectionHeader(
            'Template de chat',
            subtitle: 'Controla cómo se formatea el prompt antes de enviarlo al modelo.',
          ),
          RadioGroup<AiChatTemplate>(
            groupValue: _cfg.template,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _cfg = _cfg.copyWith(template: v));
              _mark();
            },
            child: Column(
              children: AiChatTemplate.values
                  .map(
                    (t) => RadioListTile<AiChatTemplate>(
                      value: t,
                      title: Text(t.label),
                      subtitle: Text(
                        t.description,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_cfg.template == AiChatTemplate.custom) ...[
            const SizedBox(height: 8),
            Text(
              'Define tu template usando {system}, {user} y {assistant} como '
              'marcadores de posición.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _customTemplateCtrl,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText:
                    '<|im_start|>system\n{system}<|im_end|>\n'
                    '<|im_start|>user\n{user}<|im_end|>\n'
                    '<|im_start|>assistant\n{assistant}',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _mark(),
            ),
          ],
          const Divider(height: 32),

          // ── System instruction ─────────────────────────────────────────
          _SectionHeader(
            'Instrucción de sistema',
            subtitle:
                'Rol o contexto que recibe el modelo antes de cada mensaje. '
                'Dejar vacío para usar el default de la pantalla de chat.',
          ),
          TextField(
            controller: _systemCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText:
                  'Eres un asistente breve, claro y útil. Responde en español.',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _mark(),
          ),
          const Divider(height: 32),

          // ── Temperatura ────────────────────────────────────────────────
          _SectionHeader(
            'Temperatura: ${_cfg.temperature.toStringAsFixed(2)}',
            subtitle:
                '0.0 = determinista (siempre la misma respuesta). '
                '1.0 = muy creativo/aleatorio.',
          ),
          Slider(
            value: _cfg.temperature,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: _cfg.temperature.toStringAsFixed(2),
            onChanged: (v) {
              setState(() => _cfg = _cfg.copyWith(temperature: v));
              _mark();
            },
          ),
          const Divider(height: 32),

          // ── Max output tokens ──────────────────────────────────────────
          _SectionHeader(
            'Máx. tokens de salida: ${_cfg.maxOutputTokens}',
            subtitle:
                'Límite de tokens que el modelo puede generar. '
                'Valores más altos permiten respuestas más largas pero consumen más RAM.',
          ),
          Slider(
            value: _cfg.maxOutputTokens.toDouble(),
            min: 64,
            max: 2048,
            divisions: 31,
            label: '${_cfg.maxOutputTokens}',
            onChanged: (v) {
              setState(() => _cfg = _cfg.copyWith(maxOutputTokens: v.round()));
              _mark();
            },
          ),
          const Divider(height: 32),

          // ── Top-K ──────────────────────────────────────────────────────
          _SectionHeader(
            'Top-K: ${_cfg.topK}',
            subtitle:
                'Número de tokens candidatos a considerar en cada paso. '
                '1 = greedy (más predecible). 100 = más variado.',
          ),
          Slider(
            value: _cfg.topK.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            label: '${_cfg.topK}',
            onChanged: (v) {
              setState(() => _cfg = _cfg.copyWith(topK: v.round()));
              _mark();
            },
          ),
          const SizedBox(height: 32),

          // ── Resumen de config actual ───────────────────────────────────
          Card(
            color: Colors.blueGrey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configuración activa',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _cfgRow('Template', _cfg.template.label),
                  _cfgRow('Temperatura', _cfg.temperature.toStringAsFixed(2)),
                  _cfgRow('Max tokens', '${_cfg.maxOutputTokens}'),
                  _cfgRow('Top-K', '${_cfg.topK}'),
                  _cfgRow(
                    'System',
                    _systemCtrl.text.isNotEmpty
                        ? '"${_systemCtrl.text.length > 40 ? _systemCtrl.text.substring(0, 40) : _systemCtrl.text}..."'
                        : '(default de la pantalla de chat)',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _cfgRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }
}
