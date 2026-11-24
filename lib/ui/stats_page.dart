import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../state/app_store.dart';
import 'accounts_page.dart' show groupOf;
import 'category_page.dart';
import 'format.dart';
import 'rose_chart.dart';
import 'more_page.dart' show budgetSettingsPage;
import 'edit_transaction.dart' show openTxnEditor;
import 'theme.dart';
import 'transactions_page.dart' show TxnTile;
import 'widgets.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class Slice {
  Slice(this.category, this.amount);
  final Category? category;
  final int amount;
}

/// The transfer-expense group a `grp:`/`acc:` budget key belongs to.
String? budgetGroupOf(AppStore store, String key) {
  if (key.startsWith('grp:')) return key.substring(4);
  if (!key.startsWith('acc:')) return null;
  final a = store.account(key.substring(4));
  return a == null ? null : groupOf(a);
}

/// Top-level slice key of a record: its top category, or for a transfer that
/// counts as income/expense (MM "Transfer-Expense") the group of the
/// transfer-expense account, as `grp:<group>`.
String? sliceKey(AppStore store, Txn t) {
  if (t.type != TxType.transfer) return store.topCategory(t.categoryId)?.id;
  final f = store.flowOf(t);
  if (f == null) return null;
  final a = store.account(f == TxType.expense ? t.toAccountId : t.accountId);
  return a == null ? null : 'grp:${groupOf(a)}';
}

const _groupColors = [0xFF8BD17C, 0xFF6EC6E8, 0xFFB39DDB, 0xFFF48FB1, 0xFFFFCC80];

/// MM-style colours by rank: the biggest slice is red, then orange, yellow,
/// green, teal, blue, violet, pink — a warm-to-cool scale, so the colour
/// itself tells how big a share is.
const rankPalette = [
  0xFFF0544F, // red
  0xFFF5813F, // orange
  0xFFF8AE3C, // amber
  0xFFF2D04B, // yellow
  0xFFB9D24A, // lime
  0xFF6CC35F, // green
  0xFF3FB89A, // teal
  0xFF3DA8D8, // sky
  0xFF4F7FDB, // blue
  0xFF7D66D6, // indigo
  0xFFA75CCB, // violet
  0xFFD95AA0, // pink
];

/// Colour of the slice at [rank] (0 = biggest); past the palette it's grey.
Color rankColor(int rank) => Color(rank < rankPalette.length ? rankPalette[rank] : 0xFF8E8E93);

/// The category (real, or a stand-in for an account group) behind a slice key.
Category? sliceCategory(AppStore store, String? key, TxType type) {
  if (key == null) return null;
  if (!key.startsWith('grp:')) return store.category(key);
  final name = key.substring(4);
  return Category(id: key, name: name, type: type, color: _groupColors[name.hashCode.abs() % _groupColors.length]);
}

/// Sums [txns] by top-level category (or by sub-category of [parent]).
List<Slice> slicesFor(AppStore store, Iterable<Txn> txns, {String? parent}) {
  final by = <String?, int>{};
  TxType type = TxType.expense;
  for (final t in txns) {
    final String? key;
    if (parent == null) {
      key = sliceKey(store, t);
      type = store.flowOf(t) ?? type;
    } else {
      if (store.topCategory(t.categoryId)?.id != parent) continue;
      key = t.categoryId == parent ? null : t.categoryId;
    }
    by[key] = (by[key] ?? 0) + store.baseAmount(t);
  }
  return [for (final e in by.entries) Slice(sliceCategory(store, e.key, type), e.value)]..sort((a, b) => b.amount.compareTo(a.amount));
}

enum StatsTab { stats, budget, notes }

enum StatsMode { week, month, year, custom, list, trend }

const statsModeLabels = {
  StatsMode.week: ('Тиждень', 'Т'),
  StatsMode.month: ('Місяць', 'М'),
  StatsMode.year: ('Рік', 'Р'),
  StatsMode.custom: ('Період', 'П'),
  StatsMode.list: ('Список', 'С'),
  StatsMode.trend: ('Тренд', 'Тр'),
};

class _StatsPageState extends State<StatsPage> {
  StatsTab _tab = StatsTab.stats;
  StatsMode _mode = StatsMode.month;
  late DateTime _anchor = DateTime.now();
  DateTimeRange? _custom;
  TxType _type = TxType.expense;
  bool _notesByAmount = false;

