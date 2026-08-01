import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';

/// Sélecteur de couleur HSV compact (aucune dépendance externe) :
/// carré saturation/valeur + barre de teinte + aperçu hex.
/// Renvoie la couleur choisie via Navigator.pop.
class ColorPickerSheet extends ConsumerStatefulWidget {
  final Color initial;
  const ColorPickerSheet({super.key, required this.initial});

  @override
  ConsumerState<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends ConsumerState<ColorPickerSheet> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.colorPickerTitle,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          // Carré saturation (→) / valeur (↓), toujours LTR : c'est une
          // surface de couleur, pas un contenu textuel.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 160,
                  child: LayoutBuilder(builder: (context, constraints) {
                    void update(Offset local) {
                      setState(() {
                        _hsv = _hsv.withSaturation(
                          (local.dx / constraints.maxWidth).clamp(0.0, 1.0),
                        );
                        _hsv = _hsv.withValue(
                          (1 - local.dy / constraints.maxHeight)
                              .clamp(0.0, 1.0),
                        );
                      });
                    }

                    return GestureDetector(
                      onPanDown: (d) => update(d.localPosition),
                      onPanUpdate: (d) => update(d.localPosition),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CustomPaint(
                          painter: _SvPainter(_hsv),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 22,
                  child: LayoutBuilder(builder: (context, constraints) {
                    void update(Offset local) {
                      setState(() {
                        _hsv = _hsv.withHue(
                          (local.dx / constraints.maxWidth * 360)
                              .clamp(0.0, 359.9),
                        );
                      });
                    }

                    return GestureDetector(
                      onPanDown: (d) => update(d.localPosition),
                      onPanUpdate: (d) => update(d.localPosition),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: CustomPaint(
                          painter: _HuePainter(_hsv.hue),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '#${(_color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                style: const TextStyle(
                    fontSize: 13, fontFamily: 'monospace'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context, _color),
                child: Text(s.apply),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SvPainter extends CustomPainter {
  final HSVColor hsv;
  _SvPainter(this.hsv);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
    final knob = Offset(
      hsv.saturation * size.width,
      (1 - hsv.value) * size.height,
    );
    canvas.drawCircle(
        knob, 9, Paint()..color = Colors.black.withValues(alpha: 0.4));
    canvas.drawCircle(
      knob,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_SvPainter oldDelegate) => oldDelegate.hsv != hsv;
}

class _HuePainter extends CustomPainter {
  final double hue;
  _HuePainter(this.hue);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            for (var h = 0; h <= 360; h += 60)
              HSVColor.fromAHSV(1, h.toDouble().clamp(0, 359.9), 1, 1)
                  .toColor(),
          ],
        ).createShader(rect),
    );
    final x = hue / 360 * size.width;
    canvas.drawCircle(Offset(x, size.height / 2), 8,
        Paint()..color = Colors.black.withValues(alpha: 0.4));
    canvas.drawCircle(
      Offset(x, size.height / 2),
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_HuePainter oldDelegate) => oldDelegate.hue != hue;
}
