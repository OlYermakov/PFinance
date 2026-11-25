// Alternative main charts for the Statistics tab, picked in More → Стиль.
// All of them are flat (no glow or glass), use the rank colours and the
// same card height as the rose, so switching keeps the page steady.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'format.dart';

/// Which chart the Statistics tab shows above the category list.
enum StatsChart { rose, donut, bars, treemap, bubbles, cumulative, radial }

const statsChartLabels = {
  StatsChart.rose: 'Троянда з тижнями',
  StatsChart.donut: 'Пончик',
  StatsChart.bars: 'Смуги за рангом',
  StatsChart.treemap: 'Плитки',
  StatsChart.bubbles: 'Бульбашки',
  StatsChart.cumulative: 'Накопичувальна лінія',
  StatsChart.radial: 'Радіальні смуги',
};

StatsChart statsChartOf(String name) => StatsChart.values.asNameMap()[name] ?? StatsChart.rose;

/// Grows from 0 to 1 once, when the chart first appears.
class _Grow extends StatelessWidget {
  const _Grow({required this.builder});
  final Widget Function(double t) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 700),
    curve: Curves.easeOutCubic,
    builder: (context, t, _) => builder(t),
  );
}

TextStyle _muted(BuildContext context, [double size = 12]) => TextStyle(fontSize: size, color: Theme.of(context).colorScheme.onSurfaceVariant);

// ---- 2. Смуги за рангом --------------------------------------------------------------

