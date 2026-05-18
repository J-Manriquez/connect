import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:connect/services/ble_service.dart';
import 'package:connect/services/floating_ball_service.dart';
import 'package:connect/services/preferences_service.dart';
import 'package:connect/theme_colors.dart';
import 'package:flutter/material.dart';

class FsMediaSection extends StatefulWidget {
  final bool visible;
  final ValueChanged<bool> onVisibleChanged;

  const FsMediaSection({
    super.key,
    required this.visible,
    required this.onVisibleChanged,
  });

  @override
  State<FsMediaSection> createState() => _FsMediaSectionState();
}

class _FsMediaSectionState extends State<FsMediaSection> {
  Timer? _tick;
  Timer? _volumeDebounce;
  Map<String, dynamic>? _mediaState;
  Map<String, dynamic>? _volumeState;
  bool _showVolume = false;
  bool _isAdjustingVolume = false;
  double? _volumeFraction;

  bool _isSeeking = false;
  double? _seekFraction;

  int _basePositionMs = 0;
  int _baseDurationMs = 0;
  int _baseAtMs = 0;
  bool _baseIsPlaying = false;
  String _baseTitleSig = '';

  double _dragDx = 0;
  bool _dragging = false;

  int _mediaHeightDp = 320;
  int _mediaIconSizeDp = 34;
  int _mediaTitleSizeSp = 18;
  int _mediaSubtitleSizeSp = 14;
  int _textColorArgb = 0xFFFFFFFF;

  @override
  void initState() {
    super.initState();
    _loadStyle();
    _sync();
    _configureTick();
  }

