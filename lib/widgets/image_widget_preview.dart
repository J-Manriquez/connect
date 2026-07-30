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
      final iconColor = Color(cfg.ctrlIconColor);
      final bgColor = Color(cfg.ctrlBgColor);
      final radius = cfg.ctrlCornerRadiusDp.toDouble();

      final prevBtn = _ControlBtn(
        icon: Icons.chevron_left,
        iconColor: iconColor,
        bgColor: bgColor,
        radius: radius,
      );
      final nextBtn = _ControlBtn(
        icon: Icons.chevron_right,
        iconColor: iconColor,
        bgColor: bgColor,
        radius: radius,
      );

      Widget controls;
      if (cfg.ctrlHorizPos == 1) {
        // Centrado: ambos botones juntos en el centro horizontal
        controls = Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [prevBtn, const SizedBox(width: 8), nextBtn],
          ),
        );
        if (cfg.ctrlVertPos == 0) controls = Align(alignment: Alignment.topCenter, child: Padding(padding: const EdgeInsets.only(top: 6), child: Row(mainAxisSize: MainAxisSize.min, children: [prevBtn, const SizedBox(width: 8), nextBtn])));
        if (cfg.ctrlVertPos == 2) controls = Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(mainAxisSize: MainAxisSize.min, children: [prevBtn, const SizedBox(width: 8), nextBtn])));
      } else {
        // Expandido: prev a la izquierda, next a la derecha
        final vertAlignEnum = switch (cfg.ctrlVertPos) {
          0 => Alignment.topLeft,
          2 => Alignment.bottomLeft,
          _ => Alignment.centerLeft,
        };
        final vertAlignEnumR = switch (cfg.ctrlVertPos) {
          0 => Alignment.topRight,
          2 => Alignment.bottomRight,
          _ => Alignment.centerRight,
        };
        controls = Stack(
          children: [
            Align(
              alignment: vertAlignEnum,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 6,
                  top: cfg.ctrlVertPos == 0 ? 6 : 0,
                  bottom: cfg.ctrlVertPos == 2 ? 6 : 0,
                ),
                child: prevBtn,
              ),
            ),
            Align(
              alignment: vertAlignEnumR,
              child: Padding(
                padding: EdgeInsets.only(
                  right: 6,
                  top: cfg.ctrlVertPos == 0 ? 6 : 0,
                  bottom: cfg.ctrlVertPos == 2 ? 6 : 0,
                ),
                child: nextBtn,
              ),
            ),
          ],
        );
      }

      imageContent = Stack(
        fit: StackFit.expand,
        children: [imageContent, controls],
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
      print('[img_preview] path nulo o no existe: $path');
      return ColoredBox(
        color: const Color(0xFF1E1E1E),
        child: const Center(
          child: Icon(Icons.image_outlined, color: Color(0xFF666666), size: 48),
        ),
      );
    }

    const fitNames = ['cover','contain','fill','none','fitWidth'];
    final fitName = cfg.scaleType < fitNames.length ? fitNames[cfg.scaleType] : '?';
    BoxFit fit;
    switch (cfg.scaleType) {
      case 0: fit = BoxFit.cover; break;
      case 1: fit = BoxFit.contain; break;
      case 2: fit = BoxFit.fill; break;
      case 3: fit = BoxFit.none; break;
      case 4: fit = BoxFit.fitWidth; break;
      default: fit = BoxFit.cover;
    }

    print('[img_preview] buildImage scaleType=${cfg.scaleType}($fitName) path=$path bgColor=0x${cfg.bgColor.toRadixString(16)}');

    // FittedBox garantiza escala correcta + centrado para TODOS los tamaños/aspect ratios.
    // Image.file sin width/height → tamaño intrínseco → FittedBox escala para llenar el padre.
    return SizedBox.expand(
      child: ColoredBox(
        color: Color(cfg.bgColor),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            print('[img_preview] LayoutBuilder constraints=${constraints.maxWidth.toInt()}x${constraints.maxHeight.toInt()} fit=$fitName');
            return FittedBox(
              fit: fit,
              alignment: Alignment.center,
              child: Image.file(
                File(path!),
                frameBuilder: (ctx, child, frame, _) {
                  if (frame != null) {
                    // Imagen cargada: intentar obtener dimensiones desde el widget tree
                    print('[img_preview] imagen cargada frame=$frame fit=$fitName');
                  }
                  return child;
                },
                errorBuilder: (_, err, __) {
                  print('[img_preview] ERROR cargando imagen: $err');
                  return const SizedBox(
                    width: 48, height: 48,
                    child: Icon(Icons.broken_image_outlined, color: Color(0xFF666666), size: 48),
                  );
                },
              ),
            );
          },
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
  final Color iconColor;
  final Color bgColor;
  final double radius;

  const _ControlBtn({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }
}