  ({DateTime start, DateTime end}) _range(AppStore store) {
    final a = _anchor;
    switch (_mode) {
      case StatsMode.week:
        final shift = (a.weekday - store.prefs.weekStart) % 7;
        final start = DateTime(a.year, a.month, a.day - shift);
        return (start: start, end: DateTime(start.year, start.month, start.day + 7));
      case StatsMode.year:
        return store.yearRange(a.year);
      case StatsMode.custom:
        final r = _custom ?? DateTimeRange(start: DateTime(a.year, a.month, 1), end: DateTime(a.year, a.month + 1, 0));
        return (start: r.start, end: DateTime(r.end.year, r.end.month, r.end.day + 1));
      case StatsMode.month:
      case StatsMode.list:
      case StatsMode.trend:
        return store.periodRange(store.periodOf(a));
    }
  }

  String _label(AppStore store) {
    final r = _range(store);
    final last = r.end.subtract(const Duration(days: 1));
    return switch (_mode) {
      StatsMode.week => '${shortDayMonth(r.start)} – ${shortDayMonth(last)}',
      StatsMode.year => '${_anchor.year}',
      StatsMode.custom => '${shortDate(r.start)} – ${shortDate(last)}',
      _ => store.prefs.monthStartDay == 1 ? monthTitle(store.periodOf(_anchor)) : '${shortDayMonth(r.start)} – ${shortDayMonth(last)}',
    };
  }

  void _step(int d) => setState(() {
    final a = _anchor;
    _anchor = switch (_mode) {
      StatsMode.week => DateTime(a.year, a.month, a.day + 7 * d),
      StatsMode.year => DateTime(a.year + d, a.month, a.day),
      _ => DateTime(a.year, a.month + d, a.day.clamp(1, 28)),
    };
  });