/// One bar per category, longest first; the length is the share of the biggest.
class RankBars extends StatelessWidget {
  const RankBars({super.key, required this.names, required this.amounts, required this.colors, required this.currency, this.onTap});
  final List<String> names;
  final List<int> amounts;
  final List<Color> colors;
  final String currency;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final max = amounts.isEmpty ? 1 : amounts.reduce(math.max);
    final total = amounts.fold<int>(0, (s, a) => s + a);
    final rows = math.min(names.length, 8);
    final rest = amounts.skip(rows).fold<int>(0, (s, a) => s + a);
    final scheme = Theme.of(context).colorScheme;
    return _Grow(
      builder: (t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < rows; i++)
              InkWell(
                onTap: onTap == null ? null : () => onTap!(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(names[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                          ),
                          Text(money(amounts[i], currency), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LayoutBuilder(
                        builder: (context, c) => Stack(
                          children: [
                            Container(
                              height: 10,
                              decoration: BoxDecoration(color: scheme.onSurface.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(5)),
                            ),
                            Container(
                              height: 10,
                              width: math.max(4, c.maxWidth * amounts[i] / max * t),
                              decoration: BoxDecoration(color: colors[i], borderRadius: BorderRadius.circular(5)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (rest > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(child: Text('Інші (${names.length - rows})', style: _muted(context, 13))),
                    Text(money(rest, currency), style: _muted(context, 13)),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text('Разом', style: _muted(context, 13))),
                Text(money(total, currency), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- 6. Бульбашки ----------------------------------------------------------------------

/// Circles sized by amount (area ∝ sum), packed around the biggest one.
class BubbleChart extends StatefulWidget {
  const BubbleChart({super.key, required this.names, required this.amounts, required this.colors, required this.currency});
  final List<String> names;
  final List<int> amounts;
  final List<Color> colors;
  final String currency;

  @override
  State<BubbleChart> createState() => _BubbleChartState();
}

class _BubbleChartState extends State<BubbleChart> {
  int? _sel;

  /// Greedy packing: each circle goes to the free spot nearest the centre.
  static List<({Offset c, double r})> _pack(List<double> radii) {
    final placed = <({Offset c, double r})>[];
    for (final r in radii) {
      if (placed.isEmpty) {
        placed.add((c: Offset.zero, r: r));
        continue;
      }
      Offset? best;
      var bestD = double.infinity;
      for (final a in placed) {
        for (var k = 0; k < 36; k++) {
          final ang = k * math.pi / 18;
          final p = a.c + Offset(math.cos(ang), math.sin(ang)) * (a.r + r + 2);
          final d = p.distance;
          if (d >= bestD) continue;
          if (placed.every((b) => (b.c - p).distance >= b.r + r + 1.5)) {
            best = p;
            bestD = d;
          }
        }
      }
      placed.add((c: best ?? Offset(0, bestD), r: r));
    }
    return placed;
  }

  @override
  Widget build(BuildContext context) {
    const h = 280.0;
    final n = math.min(widget.amounts.length, 12);
    final total = widget.amounts.fold<int>(0, (s, a) => s + a);
    return LayoutBuilder(
      builder: (context, cons) {
        final w = cons.maxWidth;
        final raw = [for (var i = 0; i < n; i++) math.sqrt(widget.amounts[i].toDouble())];
        var circles = _pack(raw);
        // Scale the packing to fit the card.
        var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0;
        for (final b in circles) {
          minX = math.min(minX, b.c.dx - b.r);
          maxX = math.max(maxX, b.c.dx + b.r);
          minY = math.min(minY, b.c.dy - b.r);
          maxY = math.max(maxY, b.c.dy + b.r);
        }
        final s = math.min((w - 24) / (maxX - minX), (h - 16) / (maxY - minY));
        final mid = Offset((minX + maxX) / 2, (minY + maxY) / 2);
        circles = [for (final b in circles) (c: (b.c - mid) * s + Offset(w / 2, h / 2), r: b.r * s)];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (e) {
            final i = circles.indexWhere((b) => (b.c - e.localPosition).distance <= b.r);
            setState(() => _sel = i < 0 || i == _sel ? null : i);
          },
          child: _Grow(
            builder: (t) => CustomPaint(
              size: Size(w, h),
              painter: _BubblePainter(
                circles: circles,
                colors: widget.colors,
                names: widget.names,
                amounts: widget.amounts,
                total: total,
                currency: widget.currency,
                progress: t,
                selected: _sel,
                text: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({
    required this.circles,
    required this.colors,
    required this.names,
    required this.amounts,
    required this.total,
    required this.currency,
    required this.progress,
    required this.selected,
    required this.text,
  });
  final List<({Offset c, double r})> circles;
  final List<Color> colors;
  final List<String> names;
  final List<int> amounts;
  final int total;
  final String currency;
  final double progress;
  final int? selected;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < circles.length; i++) {
      final b = circles[i];
      final r = b.r * progress;
      final dim = selected != null && selected != i;
      canvas.drawCircle(b.c, r, Paint()..color = colors[i].withValues(alpha: dim ? 0.35 : 0.9));
      if (progress < 0.98 || b.r < 22) continue;
      final pct = total == 0 ? 0 : amounts[i] * 100 / total;
      final lines = selected == i ? [names[i], money(amounts[i], currency)] : [names[i], '${pct.toStringAsFixed(pct < 10 ? 1 : 0).replaceAll('.', ',')}%'];
      final tp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${lines[0]}\n',
              style: TextStyle(fontSize: math.min(13, b.r / 3.2), fontWeight: FontWeight.w600, color: Colors.white),
            ),
            TextSpan(
              text: lines[1],
              style: TextStyle(fontSize: math.min(12, b.r / 3.6), color: Colors.white.withValues(alpha: 0.9)),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: b.r * 1.7);
      tp.paint(canvas, b.c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.progress != progress || old.selected != selected || old.circles != circles;
}

// ---- 7. Накопичувальна лінія -----------------------------------------------------------

/// Spending (or income) summed day by day through the period, against the
/// previous period and, for a month with a budget, the budget line.
class CumulativeLine extends StatelessWidget {
  const CumulativeLine({
    super.key,
    required this.current,
    required this.previous,
    required this.days,
    required this.today,
    required this.currency,
    required this.color,
    required this.prevLabel,
    this.budget,
  });

  /// Day totals of this period (index 0 = first day).
  final List<int> current;

  /// Day totals of the previous period, same length or shorter.
  final List<int> previous;
  final int days;

  /// Index of today inside the period; null when the period is over or ahead.
  final int? today;
  final String currency;
  final Color color;
  final String prevLabel;
  final int? budget;

  static List<int> _cum(List<int> v) {
    var s = 0;
    return [for (final x in v) s += x];
  }

  @override
  Widget build(BuildContext context) {
    final cur = _cum(current);
    final prev = _cum(previous);
    final upto = today ?? days - 1;
    final nowSum = cur.isEmpty ? 0 : cur[math.min(upto, cur.length - 1)];
    final prevSum = prev.isEmpty ? 0 : prev[math.min(upto, prev.length - 1)];
    final diff = nowSum - prevSum;
    final muted = _muted(context, 13);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(money(nowSum, currency), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            prev.isEmpty || prevSum == 0
                ? (today != null ? 'на сьогодні' : 'за період')
                : '${diff <= 0 ? 'на ${money(-diff, currency)} менше' : 'на ${money(diff, currency)} більше'}, ніж $prevLabel ${today != null ? 'на цей день' : ''}'
                      .trim(),
            style: muted,
          ),
          const SizedBox(height: 10),
          _Grow(
            builder: (t) => CustomPaint(
              size: const Size.fromHeight(190),
              painter: _LinePainter(
                cur: cur.take(upto + 1).toList(),
                prev: prev,
                days: days,
                budget: budget,
                color: color,
                grid: Theme.of(context).colorScheme.onSurface,
                label: _muted(context, 10),
                currency: currency,
                progress: t,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            children: [
              _legend(context, color, 'цей період', solid: true),
              _legend(context, Theme.of(context).colorScheme.onSurfaceVariant, prevLabel),
              if (budget != null) _legend(context, Theme.of(context).colorScheme.error, 'бюджет'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Color c, String text, {bool solid = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 14, height: solid ? 3 : 2, color: solid ? c : c.withValues(alpha: 0.6)),
      const SizedBox(width: 6),
      Text(text, style: _muted(context, 11)),
    ],
  );
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.cur,
    required this.prev,
    required this.days,
    required this.budget,
    required this.color,
    required this.grid,
    required this.label,
    required this.currency,
    required this.progress,
  });
  final List<int> cur, prev;
  final int days;
  final int? budget;
  final Color color, grid;
  final TextStyle label;
  final String currency;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 0.0, bottom = 16.0;
    final w = size.width - left, h = size.height - bottom;
    var top = [...cur, ...prev, budget ?? 0].fold<int>(1, math.max).toDouble();
    top *= 1.08;
    double x(int i) => left + (days <= 1 ? 0 : w * i / (days - 1));
    double y(int v) => h - h * v / top;

    final line = Paint()
      ..color = grid.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var k = 1; k <= 3; k++) {
      canvas.drawLine(Offset(left, h * k / 4), Offset(size.width, h * k / 4), line);
    }
    canvas.drawLine(Offset(left, h), Offset(size.width, h), line..color = grid.withValues(alpha: 0.25));
    // day labels: first, middle, last
    for (final i in {0, days ~/ 2, days - 1}) {
      final tp = TextPainter(
        text: TextSpan(text: '${i + 1}', style: label),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((x(i) - tp.width / 2).clamp(0, size.width - tp.width), h + 3));
    }

    if (budget != null) {
      final by = y(budget!);
      final dash = Paint()
        ..color = label.color!.withValues(alpha: 0.0)
        ..strokeWidth = 1.4;
      dash.color = const Color(0xFFE5534B).withValues(alpha: 0.8);
      for (var dx = left; dx < size.width; dx += 9) {
        canvas.drawLine(Offset(dx, by), Offset(math.min(dx + 5, size.width), by), dash);
      }
    }

    Path pathOf(List<int> v, int count) {
      final p = Path();
      for (var i = 0; i < count; i++) {
        final pt = Offset(x(i), y(v[i]));
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p;
    }

    final n = math.min(prev.length, days);
    if (n > 1) {
      canvas.drawPath(
        pathOf(prev, (n * progress).ceil().clamp(1, n)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = label.color!.withValues(alpha: 0.6),
      );
    }
    final m = (cur.length * progress).ceil().clamp(0, cur.length);
    if (m > 0) {
      final p = pathOf(cur, m);
      final fill = Path.from(p)
        ..lineTo(x(m - 1), h)
        ..lineTo(x(0), h)
        ..close();
      canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
      canvas.drawCircle(Offset(x(m - 1), y(cur[m - 1])), 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.progress != progress || old.cur != cur || old.prev != prev;
}

// ---- 16. Радіальні смуги -----------------------------------------------------------------

/// Each category is an arc on its own ring; the biggest goes three-quarters
/// round and the others in proportion. The total sits in the middle.
class RadialBars extends StatefulWidget {
  const RadialBars({super.key, required this.names, required this.amounts, required this.colors, required this.currency});
  final List<String> names;
  final List<int> amounts;
  final List<Color> colors;
  final String currency;

  @override
  State<RadialBars> createState() => _RadialBarsState();
}

class _RadialBarsState extends State<RadialBars> {
  int? _sel;

  @override
  Widget build(BuildContext context) {
    const h = 280.0;
    final n = math.min(widget.amounts.length, 6);
    final total = widget.amounts.fold<int>(0, (s, a) => s + a);
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, cons) {
        final size = Size(cons.maxWidth, h);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (e) {
            final i = _RadialPainter.ringAt(e.localPosition, size, n);
            setState(() => _sel = i == null || i == _sel ? null : i);
          },
          child: _Grow(
            builder: (t) => CustomPaint(
              size: size,
              painter: _RadialPainter(
                amounts: widget.amounts.take(n).toList(),
                names: widget.names,
                colors: widget.colors,
                progress: t,
                selected: _sel,
                track: scheme.onSurface.withValues(alpha: 0.06),
                label: _muted(context, 11),
              ),
              child: SizedBox.fromSize(
                size: size,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_sel == null ? 'Разом' : widget.names[_sel!], style: _muted(context, 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        money(_sel == null ? total : widget.amounts[_sel!], widget.currency),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RadialPainter extends CustomPainter {
  _RadialPainter({
    required this.amounts,
    required this.names,
    required this.colors,
    required this.progress,
    required this.selected,
    required this.track,
    required this.label,
  });
  final List<int> amounts;
  final List<String> names;
  final List<Color> colors;
  final double progress;
  final int? selected;
  final Color track;
  final TextStyle label;

  static const _inner = 50.0;

  static ({double outer, double step}) _geom(Size size, int n) {
    final outer = math.min(size.height, size.width) / 2 - 6;
    return (outer: outer, step: n == 0 ? 0 : (outer - _inner) / n);
  }

  /// Ring index under [p], 0 = outermost (the biggest).
  static int? ringAt(Offset p, Size size, int n) {
    final g = _geom(size, n);
    final d = (p - size.center(Offset.zero)).distance;
    if (d < _inner || d > g.outer) return null;
    return ((g.outer - d) / g.step).floor().clamp(0, n - 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = amounts.length;
    if (n == 0) return;
    final c = size.center(Offset.zero);
    final g = _geom(size, n);
    final max = amounts.reduce(math.max).toDouble();
    final stroke = g.step * 0.72;
    const start = -math.pi / 2;
    for (var i = 0; i < n; i++) {
      final r = g.outer - g.step * (i + 0.5);
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawArc(
        rect,
        start,
        math.pi * 1.5,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = track,
      );
      final sweep = math.max(0.02, math.pi * 1.5 * amounts[i] / max * progress);
      final dim = selected != null && selected != i;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = colors[i].withValues(alpha: dim ? 0.35 : 1),
      );
      // name at the start of the ring, in the empty quarter
      if (stroke >= 7) {
        final tp = TextPainter(
          text: TextSpan(
            text: names[i],
            style: label.copyWith(fontSize: math.min(11, stroke * 0.9)),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: math.max(20, size.width / 2 - 8));
        tp.paint(canvas, Offset(c.dx - tp.width - 6, c.dy - r - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_RadialPainter old) => old.progress != progress || old.selected != selected || old.amounts != amounts;
}

// ---- 3. Плитки (treemap) ----------------------------------------------------------------

/// Rectangles whose area is the category's share (squarified layout), with
/// the name, share and amount inside when the tile is big enough.
class TreemapChart extends StatelessWidget {
  const TreemapChart({super.key, required this.names, required this.amounts, required this.colors, required this.currency, this.onTap});
  final List<String> names;
  final List<int> amounts;
  final List<Color> colors;
  final String currency;
  final ValueChanged<int>? onTap;

  /// Squarified treemap (Bruls et al.): fills rows along the shorter side,
  /// keeping tiles as close to squares as possible.
  static List<Rect> layout(List<double> values, Rect area) {
    final out = List<Rect>.filled(values.length, Rect.zero);
    final total = values.fold<double>(0, (s, v) => s + v);
    if (total <= 0) return out;
    final scale = area.width * area.height / total;
    var rest = area;
    var i = 0;
    while (i < values.length) {
      final side = math.min(rest.width, rest.height);
      final row = <int>[];
      double worst(List<int> r) {
        final s = r.fold<double>(0, (a, k) => a + values[k] * scale);
        final mx = r.map((k) => values[k] * scale).reduce(math.max);
        final mn = r.map((k) => values[k] * scale).reduce(math.min);
        return math.max(side * side * mx / (s * s), (s * s) / (side * side * mn));
      }

      row.add(i++);
      while (i < values.length && worst([...row, i]) <= worst(row)) {
        row.add(i++);
      }
      final sum = row.fold<double>(0, (a, k) => a + values[k] * scale);
      final thick = sum / side;
      var pos = 0.0;
      for (final k in row) {
        final len = values[k] * scale / thick;
        out[k] = rest.width >= rest.height ? Rect.fromLTWH(rest.left, rest.top + pos, thick, len) : Rect.fromLTWH(rest.left + pos, rest.top, len, thick);
        pos += len;
      }
      rest = rest.width >= rest.height
          ? Rect.fromLTRB(rest.left + thick, rest.top, rest.right, rest.bottom)
          : Rect.fromLTRB(rest.left, rest.top + thick, rest.right, rest.bottom);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    const h = 280.0;
    final n = math.min(amounts.length, 12);
    final total = amounts.fold<int>(0, (s, a) => s + a);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, c) {
          final rects = layout([for (var i = 0; i < n; i++) amounts[i].toDouble()], Rect.fromLTWH(0, 0, c.maxWidth, h));
          return _Grow(
            builder: (t) => SizedBox(
              height: h,
              child: Stack(
                children: [
                  for (var i = 0; i < n; i++)
                    Positioned.fromRect(
                      rect: rects[i].deflate(1.5),
                      child: Opacity(
                        opacity: t,
                        child: GestureDetector(
                          onTap: onTap == null ? null : () => onTap!(i),
                          child: Container(
                            decoration: BoxDecoration(color: colors[i], borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.all(6),
                            alignment: Alignment.topLeft,
                            child: rects[i].width < 44 || rects[i].height < 30
                                ? null
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        names[i],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      if (rects[i].height >= 48)
                                        Text(
                                          '${(amounts[i] * 100 / (total == 0 ? 1 : total)).toStringAsFixed(1).replaceAll('.', ',')}%',
                                          maxLines: 1,
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
                                        ),
                                      if (rects[i].height >= 66 && rects[i].width >= 80)
                                        Text(
                                          money(amounts[i], currency),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
