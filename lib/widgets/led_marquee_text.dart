import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class LedMarqueeText extends StatefulWidget {
  final String text;

  /// Override the default style. If null, uses:
  /// TextStyle(color: temaProvider.texto, fontWeight: FontWeight.w700, fontSize: 18)
  final TextStyle? style;

  /// Controls alignment when the text fits without scrolling.
  /// Defaults to [TextAlign.center] (centered on screen, useful for AppBar titles).
  /// Use [TextAlign.start] for left-aligned contexts such as cards.
  final TextAlign textAlign;

  final bool forceScroll;
  final bool autoScroll;
  final double velocityPxPerSecond;
  final double gap;
  final Duration pauseAfterRound;
  final Duration startDelay;

  const LedMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.center,
    this.forceScroll = false,
    this.autoScroll = true,
    this.velocityPxPerSecond = 55,
    this.gap = 40,
    this.startDelay = Duration.zero,
    this.pauseAfterRound = Duration.zero,
  });

  @override
  State<LedMarqueeText> createState() => _LedMarqueeTextState();
}

class _LedMarqueeTextState extends State<LedMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _startDelayTimer;

  // Cached layout values
  double _lastTextWidth = -1;
  double _lastCycle = -1;
  bool _wasScrolling = false;

  // ── Manual-drag state ────────────────────────────────────────────────────
  bool _userHolding = false;
  double _frozenControllerValue = 0;
  double _dragOffset = 0;

  Timer? _resumeTimer;
  static const _resumeDelay = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(covariant LedMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.forceScroll != widget.forceScroll ||
        oldWidget.autoScroll != widget.autoScroll ||
        oldWidget.velocityPxPerSecond != widget.velocityPxPerSecond ||
        oldWidget.gap != widget.gap ||
        oldWidget.pauseAfterRound != widget.pauseAfterRound ||
        oldWidget.startDelay != widget.startDelay;

    if (changed) {
      _lastTextWidth = -1;
      _lastCycle = -1;
    }
  }

  @override
  void dispose() {
    _startDelayTimer?.cancel();
    _resumeTimer?.cancel();
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  // ── Animation lifecycle ──────────────────────────────────────────────────

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _controller.value = 0;
      if (widget.pauseAfterRound > Duration.zero) {
        _startDelayTimer?.cancel();
        _startDelayTimer = Timer(widget.pauseAfterRound, () {
          if (!mounted) return;
          _startAnimation(_lastCycle);
        });
      } else {
        _startAnimation(_lastCycle);
      }
    }
  }

  void _startAnimation(double cycle) {
    if (cycle <= 0 || _userHolding) return;
    final velocity = math.max(1.0, widget.velocityPxPerSecond);
    final durationMs = (cycle / velocity * 1000).round();
    _controller.duration = Duration(milliseconds: math.max(300, durationMs));
    _controller.forward(from: _controller.value);
  }

  void _scheduleAnimation({
    required bool shouldScroll,
    required double cycle,
    required double textWidth,
  }) {
    final cycleChanged = (cycle - _lastCycle).abs() > 0.5;
    final textWChanged = (textWidth - _lastTextWidth).abs() > 0.5;
    final scrollChanged = shouldScroll != _wasScrolling;

    if (!cycleChanged && !textWChanged && !scrollChanged) return;

    _lastTextWidth = textWidth;
    _lastCycle = cycle;
    _wasScrolling = shouldScroll;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startDelayTimer?.cancel();

      if (!shouldScroll) {
        _controller.stop();
        _controller.value = 0;
        return;
      }

      if (!widget.autoScroll) {
        _controller.stop();
        return;
      }

      if (widget.startDelay > Duration.zero && !_controller.isAnimating) {
        _startDelayTimer = Timer(widget.startDelay, () {
          if (!mounted) return;
          _startAnimation(cycle);
        });
      } else {
        _startAnimation(cycle);
      }
    });
  }

  // ── Gesture handlers ─────────────────────────────────────────────────────

  void _onLongPressStart(LongPressStartDetails _) {
    _resumeTimer?.cancel();
    _controller.stop();
    _frozenControllerValue = _controller.value;
    _dragOffset = 0;
    setState(() => _userHolding = true);
  }

  void _onLongPressEnd(LongPressEndDetails _) => _releaseHold();
  void _onLongPressCancel() => _releaseHold();

  void _releaseHold() {
    if (!_userHolding) return;

    if (_lastCycle > 0) {
      final rawPx = _frozenControllerValue * _lastCycle - _dragOffset;
      final wrappedPx = rawPx % _lastCycle;
      _controller.value = wrappedPx / _lastCycle;
    }

    _dragOffset = 0;
    setState(() => _userHolding = false);

    _resumeTimer = Timer(_resumeDelay, () {
      if (!mounted) return;
      _startAnimation(_lastCycle);
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Resolve style: start from the app default, then merge any overrides
    // provided via widget.style. This way the caller can pass e.g.
    // TextStyle(fontSize: 14) and only that property is overridden — color,
    // weight, etc. keep their defaults from the theme.
    final defaultStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w700,
      fontSize: 18,
    );
    final style = widget.style == null
        ? defaultStyle
        : defaultStyle.merge(widget.style);

    final rawText = widget.text;
    final text = rawText.trim().isEmpty ? '-' : rawText;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: double.infinity);

        final textWidth = textPainter.size.width;
        final measuredH = textPainter.size.height;
        final fallbackH = (style.fontSize ?? 18) * (style.height ?? 1.2);
        final baseH = math.max(1.0, measuredH > 0 ? measuredH : fallbackH);

        final metrics = textPainter.computeLineMetrics();
        final textHeight = metrics.isNotEmpty
            ? math.max(baseH, metrics.first.ascent + metrics.first.descent)
            : baseH;

        // Auto-detect: scroll only when text is wider than available space
        final shouldScroll = widget.forceScroll || textWidth > maxWidth;
        final cycle = math.max(1.0, textWidth + widget.gap);

        _scheduleAnimation(
          shouldScroll: shouldScroll,
          cycle: cycle,
          textWidth: textWidth,
        );

        // ── Static mode: text fits ──────────────────────────────────────────
        if (!shouldScroll) {
          if (widget.textAlign != TextAlign.center) {
            return SizedBox(
              width: maxWidth,
              height: textHeight + 3.0,
              child: Align(
                alignment: widget.textAlign == TextAlign.start || widget.textAlign == TextAlign.left
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Text(
                  text,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textAlign: widget.textAlign,
                ),
              ),
            );
          }
          return _CenteredTitle(
            text: text,
            style: style,
            maxWidth: maxWidth,
            textHeight: textHeight,
          );
        }

        // ── Scroll mode: marquee with long-press drag ────────────────────
        const descenderPad = 3.0;
        final totalHeight = textHeight + descenderPad;

        return Listener(
          onPointerMove: (event) {
            if (_userHolding) {
              setState(() => _dragOffset += event.delta.dx);
            }
          },
          onPointerUp: (_) {
            if (_userHolding) _releaseHold();
          },
          onPointerCancel: (_) {
            if (_userHolding) _releaseHold();
          },
          child: RawGestureDetector(
            gestures: {
              LongPressGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: const Duration(milliseconds: 250),
                ),
                (instance) {
                  instance
                    ..onLongPressStart = _onLongPressStart
                    ..onLongPressEnd = _onLongPressEnd
                    ..onLongPressCancel = _onLongPressCancel;
                },
              ),
            },
            child: SizedBox(
              width: maxWidth,
              height: totalHeight,
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    double dx = -_controller.value * cycle;
                    if (_userHolding) {
                      dx = -_frozenControllerValue * cycle + _dragOffset;
                    }

                    return SizedBox(
                      width: maxWidth,
                      height: totalHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Transform.translate(
                            offset: Offset(dx, 0),
                            child: Text(
                              text,
                              style: style,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(dx + cycle, 0),
                            child: Text(
                              text,
                              style: style,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Helper: centers text on screen regardless of the slot position ───────────
//
// With centerTitle:false the title slot is NOT symmetric. This widget reads
// its own global position via RenderBox and shifts the text so it lands on
// the true screen center — works for any combination of leading/actions.
class _CenteredTitle extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double maxWidth;
  final double textHeight;

  const _CenteredTitle({
    required this.text,
    required this.style,
    required this.maxWidth,
    required this.textHeight,
  });

  @override
  State<_CenteredTitle> createState() => _CenteredTitleState();
}

class _CenteredTitleState extends State<_CenteredTitle> {
  double _nudge = 0;
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _computeNudge());
  }

  @override
  void didUpdateWidget(covariant _CenteredTitle old) {
    super.didUpdateWidget(old);
    if (old.maxWidth != widget.maxWidth) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _computeNudge());
    }
  }

  void _computeNudge() {
    if (!mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    // Global x position of the left edge of this slot
    final slotLeft = box.localToGlobal(Offset.zero).dx;
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Where the center of this slot is on screen
    final slotCenter = slotLeft + widget.maxWidth / 2;
    final screenCenter = screenWidth / 2;

    // How much to shift so the text center aligns with the screen center
    final nudge = screenCenter - slotCenter;

    if ((nudge - _nudge).abs() > 0.5) {
      setState(() => _nudge = nudge);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _key,
      width: widget.maxWidth,
      height: widget.textHeight + 3.0,
      child: Transform.translate(
        offset: Offset(_nudge, 0),
        child: Center(
          child: Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}