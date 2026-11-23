import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'format.dart';

/// Rose (polar area) chart: one petal per category, equal angles, the petal's
/// length grows with the amount. Each petal is split from the centre outwards
/// into the parts of the period (weeks of a month), light to dark. Tapping a
/// petal shows it in the centre; tapping a part in the legend highlights it.
class RoseChart extends StatefulWidget {
  const RoseChart({
    super.key,
    required this.names,
    required this.colors,
    required this.parts,
    required this.partLabels,
    required this.currency,
    required this.centerLabel,
  });

  final List<String> names;
  final List<Color> colors;

  /// Per petal, the amount in each part of the period (minor units).
  final List<List<int>> parts;
  final List<String> partLabels;
  final String currency;
  final String centerLabel;

  @override
  State<RoseChart> createState() => _RoseChartState();
}

class _RoseChartState extends State<RoseChart> {
  int? _petal;
  int? _part;

  static const _shades = [1.0, 0.76, 0.56, 0.4, 0.3];

  int get _total => widget.parts.fold(0, (s, p) => s + p.fold(0, (a, b) => a + b));

  void _tap(Offset local, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final d = local - c;
    if (d.distance < _RosePainter.hole) {
      setState(() => _petal = null);
      return;
    }
    final n = widget.parts.length;
    var a = math.atan2(d.dy, d.dx) + math.pi / 2;
    if (a < 0) a += 2 * math.pi;
    final i = (a / (2 * math.pi / n)).floor() % n;
    setState(() => _petal = _petal == i ? null : i);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final total = _total;
    final sel = _petal;
    final selAmount = sel == null
        ? (_part == null ? total : widget.parts.fold<int>(0, (s, p) => s + p[_part!]))
        : (_part == null ? widget.parts[sel].fold<int>(0, (a, b) => a + b) : widget.parts[sel][_part!]);
    final centerTop = sel == null ? (_part == null ? widget.centerLabel : widget.partLabels[_part!]) : widget.names[sel];
    final centerSub = sel == null
        ? null
        : '${(total == 0 ? 0 : widget.parts[sel].fold<int>(0, (a, b) => a + b) * 100 / total).toStringAsFixed(1).replaceAll('.', ',')}%';

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, 300);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (e) => _tap(e.localPosition, size),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(widget.parts.length),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => CustomPaint(
                  size: size,
                  painter: _RosePainter(
                    parts: widget.parts,
                    colors: widget.colors,
                    shades: _shades,
                    progress: t,
                    petal: sel,
                    part: _part,
                    grid: scheme.onSurface.withValues(alpha: 0.08),
                    label: TextStyle(fontSize: 10, color: muted),
                    gridLabel: TextStyle(fontSize: 9, color: muted.withValues(alpha: 0.7)),
                    currency: widget.currency,
                  ),
                  child: SizedBox.fromSize(
                    size: size,
                    child: Center(
                      child: SizedBox(
                        width: _RosePainter.hole * 2 - 8,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              centerTop,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 9, color: muted),
                            ),
                            FittedBox(
                              child: Text(
                                formatPlainMoney(selAmount, widget.currency).split(',').first,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (centerSub != null) Text(centerSub, style: TextStyle(fontSize: 9, color: muted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            for (final (k, l) in widget.partLabels.indexed)
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() => _part = _part == k ? null : k),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(color: _part == k ? scheme.onSurface.withValues(alpha: 0.1) : null, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8793A).withValues(alpha: _shades[k.clamp(0, _shades.length - 1)]),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(l, style: TextStyle(fontSize: 12, color: _part == null || _part == k ? scheme.onSurface : muted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RosePainter extends CustomPainter {
  _RosePainter({
    required this.parts,
    required this.colors,
    required this.shades,
    required this.progress,
    required this.petal,
    required this.part,
    required this.grid,
    required this.label,
    required this.gridLabel,
    required this.currency,
  });

  static const hole = 30.0;

  final List<List<int>> parts;
  final List<Color> colors;
  final List<double> shades;
  final double progress;
  final int? petal, part;
  final Color grid;
  final TextStyle label, gridLabel;
  final String currency;

  @override
  void paint(Canvas canvas, Size size) {
    final n = parts.length;
    if (n == 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final sums = [for (final p in parts) p.fold<int>(0, (a, b) => a + b)];
    final total = sums.fold<int>(0, (a, b) => a + b);
    final mx = sums.fold<int>(1, math.max);
    final maxR = math.min(size.width, size.height) / 2 - 18;
    double r(num v) => hole + math.sqrt(v / mx) * (maxR - hole) * progress;

    // Scale circles at round amounts.
    final step = _nice(mx / 4);
    for (final v in [step, step * 2, step * 4]) {
      if (v > mx * 1.05) continue;
      final rr = r(v);
      canvas.drawCircle(
        c,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = grid,
      );
      final tp = TextPainter(
        text: TextSpan(text: '${(v / 100).round()}', style: gridLabel),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = c + Offset(-rr * 0.71 - tp.width - 2, rr * 0.71);
      tp.paint(canvas, p);
    }

    final slot = 2 * math.pi / n;
    final gap = math.min(0.05, slot * 0.12);
    for (var i = 0; i < n; i++) {
      final a0 = -math.pi / 2 + i * slot + gap / 2;
      final sweep = slot - gap;
      var acc = 0;
      final dim = petal != null && petal != i;
      for (var k = 0; k < parts[i].length; k++) {
        final v = parts[i][k];
        if (v <= 0) continue;
        final r0 = acc == 0 ? hole : r(acc);
        acc += v;
        final r1 = r(acc) - (k < parts[i].length - 1 ? 1.0 : 0);
        var alpha = shades[k.clamp(0, shades.length - 1)];
        if (part != null) alpha = part == k ? 1 : alpha * 0.18;
        if (dim) alpha *= 0.4;
        final path = Path()
          ..arcTo(Rect.fromCircle(center: c, radius: r1), a0, sweep, true)
          ..arcTo(Rect.fromCircle(center: c, radius: r0), a0 + sweep, -sweep, false)
          ..close();
        canvas.drawPath(path, Paint()..color = colors[i].withValues(alpha: alpha));
      }
      if (progress > 0.95 && total > 0 && slot > 0.25) {
        final pct = (sums[i] * 100 / total).round();
        final am = a0 + sweep / 2;
        final lr = r(sums[i]) + 11;
        final tp = TextPainter(
          text: TextSpan(text: '$pct%', style: label),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, c + Offset(lr * math.cos(am), lr * math.sin(am)) - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  static int _nice(double v) {
    if (v <= 0) return 100;
    final e = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    final f = v / e;
    final m = f < 1.5 ? 1 : (f < 3.5 ? 2 : (f < 7.5 ? 5 : 10));
    return (m * e).round();
  }

  @override
  bool shouldRepaint(_RosePainter old) => old.progress != progress || old.petal != petal || old.part != part || old.parts != parts;
}
