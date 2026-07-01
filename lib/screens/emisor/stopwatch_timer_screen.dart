import 'dart:async';

import 'package:connect/services/stopwatch_timer_service.dart';
import 'package:connect/screens/emisor/stopwatch_widget_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StopwatchTimerScreen extends StatefulWidget {
  const StopwatchTimerScreen({super.key});

  @override
  State<StopwatchTimerScreen> createState() => _StopwatchTimerScreenState();
}

class _StopwatchTimerScreenState extends State<StopwatchTimerScreen>
    with TickerProviderStateMixin {
  StopwatchSnapshot _snap = StopwatchSnapshot.initial;
  StreamSubscription<StopwatchSnapshot>? _sub;

  // Config de audio/vibración
  bool _soundEnabled     = true;
  bool _vibrationEnabled = true;
  String _soundUri       = '';
  bool _lapVibrate       = false;
  bool _lapSound         = false;
  String _lapSoundUri    = '';

  // Wheel picker para timer
  int _timerHours   = 0;
  int _timerMinutes = 5;
  int _timerSeconds = 0;

  // Controladores de scroll de los wheels
  late final FixedExtentScrollController _hoursCtrl;
  late final FixedExtentScrollController _minutesCtrl;
  late final FixedExtentScrollController _secondsCtrl;

  @override
  void initState() {
    super.initState();
    _hoursCtrl   = FixedExtentScrollController(initialItem: _timerHours);
    _minutesCtrl = FixedExtentScrollController(initialItem: _timerMinutes);
    _secondsCtrl = FixedExtentScrollController(initialItem: _timerSeconds);

    _sub = StopwatchTimerService.stateStream.listen((s) {
      if (mounted) setState(() => _snap = s);
    });
    StopwatchTimerService.init().then((_) {
      if (mounted) setState(() => _snap = StopwatchTimerService.current);
    });
    _loadAudioConfig();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hoursCtrl.dispose();
    _minutesCtrl.dispose();
    _secondsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAudioConfig() async {
    final cfg = await StopwatchTimerService.getAudioConfig();
    if (!mounted) return;
    setState(() {
      _soundEnabled     = cfg['soundEnabled'] as bool;
      _vibrationEnabled = cfg['vibrationEnabled'] as bool;
      _soundUri         = cfg['soundUri'] as String;
      _lapVibrate       = cfg['lapVibrate'] as bool;
      _lapSound         = cfg['lapSound'] as bool;
      _lapSoundUri      = cfg['lapSoundUri'] as String;
    });
    // Sincronizar wheels con el target guardado
    final tMs = _snap.timerTarget.inMilliseconds;
    final h   = tMs ~/ 3600000;
    final m   = (tMs % 3600000) ~/ 60000;
    final s   = (tMs % 60000)   ~/ 1000;
    setState(() { _timerHours = h; _timerMinutes = m; _timerSeconds = s; });
    _hoursCtrl.jumpToItem(h);
    _minutesCtrl.jumpToItem(m);
    _secondsCtrl.jumpToItem(s);
  }

  // ── Acciones ────────────────────────────────────────────────────────────────────────

  Future<void> _onStartPause() async {
    HapticFeedback.lightImpact();
    if (_snap.state == StopwatchStateEnum.running) {
      await StopwatchTimerService.pause();
    } else {
      if (_snap.mode == StopwatchMode.timer &&
          _snap.state == StopwatchStateEnum.idle) {
        final ms = (_timerHours * 3600 + _timerMinutes * 60 + _timerSeconds) * 1000;
        if (ms > 0) await StopwatchTimerService.setTimer(Duration(milliseconds: ms));
      }
      await StopwatchTimerService.start();
    }
  }

  Future<void> _onReset() async {
    HapticFeedback.mediumImpact();
    await StopwatchTimerService.reset();
  }

  Future<void> _onLap() async {
    HapticFeedback.selectionClick();
    await StopwatchTimerService.lap();
  }

  Future<void> _onToggleMode(StopwatchMode mode) async {
    await StopwatchTimerService.setMode(mode);
  }

  Future<void> _pickSound({bool isLap = false}) async {
    final result = await Navigator.pushNamed(context, '/custom_sound_selection');
    if (result is String && result.isNotEmpty) {
      if (isLap) {
        await StopwatchTimerService.setLapSoundUri(result);
        setState(() => _lapSoundUri = result);
      } else {
        await StopwatchTimerService.setSoundUri(result);
        setState(() => _soundUri = result);
      }
    }
  }

  Future<void> _pickVibrationPattern() async {
    await Navigator.pushNamed(context, '/vibration_patterns');
  }

  // ── Build ────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isRunning  = _snap.state == StopwatchStateEnum.running;
    final isIdle     = _snap.state == StopwatchStateEnum.idle;
    final isTimer    = _snap.mode  == StopwatchMode.timer;
    final isFinished = _snap.state == StopwatchStateEnum.finished;

    final displayTime = formatStopwatchTime(
      isTimer ? _snap.remaining : _snap.elapsed,
      showMs: true,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cronómetro / Temporizador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.widgets_outlined),
            tooltip: 'Configurar widgets',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const StopwatchWidgetListScreen(),
            )),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Selector de modo ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _ModeToggle(
                mode: _snap.mode,
                onChanged: isRunning ? null : _onToggleMode,
              ),
            ),

            // ── Display principal ─────────────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tiempo
                    Text(
                      displayTime,
                      style: TextStyle(
                        color: isFinished ? Colors.orange : null,
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (_snap.mode == StopwatchMode.stopwatch && _snap.laps.isNotEmpty)
                      Text(
                        'Vuelta actual: ${formatStopwatchTime(_snap.currentLapElapsed, showMs: true)}',
                        style: const TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                    if (isFinished)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('¡Tiempo!', style: TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ),

            // ── Wheel picker del temporizador (solo cuando idle y modo timer) ──────────
            if (isTimer && (isIdle || isFinished))
              SizedBox(
                height: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _WheelPicker(
                      max: 23, label: 'h',
                      controller: _hoursCtrl,
                      onChanged: (v) => setState(() => _timerHours = v),
                    ),
                    _WheelSeparator(),
                    _WheelPicker(
                      max: 59, label: 'm',
                      controller: _minutesCtrl,
                      onChanged: (v) => setState(() => _timerMinutes = v),
                    ),
                    _WheelSeparator(),
                    _WheelPicker(
                      max: 59, label: 's',
                      controller: _secondsCtrl,
                      onChanged: (v) => setState(() => _timerSeconds = v),
                    ),
                  ],
                ),
              ),

            // ── Barra de progreso timer ───────────────────────────────────────────────
            if (isTimer && !isIdle && !isFinished)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _snap.timerTarget.inMilliseconds > 0
                          ? (_snap.remaining.inMilliseconds / _snap.timerTarget.inMilliseconds).clamp(0.0, 1.0)
                          : 0,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4488FF)),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: ${formatStopwatchTime(_snap.timerTarget, showMs: false)}',
                      style: const TextStyle(color: Colors.black38, fontSize: 11),
                    ),
                  ],
                ),
              ),

            // ── Botones principales ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Botón LAP (solo cronómetro running)
                  _ControlButton(
                    icon: Icons.flag_outlined,
                    label: 'Vuelta',
                    size: 52,
                    enabled: isRunning && !isTimer,
                    onTap: _onLap,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 24),
                  // Botón PLAY/PAUSE principal
                  _ControlButton(
                    icon: isRunning ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    label: isRunning ? 'Pausar' : (isIdle ? 'Iniciar' : 'Reanudar'),
                    size: 72,
                    enabled: !isFinished || isTimer,
                    onTap: _onStartPause,
                    color: isRunning ? const Color(0xFF4488FF) : const Color(0xFF44BB88),
                  ),
                  const SizedBox(width: 24),
                  // Botón RESET
                  _ControlButton(
                    icon: Icons.replay,
                    label: 'Reiniciar',
                    size: 52,
                    enabled: !isIdle,
                    onTap: _onReset,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),

            // ── Configuración de audio/vibración ──────────────────────────────────────
            const Divider(),
            _AudioVibSection(
              soundEnabled:     _soundEnabled,
              vibrationEnabled: _vibrationEnabled,
              soundUri:         _soundUri,
              lapVibrate:       _lapVibrate,
              lapSound:         _lapSound,
              lapSoundUri:      _lapSoundUri,
              onSoundToggle: (v) async {
                setState(() => _soundEnabled = v);
                await StopwatchTimerService.setSoundEnabled(v);
              },
              onVibrationToggle: (v) async {
                setState(() => _vibrationEnabled = v);
                await StopwatchTimerService.setVibrationEnabled(v);
              },
              onPickSound:         () => _pickSound(),
              onPickVibration:     _pickVibrationPattern,
              onLapVibrateToggle: (v) async {
                setState(() => _lapVibrate = v);
                await StopwatchTimerService.setLapVibrate(v);
              },
              onLapSoundToggle: (v) async {
                setState(() => _lapSound = v);
                await StopwatchTimerService.setLapSound(v);
              },
              onPickLapSound: () => _pickSound(isLap: true),
            ),

            // ── Lista de vueltas ──────────────────────────────────────────────────────
            if (_snap.laps.isNotEmpty) ...[
              const Divider(),
              _LapList(laps: _snap.laps),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final StopwatchMode mode;
  final void Function(StopwatchMode)? onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _Tab('Cronómetro', mode == StopwatchMode.stopwatch, () => onChanged?.call(StopwatchMode.stopwatch)),
          _Tab('Temporizador', mode == StopwatchMode.timer,    () => onChanged?.call(StopwatchMode.timer)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF4488FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : Colors.black54,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final double size;
  final bool enabled;
  final VoidCallback onTap;
  final Color color;
  const _ControlButton({
    required this.icon, required this.label, required this.size,
    required this.enabled, required this.onTap, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.25,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: size, color: color),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _WheelPicker extends StatelessWidget {
  final int max;
  final String label;
  final FixedExtentScrollController controller;
  final void Function(int) onChanged;
  const _WheelPicker({required this.max, required this.label, required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: ListWheelScrollView.useDelegate(
              controller: controller,
              itemExtent: 40,
              perspective: 0.003,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: onChanged,
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (ctx, i) => Center(
                  child: Text(
                    i.toString().padLeft(2, '0'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ),
                childCount: max + 1,
              ),
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }
}

class _WheelSeparator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Text(':', style: TextStyle(color: Colors.black54, fontSize: 28, fontWeight: FontWeight.bold)),
    );
  }
}

class _AudioVibSection extends StatelessWidget {
  final bool soundEnabled;
  final bool vibrationEnabled;
  final String soundUri;
  final bool lapVibrate;
  final bool lapSound;
  final String lapSoundUri;
  final void Function(bool) onSoundToggle;
  final void Function(bool) onVibrationToggle;
  final VoidCallback onPickSound;
  final VoidCallback onPickVibration;
  final void Function(bool) onLapVibrateToggle;
  final void Function(bool) onLapSoundToggle;
  final VoidCallback onPickLapSound;

  const _AudioVibSection({
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.soundUri,
    required this.lapVibrate,
    required this.lapSound,
    required this.lapSoundUri,
    required this.onSoundToggle,
    required this.onVibrationToggle,
    required this.onPickSound,
    required this.onPickVibration,
    required this.onLapVibrateToggle,
    required this.onLapSoundToggle,
    required this.onPickLapSound,
  });

  @override
  Widget build(BuildContext context) {
    final soundName = soundUri.isEmpty ? 'Sonido del sistema' : soundUri.split('/').last;
    final lapSoundName = lapSoundUri.isEmpty ? 'Sonido del sistema' : lapSoundUri.split('/').last;

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      title: const Row(
        children: [
          Icon(Icons.notifications_active_outlined, size: 18),
          SizedBox(width: 8),
          Text('Sonido y Vibración', style: TextStyle(fontSize: 14)),
        ],
      ),
      children: [
        // Al terminar
        const Text('Al terminar', style: TextStyle(color: Colors.black38, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.volume_up_outlined, size: 16),
            const SizedBox(width: 6),
            const Text('Sonido'),
            const Spacer(),
            Switch(value: soundEnabled, onChanged: onSoundToggle, activeThumbColor: const Color(0xFF4488FF)),
          ],
        ),
        if (soundEnabled)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(soundName, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: onPickSound,
          ),
        Row(
          children: [
            const Icon(Icons.vibration, size: 16),
            const SizedBox(width: 6),
            const Text('Vibración'),
            const Spacer(),
            Switch(value: vibrationEnabled, onChanged: onVibrationToggle, activeThumbColor: const Color(0xFF4488FF)),
          ],
        ),
        if (vibrationEnabled)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Patrón de vibración', style: TextStyle(color: Colors.black54, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: onPickVibration,
          ),
        const Divider(),
        // En cada vuelta
        const Text('En cada vuelta', style: TextStyle(color: Colors.black38, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.vibration, size: 16),
            const SizedBox(width: 6),
            const Text('Vibrar'),
            const Spacer(),
            Switch(value: lapVibrate, onChanged: onLapVibrateToggle, activeThumbColor: const Color(0xFF4488FF)),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.volume_up_outlined, size: 16),
            const SizedBox(width: 6),
            const Text('Sonido'),
            const Spacer(),
            Switch(value: lapSound, onChanged: onLapSoundToggle, activeThumbColor: const Color(0xFF4488FF)),
          ],
        ),
        if (lapSound)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(lapSoundName, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: onPickLapSound,
          ),
      ],
    );
  }
}

class _LapList extends StatelessWidget {
  final List<LapEntry> laps;
  const _LapList({required this.laps});

  @override
  Widget build(BuildContext context) {
    final reversed = laps.reversed.toList();
    return SizedBox(
      height: 140,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: reversed.length,
        itemBuilder: (ctx, i) {
          final lap   = reversed[i];
          final isNew = i == 0;
          final dMs   = lap.delta.inMilliseconds;
          final sign  = dMs >= 0 ? '+' : '-';
          final deltaStr = formatStopwatchTime(Duration(milliseconds: dMs.abs()), showMs: true);
          return Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  'V${lap.number}',
                  style: TextStyle(
                    color: isNew ? const Color(0xFF4488FF) : Colors.black54,
                    fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  formatStopwatchTime(lap.totalElapsed, showMs: true),
                  style: TextStyle(
                    color: isNew ? Colors.black : Colors.black87,
                    fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (i < laps.length - 1)
                Text(
                  '$sign$deltaStr',
                  style: TextStyle(
                    color: dMs <= 0 ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 11,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
