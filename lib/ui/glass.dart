import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';


/// App backdrop: a solid, calm colour behind the flat panels.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? const Color(0xFF111318) : const Color(0xFFF2F3F7),
      child: child,
    );
  }
}

/// Background of a flat settings/list panel (MM-style rows).
Color panelColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1B1E25) : Colors.white;

/// Flat section panel (Money Manager–like): a quiet solid surface with no
/// blur, rim or glow, so lists read as plain rows.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 14,
    this.tint,
    this.blur = 0,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final double blur; // kept for API compatibility; unused
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final br = BorderRadius.circular(math.min(radius, 14));
    final base = dark ? const Color(0xFF1B1E25) : Colors.white;
    final fill = tint == null ? base : Color.alphaBlend(tint!.withValues(alpha: dark ? 0.06 : 0.04), base);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, borderRadius: br, child: content);
    }
    return Material(
      color: fill,
      borderRadius: br,
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

/// The PF logo as the PF dashboard shows it: a 4×4 dot grid lit as a rising
/// staircase (purple → blue → cyan → mint), geometric "PF" letters and the
/// "ПЕРСОНАЛЬНІ ФІНАНСИ" caption. Drawn in code so it stays sharp at any size.
class PfLogo extends StatelessWidget {
  const PfLogo({super.key, this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) {
    final h = size * 1.15;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'PFinance · Персональні фінанси',
      child: CustomPaint(size: Size(h * _PfLogoPainter.w / _PfLogoPainter.h, h), painter: _PfLogoPainter(dark)),
    );
  }
}

class _PfLogoPainter extends CustomPainter {
  _PfLogoPainter(this.dark);
  final bool dark;

  // Design space in pixels of the reference logo (153×68 image, trimmed):
  // dot grid 0…54 × 0…54, "P" 65…100, "F" 110…139, letters 0…42 high,
  // caption 66…139 on 49…54, bottom-aligned with the last dot row.
  static const double w = 140, h = 54;
  static const _rows = [Color(0xFF8765FF), Color(0xFF5499FF), Color(0xFF23C8F9), Color(0xFF1DEBDA)];

  // Glyph outlines of "P" and "F" from the Anurati font (1000 units/em, cap
  // height 800, y up).
  static final _p = _svg('M588 722C536 774 473 800 400 800H0L133 666H400C436 666 467 653 493 627C520 601 533 569 533 533C533 496 519 465 493 439C467 413 436 400 400 400H133H0V0H133V266H400C473 266 536 292 588 344C641 396 666 460 666 533C666 606 640 669 588 722Z');
  static final _f = _svg('M0 401V0H133V266H533V401H133ZM0 800L133 666H533V800Z');

  static Path _svg(String d) {
    final t = RegExp(r'[MLHVCZ]|-?\d+(?:\.\d+)?').allMatches(d).map((m) => m.group(0)!).toList();
    final path = Path();
    var i = 0, x = 0.0, y = 0.0;
    String cmd = 'M';
    double n() => double.parse(t[i++]);
    while (i < t.length) {
      if (RegExp(r'[A-Z]').hasMatch(t[i])) cmd = t[i++];
      switch (cmd) {
        case 'M':
          x = n(); y = n(); path.moveTo(x, y); cmd = 'L';
        case 'L':
          x = n(); y = n(); path.lineTo(x, y);
        case 'H':
          x = n(); path.lineTo(x, y);
        case 'V':
          y = n(); path.lineTo(x, y);
        case 'C':
          final a = n(), b = n(), c = n(), e = n();
          x = n(); y = n();
          path.cubicTo(a, b, c, e, x, y);
        case 'Z':
          path.close();
      }
    }
    return path;
  }

  void _glyph(Canvas canvas, Path g, double left, Paint paint) {
    canvas.save();
    canvas.translate(left, 42);
    canvas.scale(42 / 800, -42 / 800);
    canvas.drawPath(g, paint);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / w, size.height / h);
    final dim = dark ? const Color(0x2EFFFFFF) : const Color(0x26000000);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        final lit = c >= 3 - r;
        canvas.drawCircle(Offset(4.5 + c * 15.0, 4.5 + r * 15.0), 4.5, Paint()..color = lit ? _rows[r] : dim);
      }
    }
    final ink = dark ? const Color(0xFFDDDEE2) : const Color(0xFF1E2230);
    final paint = Paint()..color = ink;
    _glyph(canvas, _p, 65, paint);
    _glyph(canvas, _f, 110, paint);
    final tp = TextPainter(
      text: TextSpan(
        text: 'ПЕРСОНАЛЬНІ ФІНАНСИ',
        style: TextStyle(fontSize: 10, height: 1, fontWeight: FontWeight.w700, color: ink.withValues(alpha: 0.85)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final m = tp.computeLineMetrics().first;
    // Cap height of Outfit ≈ 0.7 em: scale so caps are 5 px and the line spans 66…139.
    canvas.save();
    canvas.translate(66, 54);
    canvas.scale(73 / tp.width, 5 / 7);
    tp.paint(canvas, Offset(0, -m.baseline));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PfLogoPainter o) => o.dark != dark;
}