  @override
  void didUpdateWidget(covariant FsMediaSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      print('[fs_media] visible changed ${oldWidget.visible} -> ${widget.visible}');
      _configureTick();
      if (widget.visible) {
        _sync();
      }
    }
  }

  void _configureTick() {
    _tick?.cancel();
    _tick = null;
    if (!widget.visible) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _sync();
    });
  }

  Future<void> _loadStyle() async {
    try {
      final mediaHeightDp = await FloatingBallService.getMediaHeightDp();
      final mediaIconSizeDp = await FloatingBallService.getMediaIconSizeDp();
      final mediaTitleSizeSp = await FloatingBallService.getMediaTitleSizeSp();
      final mediaSubtitleSizeSp = await FloatingBallService.getMediaSubtitleSizeSp();
      final textColor = await FloatingBallService.getFullScreenTextColor();
      if (!mounted) return;
      setState(() {
        _mediaHeightDp = mediaHeightDp;
        _mediaIconSizeDp = mediaIconSizeDp;
        _mediaTitleSizeSp = mediaTitleSizeSp;
        _mediaSubtitleSizeSp = mediaSubtitleSizeSp;
        _textColorArgb = textColor;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _tick?.cancel();
    _tick = null;
    _volumeDebounce?.cancel();
    _volumeDebounce = null;
    super.dispose();
  }

  Map<String, dynamic>? _parseState(dynamic json) {
    if (json == null) return null;
    try {
      if (json is Map) return Map<String, dynamic>.from(json);
      if (json is String) {
        final decoded = jsonDecode(json);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  bool _toBool(dynamic v) {
    if (v is bool) return v;
    final s = (v ?? '').toString().toLowerCase().trim();
    return s == '1' || s == 'true' || s == 'yes';
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  Future<void> _sync() async {
    try {
      final prioritizeLocal = await PreferencesService.getPrioritizeLocalMedia();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      int connectedCount = 0;
      try {
        final st = await BleService.getBtServerStatus();
        connectedCount = (st['connectedCount'] as num?)?.toInt() ?? 0;
      } catch (_) {}

      final bt = await BleService.getLastBtMediaState();
      final local = await BleService.getLastLocalMediaState();

      final remoteUpdatedAt = _toInt(bt?['updatedAtMs']);
      final localUpdatedAt = _toInt(local?['updatedAtMs']);
      final remoteFresh = connectedCount > 0 &&
          remoteUpdatedAt > 0 &&
          nowMs - remoteUpdatedAt <= 15000;
      final localFresh = localUpdatedAt > 0 && nowMs - localUpdatedAt <= 15000;

      final bool useLocal = prioritizeLocal
          ? (localFresh || !remoteFresh)
          : (!remoteFresh && localFresh);
      if (prioritizeLocal && !localFresh) {
        try {
          await BleService.refreshLocalMediaState();
        } catch (_) {}
      }

      final next = useLocal ? _parseState(local?['json']) : _parseState(bt?['json']);
      if (!mounted) return;
      if (next == null) {
        if (_mediaState != null) {
          setState(() {
            _mediaState = null;
            _volumeState = null;
          });
        }
        return;
      }

      final sig = [
        (next['title'] ?? '').toString(),
        (next['appName'] ?? '').toString(),
        (next['positionMs'] ?? '').toString(),
        (next['isPlaying'] ?? '').toString(),
      ].join('|');

      final prevSig = _mediaState == null
          ? ''
          : [
              (_mediaState!['title'] ?? '').toString(),
              (_mediaState!['appName'] ?? '').toString(),
              (_mediaState!['positionMs'] ?? '').toString(),
              (_mediaState!['isPlaying'] ?? '').toString(),
              (_mediaState!['_source'] ?? '').toString(),
            ].join('|');

      if (sig != prevSig) {
        print('[fs_media] sync source=${useLocal ? "local" : "emisor"} title="${(next["title"] ?? "").toString()}"');
      }

      setState(() {
        _mediaState = {
          ...next,
        };
      });

      final title = (next['title'] ?? '').toString().trim();
      final appName = (next['appName'] ?? '').toString().trim();
      final artist = (next['artist'] ?? '').toString().trim();
      final titleSig = '$title|$artist|$appName';
      final isPlaying = _toBool(next['isPlaying']);
      final durationMs = _toInt(next['durationMs']);
      final positionMs = _toInt(next['positionMs']);
      bool shouldResetBase =
          titleSig != _baseTitleSig || isPlaying != _baseIsPlaying;
      if (!shouldResetBase && isPlaying && _baseAtMs > 0) {
        final expected = _basePositionMs + (nowMs - _baseAtMs);
        final delta = (positionMs - expected).abs();
        if (delta > 1500) {
          shouldResetBase = true;
          print('[fs_media] base resync deltaMs=$delta pos=$positionMs expected=$expected');
        }
      }
      if (shouldResetBase) {
        _baseTitleSig = titleSig;
        _baseIsPlaying = isPlaying;
        _baseDurationMs = durationMs;
        _basePositionMs = positionMs.clamp(0, durationMs > 0 ? durationMs : 1 << 30);
        _baseAtMs = nowMs;
        print('[fs_media] base reset titleSig="$titleSig" isPlaying=$isPlaying pos=$_basePositionMs dur=$_baseDurationMs');
      } else {
        _baseDurationMs = durationMs;
      }
    } catch (e) {
      print('[fs_media] sync error=$e');
    }
  }

  Uint8List? _decodeArtBytes(String? base64) {
    final s = base64?.replaceAll(RegExp(r'\s+'), '').trim();
    if (s == null || s.isEmpty) return null;
    try {
      return const Base64Decoder().convert(s);
    } catch (_) {
      return null;
    }
  }

  String _formatMs(int ms) {
    final s = (ms / 1000).floor();
    final mm = (s / 60).floor();
    final ss = (s % 60);
    return '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }

  Future<void> _ensureBtServerRunning() async {
    try {
      final status = await BleService.getBtServerStatus();
      if (status['running'] == true) return;
      print('[fs_media] bt_server start requested (was not running)');
      await BleService.startBtServer();
      await Future.delayed(const Duration(milliseconds: 250));
    } catch (e) {
      print('[fs_media] ensureBtServerRunning error=$e');
    }
  }

  Future<void> _sendViaBtServerOrFallback(Map<String, dynamic> payload) async {
    try {
      await _ensureBtServerRunning();
      try {
        final status = await BleService.getBtServerStatus();
        final running = status['running'] == true;
        final connectedCount = (status['connectedCount'] as num?)?.toInt() ?? 0;
        print('[fs_media] bt_server status running=$running peers=$connectedCount type=${payload["type"]}');
        if (running && connectedCount > 0) {
          await BleService.sendBtServerMessage(payload);
          print('[fs_media] sent via bt_server');
          return;
        }
      } catch (_) {}

      await BleService.sendNotification(payload);
      print('[fs_media] sent via ble_notification fallback');
    } catch (e) {
      print('[fs_media] send error=$e');
    }
  }

  Future<void> _sendMediaCommand(String command, {int? positionMs}) async {
    final enabled = await PreferencesService.getBleEnabled();
    print('[fs_media][cmd] command=$command positionMs=$positionMs enabled=$enabled');
    if (!enabled) return;
    await _sendViaBtServerOrFallback(<String, dynamic>{
      'type': 'media_command',
      'command': command,
      if (positionMs != null) 'positionMs': positionMs,
      'time': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _sendVolumeRequest() async {
    final enabled = await PreferencesService.getBleEnabled();
    print('[fs_media][vol_req] enabled=$enabled');
    if (!enabled) return;
    await _sendViaBtServerOrFallback(<String, dynamic>{
      'type': 'volume_request',
      'time': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _sendVolumeCommandPct(int pct) async {
    final enabled = await PreferencesService.getBleEnabled();
    print('[fs_media][vol_cmd] pct=$pct enabled=$enabled');
    if (!enabled) return;
    await _sendViaBtServerOrFallback(<String, dynamic>{
      'type': 'volume_command',
      'pct': pct.clamp(0, 100),
      'time': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _debounceVolumeSend(int pct) {
    _volumeDebounce?.cancel();
    _volumeDebounce = Timer(const Duration(milliseconds: 140), () async {
      print('[fs_media][vol_debounce] pct=$pct');
      await _sendVolumeCommandPct(pct);
    });
  }

  Future<void> _sendLaunchDefaultMediaAppPlay() async {
    final enabled = await PreferencesService.getBleEnabled();
    print('[fs_media][media_launch] enabled=$enabled');
    if (!enabled) return;
    await _sendViaBtServerOrFallback(<String, dynamic>{
      'type': 'launch_default_media_app',
      'packageName': '',
      'forcePlay': true,
      'pauseOthers': true,
      'time': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _hide() {
    if (!widget.visible) return;
    print('[fs_media] hide requested');
    widget.onVisibleChanged(false);
  }

  void _toggle() {
    final next = !widget.visible;
    print('[fs_media] toggle requested -> $next');
    widget.onVisibleChanged(next);
  }

  int _effectivePositionMs({
    required String title,
    required int positionMs,
    required int durationMs,
    required bool isPlaying,
    required int nowMs,
  }) {
    if (title.isEmpty || durationMs <= 0) return positionMs.clamp(0, durationMs);
    if (!_baseIsPlaying || !isPlaying) return positionMs.clamp(0, durationMs);
    final elapsed = nowMs - _baseAtMs;
    if (elapsed <= 0) return positionMs.clamp(0, durationMs);
    final next = _basePositionMs + elapsed;
    return next.clamp(0, durationMs).toInt();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final state = _mediaState;
    final hasMedia = state != null && (state['title'] ?? '').toString().trim().isNotEmpty;
    final title = (hasMedia ? (state!['title'] ?? '').toString() : '').trim();
    final appName = (hasMedia ? (state!['appName'] ?? '').toString() : '').trim();
    final artist = (hasMedia ? (state!['artist'] ?? '').toString() : '').trim();
    final isPlaying = hasMedia ? _toBool(state!['isPlaying']) : false;
    final canPlayPause = hasMedia ? _toBool(state!['canPlayPause']) : true;
    final canSkipNext = hasMedia ? _toBool(state!['canSkipNext']) : false;
    final canSkipPrev = hasMedia ? _toBool(state!['canSkipPrev']) : false;
    final canSeek = hasMedia ? _toBool(state!['canSeek']) : true;
    final posMs = hasMedia ? _toInt(state!['positionMs']) : 0;
    final durMs = hasMedia ? _toInt(state!['durationMs']) : 0;
    final art = hasMedia ? _decodeArtBytes((state!['artBase64'] ?? '').toString()) : null;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final int effectivePositionMs = hasMedia
        ? _effectivePositionMs(
            title: title,
            positionMs: posMs,
            durationMs: durMs,
            isPlaying: isPlaying,
            nowMs: nowMs,
          )
        : 0;
    final int displayPositionMs =
        (_isSeeking && _seekFraction != null && durMs > 0)
            ? (durMs * _seekFraction!).round().clamp(0, durMs).toInt()
            : effectivePositionMs;
    final double progress = (durMs > 0)
        ? (displayPositionMs / durMs).clamp(0.0, 1.0)
        : 0.0;
    final double sliderValue = (_seekFraction ?? progress).clamp(0.0, 1.0);

    final int baseVolPct = (() {
      final v = _volumeState;
      final pct = _toInt(v?['pct']);
      if (pct > 0) return pct.clamp(0, 100);
      final mpct = hasMedia ? _toInt(state?['volumePct']) : 0;
      return mpct.clamp(0, 100);
    })();

    final textColor = Color(_textColorArgb);
    return GestureDetector(
      onTap: _hide,
      onVerticalDragEnd: (_) => _hide(),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          image: art == null
              ? null
              : DecorationImage(
                  image: MemoryImage(art),
                  fit: BoxFit.cover,
                ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onHorizontalDragStart: (_) {
                              _dragging = true;
                              _dragDx = 0;
                            },
                            onHorizontalDragUpdate: (d) {
                              if (!_dragging) return;
                              _dragDx += d.delta.dx;
                            },
                            onHorizontalDragEnd: (_) async {
                              final dx = _dragDx;
                              _dragging = false;
                              _dragDx = 0;
                              if (dx > 70) {
                                _hide();
                                return;
                              }
                              if (dx < -70) {
                                await _sendLaunchDefaultMediaAppPlay();
                                return;
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasMedia ? title : 'Sin reproducción',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: _mediaTitleSizeSp.toDouble(),
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasMedia
                                      ? (() {
                                          if (artist.isNotEmpty && appName.isNotEmpty) {
                                            return '$artist • $appName';
                                          }
                                          if (artist.isNotEmpty) return artist;
                                          if (appName.isNotEmpty) return appName;
                                          return '';
                                        })()
                                      : 'No hay estado multimedia disponible',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.7),
                                    fontSize: _mediaSubtitleSizeSp.toDouble(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _hide,
                          icon: Icon(Icons.close, color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (durMs > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(trackHeight: 4),
                            child: Slider(
                              value: sliderValue,
                              onChangeStart: hasMedia && canSeek
                                  ? (_) {
                                      setState(() {
                                        _isSeeking = true;
                                      });
                                    }
                                  : null,
                              onChanged: hasMedia && canSeek
                                  ? (v) {
                                      setState(() {
                                        _seekFraction = v;
                                      });
                                    }
                                  : null,
                              onChangeEnd: hasMedia && canSeek
                                  ? (v) async {
                                      final target = (durMs * v).round().clamp(0, durMs).toInt();
                                      await _sendMediaCommand('seekTo', positionMs: target);
                                      if (!mounted) return;
                                      setState(() {
                                        _isSeeking = false;
                                        _seekFraction = null;
                                      });
                                    }
                                  : null,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatMs(displayPositionMs),
                                  style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7)),
                                ),
                                Text(
                                  _formatMs(durMs),
                                  style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      LinearProgressIndicator(
                        value: hasMedia ? null : 0,
                        minHeight: 4,
                        color: textColor.withValues(alpha: 0.54),
                        backgroundColor: textColor.withValues(alpha: 0.24),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(Icons.skip_previous, color: textColor),
                          onPressed: hasMedia && canSkipPrev ? () => _sendMediaCommand('previous') : null,
                          iconSize: _mediaIconSizeDp.toDouble(),
                        ),
                        IconButton(
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: textColor),
                          onPressed: hasMedia && canPlayPause ? () => _sendMediaCommand('toggle') : null,
                          iconSize: (_mediaIconSizeDp + 8).toDouble(),
                        ),
                        IconButton(
                          icon: Icon(Icons.skip_next, color: textColor),
                          onPressed: hasMedia && canSkipNext ? () => _sendMediaCommand('next') : null,
                          iconSize: _mediaIconSizeDp.toDouble(),
                        ),
                        IconButton(
                          icon: Icon(_showVolume ? Icons.volume_up : Icons.volume_down, color: textColor),
                          onPressed: () async {
                            final next = !_showVolume;
                            setState(() {
                              _showVolume = next;
                              _isAdjustingVolume = false;
                              _volumeFraction = null;
                            });
                            if (next) {
                              await _sendVolumeRequest();
                            }
                          },
                          iconSize: _mediaIconSizeDp.toDouble(),
                        ),
                      ],
                    ),
                    if (_showVolume) ...[
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(trackHeight: 8),
                        child: Slider(
                          value: (_isAdjustingVolume && _volumeFraction != null)
                              ? _volumeFraction!.clamp(0.0, 1.0)
                              : (baseVolPct / 100.0).clamp(0.0, 1.0),
                          onChangeStart: (_) {
                            setState(() {
                              _isAdjustingVolume = true;
                            });
                          },
                          onChanged: (v) {
                            setState(() {
                              _volumeFraction = v;
                            });
                            _debounceVolumeSend((v * 100).round().clamp(0, 100));
                          },
                          onChangeEnd: (v) async {
                            final pct = (v * 100).round().clamp(0, 100);
                            await _sendVolumeCommandPct(pct);
                            if (!mounted) return;
                            setState(() {
                              _isAdjustingVolume = false;
                              _volumeFraction = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(((_isAdjustingVolume && _volumeFraction != null) ? (_volumeFraction! * 100) : baseVolPct).round()).clamp(0, 100)}%',
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7)),
                      ),
                    ],
                    SizedBox(height: (_mediaHeightDp * 0.15).toDouble()),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sendLaunchDefaultMediaAppPlay,
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text(
                          'Abrir y reproducir en app predeterminada',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: customColor[500],
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