  Future<void> _pickMode() async {
    final v = await showModalBottomSheet<StatsMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in StatsMode.values)
              ListTile(
                title: Text(statsModeLabels[m]!.$1, style: TextStyle(color: m == _mode ? Theme.of(context).colorScheme.primary : null)),
                trailing: m == _mode ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () => Navigator.pop(context, m),
              ),
          ],
        ),
      ),
    );
    if (v == null || !mounted) return;
    if (v == StatsMode.custom) {
      final now = DateTime.now();
      final r = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: _custom ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      );
      if (r == null) return;
      _custom = r;
    }
    setState(() => _mode = v);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = AppPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final cur = store.baseCurrency;
    // Budgets are monthly, so the budget tab always shows a month.
    final r = _tab == StatsTab.budget ? store.periodRange(store.periodOf(_anchor)) : _range(store);
    final inRange = store.txns.where((t) => !t.date.isBefore(r.start) && t.date.isBefore(r.end)).toList();
    final totals = store.totalsBase(inRange);
    final txns = inRange.where((t) => store.flowOf(t) == _type).toList();
    final missingRates = {for (final t in txns) store.currencyOf(t)}.where((c) => !store.hasRate(c)).toList();
    final incColor = incomeColor(context, store);

    final Widget body = switch (_tab) {
      StatsTab.stats => switch (_mode) {
        StatsMode.trend => _trend(store, cur),
        StatsMode.list => _listView(store, txns, cur),
        _ => _statsView(store, txns, cur),
      },
      StatsTab.budget => _BudgetView(month: store.periodOf(_anchor), currency: cur, type: _type),
      StatsTab.notes => _notesView(store, txns, cur),
    };

    // MM: tabs, period and income/expense stay put; only the content scrolls.
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PillTabs<StatsTab>(
                        value: _tab,
                        items: const {StatsTab.stats: 'Статистика', StatsTab.budget: 'Бюджет', StatsTab.notes: 'Нотатки'},
                        onChanged: (t) => setState(() => _tab = t),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_tab != StatsTab.budget)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(56, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: _pickMode,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(statsModeLabels[_mode]!.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const Icon(Icons.expand_more_rounded, size: 18),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (_mode != StatsMode.custom || _tab == StatsTab.budget)
                      IconButton(tooltip: 'Попередній', icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _step(-1))
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: GestureDetector(
                        onTap: _mode == StatsMode.custom && _tab != StatsTab.budget ? _pickMode : null,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            _tab == StatsTab.budget
                                ? (store.prefs.monthStartDay == 1
                                      ? monthTitle(store.periodOf(_anchor))
                                      : '${shortDayMonth(r.start)} – ${shortDayMonth(r.end.subtract(const Duration(days: 1)))}')
                                : _label(store),
                            key: ValueKey('${_label(store)}$_tab'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    if (_mode != StatsMode.custom || _tab == StatsTab.budget)
                      IconButton(tooltip: 'Наступний', icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _step(1))
                    else
                      const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (final (t, label, v, col) in [
                      (TxType.income, 'Доходи', totals.income, incColor),
                      (TxType.expense, 'Витрати', totals.expense, p.expense),
                    ])
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _type = t),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: _type == t ? col : Colors.white.withValues(alpha: 0.10), width: _type == t ? 3 : 1),
                              ),
                            ),
                            // MM: "Дохід € 1 790,32" in one line
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '$label  ',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    TextSpan(
                                      text: money(v, cur),
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                style: TextStyle(fontSize: 16, color: _type == t ? null : scheme.onSurfaceVariant),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (missingRates.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Немає курсу для ${missingRates.join(', ')}: ці записи не враховано. Задай курс у «Більше → Додаткові валюти».',
                      style: TextStyle(color: p.expense, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(key: ValueKey('$_tab$_mode'), child: body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsView(AppStore store, List<Txn> txns, String cur) {
    final slices = slicesFor(store, txns);
    final total = slices.fold<int>(0, (s, x) => s + x.amount);
    if (slices.isEmpty) return const EmptyState(icon: Icons.donut_large_outlined, text: 'Немає записів за цей період');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(padding: const EdgeInsets.symmetric(vertical: 12), child: _rose(store, txns, slices, cur)),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final (i, s) in slices.indexed)
                CategoryRow(
                  slice: s,
                  total: total,
                  currency: cur,
                  index: i,
                  onTap: s.category == null ? null : () => _openCategory(context, s.category!, rankColor(i)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The rose with each petal split into parts of the period: weeks of a
  /// month (1–7, 8–14, 15–21, 22–end) or quarters of a longer period.
  Widget _rose(AppStore store, List<Txn> txns, List<Slice> slices, String cur) {
    final r = _range(store);
    final days = r.end.difference(r.start).inDays;
    final bounds = <DateTime>[];
    if (days <= 7) {
      bounds.add(r.start);
    } else if (days <= 31) {
      for (var d = 0; d + 7 <= days || bounds.isEmpty; d += 7) {
        if (bounds.length == 4) break;
        bounds.add(DateTime(r.start.year, r.start.month, r.start.day + d));
      }
    } else {
      for (var q = 0; q < 4; q++) {
        bounds.add(DateTime(r.start.year, r.start.month + q * 3, r.start.day));
      }
    }
    int partOf(DateTime d) {
      var k = 0;
      while (k + 1 < bounds.length && !d.isBefore(bounds[k + 1])) {
        k++;
      }
      return k;
    }

    const months = ['січ', 'лют', 'бер', 'кві', 'тра', 'чер', 'лип', 'сер', 'вер', 'жов', 'лис', 'гру'];
    final labels = [
      for (var k = 0; k < bounds.length; k++)
        () {
          final s = bounds[k];
          final e = (k + 1 < bounds.length ? bounds[k + 1] : r.end).subtract(const Duration(days: 1));
          return days > 31 ? '${months[s.month - 1]}–${months[e.month - 1]}' : '${s.day}–${e.day}';
        }(),
    ];
    final parts = [
      for (final sl in slices)
        () {
          final p = List<int>.filled(bounds.length, 0);
          for (final t in txns) {
            if (sliceKey(store, t) == sl.category?.id) p[partOf(t.date)] += store.baseAmount(t);
          }
          return p;
        }(),
    ];
    return RoseChart(
      key: ValueKey('${_label(store)}$_type'),
      names: [for (final s in slices) s.category?.name ?? 'Без категорії'],
      colors: [for (var i = 0; i < slices.length; i++) rankColor(i)],
      parts: parts,
      partLabels: bounds.length > 1 ? labels : const [],
      currency: cur,
      centerLabel: 'Разом',
    );
  }

  /// "Список": every record of the month, grouped by category, biggest first.
  Widget _listView(AppStore store, List<Txn> txns, String cur) {
    final slices = slicesFor(store, txns);
    if (slices.isEmpty) return const EmptyState(icon: Icons.list_alt_rounded, text: 'Немає записів за цей період');
    final total = slices.fold<int>(0, (s, x) => s + x.amount);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        for (final (i, sl) in slices.indexed) ...[
          GlassCard(
            radius: 20,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                CategoryRow(slice: sl, total: total, currency: cur, index: i),
                for (final t in (txns.where((t) => sliceKey(store, t) == sl.category?.id).toList()..sort((a, b) => b.date.compareTo(a.date)))) ...[
                  Divider(height: 1, indent: 16, color: Colors.white.withValues(alpha: 0.06)),
                  InkWell(
                    onTap: () => openTxnEditor(context, existing: t),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: Text('${t.date.day.toString().padLeft(2, '0')}.${t.date.month.toString().padLeft(2, '0')}', style: TextStyle(color: muted)),
                          ),
                          Expanded(
                            child: Text(
                              [
                                if (store.category(t.categoryId)?.parentId != null) store.category(t.categoryId)!.name,
                                if (t.note.isNotEmpty) t.note,
                              ].join(' · '),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(money(t.amount, store.currencyOf(t)), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _trend(AppStore store, String cur) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GlassCard(
        padding: const EdgeInsets.all(16),
        child: TrendChart(month: store.periodOf(_anchor), currency: cur),
      ),
      const SizedBox(height: 10),
      Text('Доходи й витрати за останні 6 місяців.', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
    ],
  );

  Widget _notesView(AppStore store, List<Txn> txns, String cur) {
    final groups = <String, ({int count, int sum, List<Txn> list})>{};
    for (final t in txns) {
      final k = t.note.trim();
      final g = groups[k] ?? (count: 0, sum: 0, list: <Txn>[]);
      groups[k] = (count: g.count + 1, sum: g.sum + store.baseAmount(t), list: [...g.list, t]);
    }
    final rows = groups.entries.toList()
      ..sort(
        (a, b) => _notesByAmount
            ? b.value.sum.compareTo(a.value.sum)
            : (b.value.count != a.value.count ? b.value.count.compareTo(a.value.count) : b.value.sum.compareTo(a.value.sum)),
      );
    if (rows.isEmpty) return const EmptyState(icon: Icons.notes_rounded, text: 'Немає записів за цей період');
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final accent = Theme.of(context).colorScheme.primary;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text('Нотатка', style: TextStyle(color: muted)),
                ),
                InkWell(
                  onTap: () => setState(() => _notesByAmount = false),
                  child: SizedBox(
                    width: 64,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'К-сть',
                          style: TextStyle(color: _notesByAmount ? muted : accent, fontWeight: FontWeight.w600),
                        ),
                        if (!_notesByAmount) Icon(Icons.arrow_downward_rounded, size: 14, color: accent),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _notesByAmount = true),
                  child: SizedBox(
                    width: 110,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Сума',
                          style: TextStyle(color: _notesByAmount ? accent : muted, fontWeight: FontWeight.w600),
                        ),
                        if (_notesByAmount) Icon(Icons.arrow_downward_rounded, size: 14, color: accent),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final e in rows) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
            InkWell(
              onTap: () => _openNote(context, e.key, e.value.list),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key.isEmpty ? 'Без нотатки' : e.key,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: e.key.isEmpty ? muted : null, fontSize: 15),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${e.value.count}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        money(e.value.sum, cur),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openNote(BuildContext context, String note, List<Txn> list) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(note.isEmpty ? 'Без нотатки' : note, style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final t in list) TxnTile(txn: t),
          ],
        ),
      ),
    );
  }

  void _openCategory(BuildContext context, Category c, Color color) {
    final store = StoreScope.read(context);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CategoryStatsPage(category: c, type: _type, month: store.periodOf(_anchor), color: color, year: _mode == StatsMode.year),
      ),
    );
  }
}

class _PillTabs<T> extends StatelessWidget {
  const _PillTabs({required this.value, required this.items, required this.onChanged});
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => PillTabs<T>(value: value, items: items, onChanged: onChanged);
}

/// Budget rows of a month (top-level categories in their order, then
/// transfer-expense groups) and the month's total limit and spending. The
/// Budget tab and the Summary both use this, so their totals always agree.
({List<Budget> rows, int limitTotal, int spentTotal, int Function(String key) spentFor}) budgetTotals(
  AppStore store,
  DateTime month,
  String currency,
  TxType type,
) {
  final r = store.periodRange(month);
  final txns = store.txns.where((t) => !t.date.isBefore(r.start) && t.date.isBefore(r.end) && store.flowOf(t) == type).toList();
  int spentFor(String key) => txns
      .where((t) => key.startsWith('grp:') ? sliceKey(store, t) == key : (t.categoryId == key || store.topCategory(t.categoryId)?.id == key))
      .fold(0, (s, t) => s + store.baseAmount(t));

  // Top-level categories in their own order, then transfer-expense groups.
  // MM budgets a transfer-expense account (`acc:<id>`) or its whole group
  // (`grp:<group>`); the Budget tab shows one row per group with their sum.
  final order = {for (final (i, c) in store.categoriesOf(type).indexed) c.id: i};
  // Amounts as they stand in this month (MM: budgets can differ by month); a
  // category with no budget of its own shows the sum of its subcategories'.
  final all = [for (final b in store.budgets.where((b) => b.currency == currency)) b.atMonth(month)];
  final mine = <Budget>[
    for (final b in all)
      if (b.categoryId != null && b.amount > 0 && store.category(b.categoryId)?.parentId == null) b,
  ];
  for (final c in store.categoriesOf(type)) {
    if (mine.any((b) => b.categoryId == c.id)) continue;
    final subs = {for (final x in store.subcategoriesOf(c.id)) x.id};
    final sum = all.where((b) => subs.contains(b.categoryId)).fold<int>(0, (a, b) => a + b.amount);
    if (sum > 0) mine.add(Budget(id: 'sub:${c.id}', categoryId: c.id, amount: sum, currency: currency));
  }
  final groupSums = <String, int>{};
  if (type == TxType.expense) {
    for (final b in mine) {
      final g = budgetGroupOf(store, b.categoryId!);
      if (g != null) groupSums['grp:$g'] = (groupSums['grp:$g'] ?? 0) + b.amount;
    }
  }
  final rows = [
    ...mine.where((b) => order.containsKey(b.categoryId)).toList()..sort((a, b) => order[a.categoryId]!.compareTo(order[b.categoryId]!)),
    for (final e in groupSums.entries) Budget(id: e.key, categoryId: e.key, amount: e.value, currency: currency),
  ];
  final overall = type == TxType.expense ? all.where((b) => b.categoryId == null && b.amount > 0).firstOrNull : null;
  final limitTotal = overall?.amount ?? rows.fold<int>(0, (s, b) => s + b.amount);
  final spentTotal = overall != null ? txns.fold<int>(0, (s, t) => s + store.baseAmount(t)) : rows.fold<int>(0, (s, b) => s + spentFor(b.categoryId!));

  return (rows: rows, limitTotal: limitTotal, spentTotal: spentTotal, spentFor: spentFor);
}

/// Money Manager–style budget list: what is left this month on top, the
/// month's total budget with a "today" marker, then one row per budgeted
/// top-level category (or transfer-expense group) of the selected type.
class _BudgetView extends StatelessWidget {
  const _BudgetView({required this.month, required this.currency, required this.type});
  final DateTime month;
  final String currency;
  final TxType type;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final r = store.periodRange(month);
    final (:rows, :limitTotal, :spentTotal, :spentFor) = budgetTotals(store, month, currency, type);

    final now = DateTime.now();
    final pace = now.isBefore(r.start)
        ? 0.0
        : now.isAfter(r.end)
        ? 1.0
        : now.difference(r.start).inMinutes / r.end.difference(r.start).inMinutes;
    const kind = 'Місяць';
    String nameOf(String id) => id.startsWith('grp:') ? id.substring(4) : store.category(id)?.name ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 0, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type == TxType.expense ? 'Залишилось ($kind)' : 'Ще очікується', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                    const SizedBox(height: 6),
                    AnimatedMoney(limitTotal - spentTotal, currency, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Material(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => budgetSettingsPage(type))),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 6, 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Налашт. бюджету', style: TextStyle(fontSize: 14)),
                        Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (rows.isEmpty && limitTotal == 0)
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Бюджетів ще немає. Задай місячний ліміт для категорій у «Налашт. бюджету». Позначка «Сьогодні» показує, скільки мало б бути витрачено на цей день.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          )
        else ...[
          GlassCard(
            padding: EdgeInsets.zero,
            child: BudgetRow(
              title: 'Бюджет ($kind)',
              limit: limitTotal,
              spent: spentTotal,
              pace: pace,
              currency: currency,
              showToday: true,
              index: 0,
              overIsBad: type == TxType.expense,
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isNotEmpty)
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, b) in rows.indexed) ...[
                    if (i > 0) Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => budgetSettingsPage(type))),
                      child: BudgetRow(
                        title: nameOf(b.categoryId!),
                        limit: b.amount,
                        spent: spentFor(b.categoryId!),
                        pace: pace,
                        currency: currency,
                        showToday: false,
                        index: i + 1,
                        overIsBad: type == TxType.expense,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// One budget line (MM): name and limit on the left; a bar with the
/// percentage, an optional «Сьогодні» marker, spent and left underneath.
/// Used by the Budget tab and the Summary so they look the same.
class BudgetRow extends StatelessWidget {
  const BudgetRow({
    super.key,
    required this.title,
    required this.limit,
    required this.spent,
    required this.pace,
    required this.currency,
    required this.showToday,
    required this.index,
    this.overIsBad = true,
  });
  final bool overIsBad; // income above its budget is good news
  final String title;
  final int limit;
  final int spent;
  final double pace;
  final String currency;
  final bool showToday;
  final int index;

  static const _blue = Color(0xFF55A6F7);
  static const _over = Color(0xFFF47A6C);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final over = spent > limit;
    final ratio = limit == 0 ? (spent > 0 ? 1.0 : 0.0) : spent / limit;
    final barColor = over && overIsBad ? _over : _blue;
    final panel = panelColor(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, showToday ? 30 : 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(money(limit, currency), style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final x = (c.maxWidth * pace).clamp(0.0, c.maxWidth - 1);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 22,
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(4)),
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: ratio.clamp(0, 1)),
                          duration: Duration(milliseconds: 600 + index.clamp(0, 10) * 50),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => Container(
                            height: 22,
                            width: c.maxWidth * v,
                            decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        Positioned(
                          left: x,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 1.5, color: panel),
                        ),
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Text('${(ratio * 100).round()}%', style: const TextStyle(fontSize: 14, color: Colors.white)),
                          ),
                        ),
                        if (showToday)
                          Positioned(
                            left: (x - 36).clamp(0.0, c.maxWidth - 72),
                            top: -27,
                            width: 72,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFF55585F), borderRadius: BorderRadius.circular(10)),
                                  child: const Text('Сьогодні', style: TextStyle(fontSize: 11, color: Colors.white)),
                                ),
                                CustomPaint(size: const Size(8, 4), painter: _Notch(const Color(0xFF55585F))),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(formatPlainMoney(spent, currency), style: TextStyle(color: barColor, fontSize: 15)),
                    ),
                    Text(formatPlainMoney(limit - spent, currency), style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notch extends CustomPainter {
  _Notch(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close(),
    Paint()..color = color,
  );
  @override
  bool shouldRepaint(_Notch old) => old.color != color;
}

/// Pie with outside labels and leader lines (as in Money Manager), drawn as a
/// thick ring in the PF style.
class LabeledPie extends StatelessWidget {
  const LabeledPie({super.key, required this.slices, required this.total});
  final List<Slice> slices;
  final int total;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
      fontFamily: 'Outfit',
      fontFamilyFallback: const ['Manrope'],
    );
    final sub = style.copyWith(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        size: const Size.fromHeight(290),
        painter: _PiePainter(
          values: [for (final s in slices) s.amount / (total == 0 ? 1 : total)],
          colors: [for (var i = 0; i < slices.length; i++) rankColor(i)],
          names: [for (final s in slices) s.category?.name ?? 'Без категорії'],
          progress: t,
          style: style,
          sub: sub,
        ),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.values, required this.colors, required this.names, required this.progress, required this.style, required this.sub});
  final List<double> values;
  final List<Color> colors;
  final List<String> names;
  final double progress;
  final TextStyle style;
  final TextStyle sub;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.height / 2 - 30, size.width / 2 - 92).clamp(60.0, 115.0);
    const ring = 34.0;
    final rect = Rect.fromCircle(center: c, radius: r - ring / 2);
    var start = -math.pi / 2;
    final labels = <({double mid, int i})>[];
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] * math.pi * 2 * progress;
      if (sweep > 0.004) {
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = ring + 8
            ..color = colors[i].withValues(alpha: 0.18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = ring
            ..shader = SweepGradient(
              startAngle: start,
              endAngle: start + sweep + 0.0001,
              colors: [colors[i], Color.lerp(colors[i], Colors.white, 0.2)!],
            ).createShader(rect),
        );
        // Thin separator between slices.
        if (values.length > 1) {
          final dir = Offset(math.cos(start), math.sin(start));
          canvas.drawLine(
            c + dir * (r - ring),
            c + dir * r,
            Paint()
              ..color = const Color(0xFF0B0C14)
              ..strokeWidth = 1.5,
          );
        }
      }
      if (values[i] >= 0.008) labels.add((mid: start + sweep / 2, i: i));
      start += sweep;
    }
    if (progress < 0.98) return;

    // Outside labels, pushed apart vertically on each side so they never overlap.
    const minGap = 30.0;
    for (final side in [1, -1]) {
      final items = [
        for (final l in labels)
          if ((math.cos(l.mid) >= 0 ? 1 : -1) == side) (l: l, y: c.dy + math.sin(l.mid) * (r + 18)),
      ]..sort((a, b) => a.y.compareTo(b.y));
      final ys = [for (final it in items) it.y];
      for (var k = 1; k < ys.length; k++) {
        if (ys[k] - ys[k - 1] < minGap) ys[k] = ys[k - 1] + minGap;
      }
      final overflow = ys.isEmpty ? 0.0 : ys.last - (size.height - 14);
      if (overflow > 0) {
        for (var k = ys.length - 1; k >= 0; k--) {
          ys[k] -= overflow;
          if (k > 0 && ys[k] - ys[k - 1] >= minGap) break;
        }
        for (var k = ys.length - 2; k >= 0; k--) {
          if (ys[k + 1] - ys[k] < minGap) ys[k] = ys[k + 1] - minGap;
        }
      }
      for (var k = 0; k < items.length; k++) {
        final l = items[k].l;
        final dir = Offset(math.cos(l.mid), math.sin(l.mid));
        final p0 = c + dir * (r + 2);
        final p1 = c + dir * (r + 14);
        final p2 = Offset(c.dx + side * (r + 28), ys[k]);
        final paint = Paint()
          ..color = colors[l.i].withValues(alpha: 0.9)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawPath(
          Path()
            ..moveTo(p0.dx, p0.dy)
            ..lineTo(p1.dx, p1.dy)
            ..lineTo(p2.dx, p2.dy),
          paint,
        );
        final maxW = size.width / 2 - r - 34;
        final name = TextPainter(
          text: TextSpan(text: names[l.i], style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: maxW);
        final pct = TextPainter(
          text: TextSpan(text: '${(values[l.i] * 100).toStringAsFixed(1)} %', style: sub),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxW);
        final x = side == 1 ? p2.dx + 4 : p2.dx - 4 - math.max(name.width, pct.width);
        name.paint(canvas, Offset(side == 1 ? x : p2.dx - 4 - name.width, p2.dy - name.height));
        pct.paint(canvas, Offset(side == 1 ? x : p2.dx - 4 - pct.width, p2.dy));
      }
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) => old.progress != progress || old.values != values;
}

