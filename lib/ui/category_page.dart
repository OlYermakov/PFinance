// Category detail from Stats (MM: tap a category in the pie list): monthly
// line chart, month switcher, sub-categories and the records grouped by day.

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../state/app_store.dart';
import 'accounts_page.dart' show TrendLine, groupOf, openStatement;
import 'format.dart';
import 'glass.dart';
import 'stats_page.dart' show CategoryRow, Slice, rankColor, sliceKey, slicesFor;
import 'transactions_page.dart' show DayCard;
import '../l10n/l10n.dart';

class CategoryStatsPage extends StatefulWidget {
  const CategoryStatsPage({super.key, required this.category, required this.type, required this.month, this.backLabel, this.color, this.year = false});

  final Category category;
  final TxType type;
  final DateTime month; // accounting month (first day)
  final String? backLabel;
  final Color? color; // the slice colour it was opened from

  /// MM «Р» mode: periods are years, the chart shows years.
  final bool year;

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
    final r = widget.year ? store.yearRange(m.year) : store.periodRange(m);
    return store.txns.where((t) => !t.date.isBefore(r.start) && t.date.isBefore(r.end) && _matches(store, t)).toList();
  }

  void _go(int d) => setState(() {
    _month = widget.year ? DateTime(_month.year + d, _month.month) : DateTime(_month.year, _month.month + d);
    _shift = 0;
  });

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final c = widget.category;
    final color = widget.color ?? rankColor(0);
    final cur = store.baseCurrency;
    final txns = _inMonth(store, _month);

    // Chart: 4 months before the selected one and 2 after (like MM).
    final months = [
      for (var i = -4; i <= 2; i++) widget.year ? DateTime(_month.year + i + _shift, _month.month) : DateTime(_month.year, _month.month + i + _shift),
    ];
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
          label: Text(widget.backLabel ?? tr('Назад'), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
          style: TextButton.styleFrom(foregroundColor: scheme.onSurface, alignment: Alignment.centerLeft),
        ),
        title: Text(c.name),
        centerTitle: true,
      ),
      // MM: the month and the chart stay put; the list below scrolls.
      body: Column(
        children: [
          Container(
            color: panelColor(context),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _go(-1)),
                Expanded(
                  child: Text(
                    widget.year ? '${_month.year}' : monthTitle(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _go(1)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: GlassCard(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: TrendLine(
                labels: [for (final m in months) widget.year ? '${m.year}' : monthTitle(m).substring(0, 3)],
                values: values,
                selected: months.indexWhere((m) => m.year == _month.year && m.month == _month.month),
                currency: cur,
                color: color,
                onTap: (i) => setState(() {
                  _month = months[i];
                  _shift = 0;
                }),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
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
                            fallbackName: tr('Без підкатегорії'),
                            onTap: s.category == null
                                ? null
                                : isGroup
                                ? () => openStatement(context, store.account(s.category!.id)!)
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => CategoryStatsPage(
                                        category: s.category!,
                                        type: widget.type,
                                        month: _month,
                                        backLabel: c.name,
                                        color: rankColor(i),
                                        year: widget.year,
                                      ),
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
                      widget.year ? tr('Записів за цей рік немає') : tr('Записів за цей місяць немає'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                // MM: a year with sub-categories shows just them, no records.
                if (!isGroup && !(widget.year && subs.isNotEmpty))
                  for (final e in days.entries)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: DayCard(day: e.key, txns: e.value),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
