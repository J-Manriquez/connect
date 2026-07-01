import 'dart:io';

import 'package:connect/services/image_widget_service.dart';
import 'package:flutter/material.dart';

/// Vista previa del widget de imágenes. Replica visualmente el RemoteViews nativo.
/// Acepta la misma [ImageWidgetCfg] que usa el proveedor Kotlin.
class ImageWidgetPreview extends StatelessWidget {
  final ImageWidgetCfg cfg;
  final int? overrideIndex;

  const ImageWidgetPreview({super.key, required this.cfg, this.overrideIndex});

  int get _idx {
    final i = overrideIndex ?? cfg.currentIndex;
    if (cfg.imageList.isEmpty) return 0;
    return i.clamp(0, cfg.imageList.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final hasImages = cfg.imageList.isNotEmpty;
    final imgPath = hasImages ? cfg.imageList[_idx] : null;
    final radiusDp = cfg.cornerRadiusDp.toDouble();
    final padDp = cfg.paddingDp.toDouble();

    Widget imageContent = _buildImage(imgPath);

    // Scrim overlay
    if (cfg.scrimShow) {
      final alpha = ((cfg.scrimOpacity / 100.0) * 255).round();
      final scrimColor = Color((cfg.scrimColor & 0x00FFFFFF) | (alpha << 24));
      imageContent = Stack(
        fit: StackFit.expand,
        children: [
          imageContent,
          Container(color: scrimColor),
        ],
      );
    }

    // Caption
    if (cfg.captionShow && imgPath != null) {
      final text = _captionText(imgPath);
      if (text.isNotEmpty) {
        imageContent = Stack(
          fit: StackFit.expand,
          children: [
            imageContent,
            Positioned(
              left: 0, right: 0,
              top: cfg.captionPosition == 0 ? 0 : null,
              bottom: cfg.captionPosition == 1 ? 0 : null,
              child: Container(
                color: Color(cfg.captionBg),
                padding: EdgeInsets.all(cfg.captionPadDp.toDouble()),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(cfg.captionColor),
                    fontSize: cfg.captionSizeSp.toDouble(),
                    fontWeight: cfg.captionBold ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        );
      }
    }

    // Dot indicator
    if (cfg.dotsShow && cfg.imageList.length > 1) {
      imageContent = Stack(
        fit: StackFit.expand,
        children: [
          imageContent,
          Positioned(
            left: 0, right: 0,
            top: cfg.dotsPosition == 0 ? 6 : null,
            bottom: cfg.dotsPosition == 1 ? 6 : null,
            child: _DotsRow(
              total: cfg.imageList.length,
              current: _idx,
              activeColor: Color(cfg.dotsActiveColor),
              inactiveColor: Color(cfg.dotsInactiveColor),
              sizeDp: cfg.dotsSizeDp.toDouble(),
              spacingDp: cfg.dotsSpacingDp.toDouble(),
            ),
          ),
        ],
      );
    }

    // Controls overlay (preview always shows them as a hint)
    if (cfg.controlsVisible) {
      imageContent = Stack(
        fit: StackFit.expand,
        children: [
          imageContent,
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _ControlBtn(Icons.chevron_left),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _ControlBtn(Icons.chevron_right),
            ),
          ),
        ],
      );
    }

    // Apply clip (corner radius) and border + padding
    Widget widget = ClipRRect(
      borderRadius: BorderRadius.circular(radiusDp),
      child: SizedBox.expand(child: imageContent),
    );

    if (padDp > 0 || cfg.borderShow) {
      widget = Container(
        decoration: BoxDecoration(
          color: Color(cfg.bgColor),
          borderRadius: BorderRadius.circular(radiusDp),
          border: cfg.borderShow
              ? Border.all(
                  color: Color(cfg.borderColor),
                  width: cfg.borderThicknessDp.toDouble(),
                )
              : null,
        ),
        padding: EdgeInsets.all(padDp),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
              (radiusDp - padDp).clamp(0, radiusDp)),
          child: SizedBox.expand(child: imageContent),
        ),
      );
    }

    return widget;
  }

  Widget _buildImage(String? path) {
    bool exists = false;
    try { exists = path != null && File(path).existsSync(); } catch (_) {}
    if (!exists) {
      return Container(
        color: const Color(0xFF1E1E1E),
        child: const Center(
          child: Icon(Icons.image_outlined, color: Color(0xFF666666), size: 48),
        ),
      );
    }
    BoxFit fit;
    switch (cfg.scaleType) {
      case 0: fit = BoxFit.cover; break;
      case 1: fit = BoxFit.contain; break;
      case 2: fit = BoxFit.fill; break;
      case 3: fit = BoxFit.none; break;
      case 4: fit = BoxFit.fitWidth; break;
      default: fit = BoxFit.cover;
    }
    return Container(
      color: Color(cfg.bgColor),
      child: Image.file(
        File(path!),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF1E1E1E),
          child: const Center(
            child: Icon(Icons.broken_image_outlined, color: Color(0xFF666666), size: 48),
          ),
        ),
      ),
    );
  }

  String _captionText(String path) {
    if (cfg.captionSource == 0) {
      return path.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
    } else {
      try {
        final ms = File(path).lastModifiedSync();
        final d = ms;
        return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      } catch (_) {
        return '';
      }
    }
  }
}

class _DotsRow extends StatelessWidget {
  final int total;
  final int current;
  final Color activeColor;
  final Color inactiveColor;
  final double sizeDp;
  final double spacingDp;

  const _DotsRow({
    required this.total,
    required this.current,
    required this.activeColor,
    required this.inactiveColor,
    required this.sizeDp,
    required this.spacingDp,
  });

  @override
  Widget build(BuildContext context) {
    const maxDots = 12;
    final display = total.clamp(0, maxDots);
    final windowStart = total <= maxDots ? 0 : (current - maxDots ~/ 2).clamp(0, total - maxDots);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(display, (i) {
        final actualIdx = windowStart + i;
        return Container(
          width: sizeDp,
          height: sizeDp,
          margin: EdgeInsets.symmetric(horizontal: spacingDp / 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: actualIdx == current ? activeColor : inactiveColor,
          ),
        );
      }),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  const _ControlBtn(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}