class CategoryRow extends StatelessWidget {
  const CategoryRow({
    super.key,
    required this.slice,
    required this.total,
    required this.currency,
    required this.index,
    this.onTap,
    this.fallbackName = 'Без категорії',
    this.color,
  });
  final Slice slice;
  final int total;
  final String currency;
  final int index;
  final VoidCallback? onTap;
  final String fallbackName;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = slice.category;
    final col = color ?? rankColor(index);
    final share = total == 0 ? 0.0 : slice.amount / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index.clamp(0, 10) * 60),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: ListTile(
        onTap: onTap,
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(color: col.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(8)),
          child: Text(
            '${(share * 100).toStringAsFixed(1).replaceAll('.', ',')}%',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
        title: Row(
          children: [
            if (c != null && c.parentId == null && hasIcon(c.emoji)) ...[Text(c.emoji), const SizedBox(width: 6)],
            Expanded(child: Text(c?.name ?? fallbackName, overflow: TextOverflow.ellipsis)),
            Text(money(slice.amount, currency), style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

Future<void> editBudget(BuildContext context, {required String currency, Budget? existing}) async {
  final store = StoreScope.read(context);
  String? catId = existing?.categoryId;
  final ctrl = TextEditingController(text: existing == null ? '' : minorToInput(existing.amountAt(store.currentPeriod), currency));
  final used = store.budgets.where((b) => b.currency == currency && b.id != existing?.id).map((b) => b.categoryId).toSet();
  final cats = store.categoriesOf(TxType.expense).where((c) => !used.contains(c.id)).toList();

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? 'Новий бюджет' : 'Бюджет'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String?>(
              initialValue: catId,
              decoration: const InputDecoration(labelText: 'Категорія'),
              items: [
                if (!used.contains(null) || existing?.categoryId == null) const DropdownMenuItem(value: null, child: Text('🎯 Усі витрати')),
                for (final c in cats) DropdownMenuItem(value: c.id, child: Text('${iconPrefix(c.emoji)}${c.name}')),
              ],
              onChanged: existing != null ? null : (v) => setState(() => catId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Ліміт на місяць', suffixText: currency),
            ),
          ],
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () {
                store.saveBudget(existing.copyWith(deleted: true));
                Navigator.pop(context);
              },
              child: const Text('Видалити'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
          FilledButton(
            onPressed: () {
              final v = parseMoney(ctrl.text, currency);
              if (v == null || v == 0) return;
              store.saveBudget(existing?.withDefault(v, store.currentPeriod) ?? Budget(categoryId: catId, amount: v, currency: currency));
              Navigator.pop(context);
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    ),
  );
}

class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.month, required this.currency, this.categoryId, this.type});
  final DateTime month;
  final String currency;
  final String? categoryId;
  final TxType? type;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = AppPalette.of(context);
    final inc = incomeColor(context, store);
    final months = [for (var i = 5; i >= 0; i--) DateTime(month.year, month.month - i)];
    final data = [
      for (final m in months)
        () {
          var list = store.txnsInPeriod(m);
          if (categoryId != null) list = list.where((t) => store.topCategory(t.categoryId)?.id == categoryId).toList();
          final t = store.totalsBase(list);
          return (inc: t.income, exp: t.expense);
        }(),
    ];
    final single = categoryId != null;
    final maxV = data.fold<int>(1, (m, d) => math.max(m, single ? (type == TxType.income ? d.inc : d.exp) : math.max(d.inc, d.exp)));
    final label = Theme.of(context).textTheme.labelSmall;

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, d) in data.indexed)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!single || type == TxType.income) _Bar(value: d.inc / maxV, color: inc, delay: i, wide: single),
                      if (!single) const SizedBox(width: 3),
                      if (!single || type == TxType.expense) _Bar(value: d.exp / maxV, color: p.expense, delay: i, wide: single),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final m in months)
              Expanded(
                child: Text(monthTitle(m).substring(0, 3), textAlign: TextAlign.center, style: label),
              ),
          ],
        ),
        if (!single) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, size: 10, color: inc),
              const Text(' Доходи   '),
              Icon(Icons.circle, size: 10, color: p.expense),
              const Text(' Витрати'),
            ],
          ),
        ],
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color, required this.delay, this.wide = false});
  final double value;
  final Color color;
  final int delay;
  final bool wide;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value),
    duration: Duration(milliseconds: 600 + delay * 80),
    curve: Curves.easeOutBack,
    builder: (context, v, _) => Container(
      width: wide ? 22 : 12,
      height: math.max(3, 130 * v.clamp(0, 1.1)),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [color.withValues(alpha: 0.55), color]),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8)],
      ),
    ),
  );
}
