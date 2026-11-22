// Category detail from Stats (MM: tap a category in the pie list): monthly
// line chart, month switcher, sub-categories and the records grouped by day.

import 'dart:math' as math;

import 'package:intl/intl.dart' show NumberFormat;
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../state/app_store.dart';
import 'accounts_page.dart' show groupOf, openStatement;
import 'format.dart';
import 'glass.dart';
import 'stats_page.dart' show CategoryRow, Slice, sliceKey, slicesFor;
import 'transactions_page.dart' show DayCard;

class CategoryStatsPage extends StatefulWidget {
  const CategoryStatsPage({super.key, required this.category, required this.type, required this.month, this.backLabel});

  final Category category;
  final TxType type;
  final DateTime month; // accounting month (first day)
  final String? backLabel;

  @override
  State<CategoryStatsPage> createState() => _CategoryStatsPageState();
}

class _CategoryStatsPageState extends State<CategoryStatsPage> {
  late DateTime _month = DateTime(widget.month.year, widget.month.month);
  int _shift = 0; // chart window offset in months

  bool _matches(AppStore store, Txn t) {
    if (store.flowOf(t) != widget.type) return false;
    final c = widget.category;
    return c.parentId == null ? sliceKey(store, t) == c.id : t.categoryId == c.id;
  }

  List<Txn> _inMonth(AppStore store, DateTime m) {
    final r = store.periodRange(m);
    return store.txns.where((t) => !t.date.isBefore(r.start) && t.date.isBefore(r.end) && _matches(store, t)).toList();
  }

  void _go(int d) => setState(() {
    _month = DateTime(_month.year, _month.month + d);
    _shift = 0;
  });

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final c = widget.category;
    final color = Color(c.color);
    final cur = store.baseCurrency;
    final txns = _inMonth(store, _month);

    // Chart: 4 months before the selected one and 2 after (like MM).
    final months = [for (var i = -4; i <= 2; i++) DateTime(_month.year, _month.month + i + _shift)];
    final values = [for (final m in months) _inMonth(store, m).fold<int>(0, (s, t) => s + store.baseAmount(t))];

    // A transfer-expense group (MM): its accounts instead of sub-categories.
    final isGroup = c.id.startsWith('grp:');
    final groupAccounts = isGroup
        ? store.accounts.where((a) => store.prefs.transferExpense.contains(a.id) && groupOf(a) == c.name).toList()
        : const <Account>[];
    final List<Slice> subs = isGroup
        ? ([
            for (final a in groupAccounts)
              Slice(
                Category(id: a.id, name: a.name, type: widget.type, color: a.color),
                txns.where((t) => (widget.type == TxType.expense ? t.toAccountId : t.accountId) == a.id).fold<int>(0, (s, t) => s + store.baseAmount(t)),
              ),
          ]..sort((x, y) => y.amount.compareTo(x.amount)))
        : c.parentId == null && store.subcategoriesOf(c.id).isNotEmpty
        ? slicesFor(store, txns, parent: c.id)
        : const <Slice>[];
    final subTotal = subs.fold<int>(0, (s, x) => s + x.amount);

    final days = <DateTime, List<Txn>>{};
    for (final t in txns) {
      days.putIfAbsent(DateTime(t.date.year, t.date.month, t.date.day), () => []).add(t);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111318) : const Color(0xFFF2F3F7),
      appBar: AppBar(
        leadingWidth: 140,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
          label: Text(widget.backLabel ?? 'Назад', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
          style: TextButton.styleFrom(foregroundColor: scheme.onSurface, alignment: Alignment.centerLeft),
        ),
        title: Text(c.name),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Container(
            color: panelColor(context),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _go(-1)),
                Expanded(
                  child: Text(
                    monthTitle(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _go(1)),
              ],
            ),
          ),
          Container(
            color: panelColor(context),
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Stack(
              children: [
                _LineChart(
                  months: months,
                  values: values,
                  selected: months.indexWhere((m) => m.year == _month.year && m.month == _month.month),
                  color: color,
                  onTap: (i) => setState(() {
                    _month = months[i];
                    _shift = 0;
                  }),
                ),
                Positioned(
                  right: 4,
                  top: 50,
                  child: Column(
                    children: [
                      _RoundBtn(icon: Icons.keyboard_double_arrow_right_rounded, onTap: () => setState(() => _shift += 3)),
                      const SizedBox(height: 6),
                      _RoundBtn(icon: Icons.keyboard_double_arrow_left_rounded, onTap: () => setState(() => _shift -= 3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (subs.isNotEmpty)
            Container(
              color: panelColor(context),
              margin: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  for (final (i, s) in subs.indexed)
                    CategoryRow(
                      slice: s,
                      total: subTotal,
                      currency: cur,
                      index: i,
                      fallbackName: 'Без підкатегорії',
                      color: isGroup ? null : color,
                      onTap: s.category == null
                          ? null
                          : isGroup
                          ? () => openStatement(context, store.account(s.category!.id)!)
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => CategoryStatsPage(category: s.category!, type: widget.type, month: _month, backLabel: c.name),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          if (days.isEmpty && !isGroup)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Записів за цей місяць немає',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          if (!isGroup)
            for (final e in days.entries)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: DayCard(day: e.key, txns: e.value),
              ),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.06),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}

/// MM-style monthly line: value labels above the points, selected month
/// highlighted, tap a month to open it.
class _LineChart extends StatelessWidget {
  const _LineChart({required this.months, required this.values, required this.selected, required this.color, required this.onTap});
  final List<DateTime> months;
  final List<int> values;
  final int selected;
  final Color color;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final step = (w - 56) / (months.length - 1); // room for the arrows on the right
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final i = ((d.localPosition.dx - 24) / step).round().clamp(0, months.length - 1);
            onTap(i);
          },
          child: Column(
            children: [
              SizedBox(
                height: 170,
                width: w,
                child: CustomPaint(
                  painter: _LinePainter(
                    values: values,
                    selected: selected,
                    color: color,
                    step: step,
                    text: scheme.onSurfaceVariant,
                    strong: scheme.onSurface,
                    grid: scheme.onSurface.withValues(alpha: 0.05),
                  ),
                ),
              ),
              SizedBox(
                height: 38,
                child: Stack(
                  children: [
                    for (final (i, m) in months.indexed)
                      Positioned(
                        left: 24 + step * i - 30,
                        width: 60,
                        child: Column(
                          children: [
                            Text(
                              monthTitle(m).substring(0, 3),
                              style: TextStyle(fontSize: 14, color: i == selected ? const Color(0xFFFF6B5E) : scheme.onSurfaceVariant),
                            ),
                            if (m.year != now.year && (i == 0 || m.month == 1))
                              Text('${m.year}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.selected,
    required this.color,
    required this.step,
    required this.text,
    required this.strong,
    required this.grid,
  });
  final List<int> values;
  final int selected;
  final Color color;
  final double step;
  final Color text, strong, grid;

  static final _nf = NumberFormat('#,##0.00', 'uk');

  @override
  void paint(Canvas canvas, Size size) {
    final g = Paint()..color = grid;
    for (var y = 0.0; y < size.height; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), g);
    }
    for (var x = 0.0; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), g);
    }
    final maxV = math.max(1, values.fold<int>(0, math.max));
    const top = 34.0, bottom = 12.0;
    final pts = [for (final (i, v) in values.indexed) Offset(24 + step * i, size.height - bottom - (size.height - top - bottom) * v / maxV)];
    final line = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(Path()..addPolygon(pts, false), line);
    for (final (i, p) in pts.indexed) {
      canvas.drawCircle(p, 7, Paint()..color = color);
      if (i == selected) canvas.drawCircle(p, 4, Paint()..color = Colors.white);
      final tp = TextPainter(
        text: TextSpan(
          text: _nf.format(values[i] / 100),
          style: TextStyle(fontSize: 12, color: i == selected ? strong : text, fontWeight: i == selected ? FontWeight.w600 : FontWeight.w400),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      var x = p.dx - tp.width / 2;
      x = x.clamp(0, size.width - tp.width);
      tp.paint(canvas, Offset(x, p.dy - 26));
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values || old.selected != selected || old.color != color || old.step != step;
}
