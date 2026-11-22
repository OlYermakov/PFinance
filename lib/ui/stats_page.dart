import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../state/app_store.dart';
import 'accounts_page.dart' show groupOf;
import 'category_page.dart';
import 'format.dart';
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
        final shift = store.prefs.weekStartsMonday ? (a.weekday - 1) : (a.weekday % 7);
        final start = DateTime(a.year, a.month, a.day - shift);
        return (start: start, end: DateTime(start.year, start.month, start.day + 7));
      case StatsMode.year:
        final s = store.prefs.monthStartDay;
        return (start: DateTime(a.year, 1, s), end: DateTime(a.year + 1, 1, s));
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final m in StatsMode.values)
            ListTile(
              title: Text(statsModeLabels[m]!.$1, style: TextStyle(color: m == _mode ? Theme.of(context).colorScheme.primary : null)),
              trailing: m == _mode ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () => Navigator.pop(context, m),
            ),
        ]),
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
      StatsTab.budget => _BudgetView(month: store.periodOf(_anchor), currency: cur),
      StatsTab.notes => _notesView(store, txns, cur),
    };

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Row(children: [
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _pickMode,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(statsModeLabels[_mode]!.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Icon(Icons.expand_more_rounded, size: 18),
                ]),
              ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
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
                        ? (store.prefs.monthStartDay == 1 ? monthTitle(store.periodOf(_anchor)) : '${shortDayMonth(r.start)} – ${shortDayMonth(r.end.subtract(const Duration(days: 1)))}')
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
          ]),
          const SizedBox(height: 4),
          Row(children: [
            for (final (t, label, v, col) in [
              (TxType.income, 'Доходи', totals.income, incColor),
              (TxType.expense, 'Витрати', totals.expense, p.expense),
            ])
              Expanded(
                child: InkWell(
                  onTap: _tab == StatsTab.budget ? null : () => setState(() => _type = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: (_tab == StatsTab.budget ? t == TxType.expense : _type == t) ? col : Colors.white.withValues(alpha: 0.10),
                          width: (_tab == StatsTab.budget ? t == TxType.expense : _type == t) ? 3 : 1,
                        ),
                      ),
                    ),
                    // MM: "Дохід € 1 790,32" in one line
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '$label  ', style: const TextStyle(fontWeight: FontWeight.w500)),
                          TextSpan(text: money(v, cur), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 16,
                          color: (_tab == StatsTab.budget ? t == TxType.expense : _type == t) ? null : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
          if (missingRates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Немає курсу для ${missingRates.join(', ')}: ці записи не враховано. Задай курс у «Більше → Додаткові валюти».',
                  style: TextStyle(color: p.expense, fontSize: 12)),
            ),
          const SizedBox(height: 14),
          AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey('$_tab$_mode'), child: body)),
        ],
      ),
    );
  }

  Widget _statsView(AppStore store, List<Txn> txns, String cur) {
    final slices = slicesFor(store, txns);
    final total = slices.fold<int>(0, (s, x) => s + x.amount);
    if (slices.isEmpty) return const EmptyState(icon: Icons.donut_large_outlined, text: 'Немає записів за цей період');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: LabeledPie(key: ValueKey('${_label(store)}$_type'), slices: slices, total: total),
      ),
      const SizedBox(height: 12),
      GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          for (final (i, s) in slices.indexed)
            CategoryRow(
              slice: s,
              total: total,
              currency: cur,
              index: i,
              onTap: s.category == null ? null : () => _openCategory(context, s.category!),
            ),
        ]),
      ),
    ]);
  }

  /// "Список": every record of the month, grouped by category, biggest first.
  Widget _listView(AppStore store, List<Txn> txns, String cur) {
    final slices = slicesFor(store, txns);
    if (slices.isEmpty) return const EmptyState(icon: Icons.list_alt_rounded, text: 'Немає записів за цей період');
    final total = slices.fold<int>(0, (s, x) => s + x.amount);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(children: [
      for (final (i, sl) in slices.indexed) ...[
        GlassCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            CategoryRow(slice: sl, total: total, currency: cur, index: i),
            for (final t in (txns.where((t) => sliceKey(store, t) == sl.category?.id).toList()
              ..sort((a, b) => b.date.compareTo(a.date)))) ...[
              Divider(height: 1, indent: 16, color: Colors.white.withValues(alpha: 0.06)),
              InkWell(
                onTap: () => openTxnEditor(context, existing: t),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(children: [
                    SizedBox(width: 56, child: Text('${t.date.day.toString().padLeft(2, '0')}.${t.date.month.toString().padLeft(2, '0')}', style: TextStyle(color: muted))),
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
                  ]),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 10),
      ],
    ]);
  }

  Widget _trend(AppStore store, String cur) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GlassCard(padding: const EdgeInsets.all(16), child: TrendChart(month: store.periodOf(_anchor), currency: cur)),
        const SizedBox(height: 10),
        Text('Доходи й витрати за останні 6 місяців.', style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
      ]);

  Widget _notesView(AppStore store, List<Txn> txns, String cur) {
    final groups = <String, ({int count, int sum, List<Txn> list})>{};
    for (final t in txns) {
      final k = t.note.trim();
      final g = groups[k] ?? (count: 0, sum: 0, list: <Txn>[]);
      groups[k] = (count: g.count + 1, sum: g.sum + store.baseAmount(t), list: [...g.list, t]);
    }
    final rows = groups.entries.toList()
      ..sort((a, b) => _notesByAmount ? b.value.sum.compareTo(a.value.sum) : (b.value.count != a.value.count ? b.value.count.compareTo(a.value.count) : b.value.sum.compareTo(a.value.sum)));
    if (rows.isEmpty) return const EmptyState(icon: Icons.notes_rounded, text: 'Немає записів за цей період');
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final accent = Theme.of(context).colorScheme.primary;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(children: [
            Expanded(child: Text('Нотатка', style: TextStyle(color: muted))),
            InkWell(
              onTap: () => setState(() => _notesByAmount = false),
              child: SizedBox(
                width: 64,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('К-сть', style: TextStyle(color: _notesByAmount ? muted : accent, fontWeight: FontWeight.w600)),
                  if (!_notesByAmount) Icon(Icons.arrow_downward_rounded, size: 14, color: accent),
                ]),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _notesByAmount = true),
              child: SizedBox(
                width: 110,
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('Сума', style: TextStyle(color: _notesByAmount ? accent : muted, fontWeight: FontWeight.w600)),
                  if (_notesByAmount) Icon(Icons.arrow_downward_rounded, size: 14, color: accent),
                ]),
              ),
            ),
          ]),
        ),
        for (final e in rows) ...[
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
          InkWell(
            onTap: () => _openNote(context, e.key, e.value.list),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(children: [
                Expanded(
                  child: Text(e.key.isEmpty ? 'Без нотатки' : e.key,
                      overflow: TextOverflow.ellipsis, style: TextStyle(color: e.key.isEmpty ? muted : null, fontSize: 15)),
                ),
                SizedBox(width: 64, child: Text('${e.value.count}', textAlign: TextAlign.center, style: TextStyle(color: muted))),
                SizedBox(
                  width: 110,
                  child: Text(money(e.value.sum, cur), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ]),
            ),
          ),
        ],
      ]),
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
        builder: (context, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(note.isEmpty ? 'Без нотатки' : note, style: Theme.of(context).textTheme.titleLarge),
          ),
          for (final t in list) TxnTile(txn: t),
        ]),
      ),
    );
  }

  void _openCategory(BuildContext context, Category c) {
    final store = StoreScope.read(context);
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => CategoryStatsPage(category: c, type: _type, month: store.periodOf(_anchor))),
    );
  }
}

class _PillTabs<T> extends StatelessWidget {
  const _PillTabs({required this.value, required this.items, required this.onChanged});
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final keys = items.keys.toList();
    final idx = keys.indexOf(value);
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / keys.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            left: w * idx,
            top: 0,
            bottom: 0,
            width: w,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: LinearGradient(colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, 0.6)!]),
              ),
            ),
          ),
          Row(children: [
            for (final k in keys)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(k),
                  child: Center(
                    child: Text(items[k]!,
                        style: TextStyle(
                          fontWeight: k == value ? FontWeight.w700 : FontWeight.w500,
                          color: k == value ? Colors.white : scheme.onSurfaceVariant,
                        )),
                  ),
                ),
              ),
          ]),
        ]);
      }),
    );
  }
}

/// Money Manager–style budget list: remaining amount on top, then one row per
/// budget with a bar, a "today" marker, spent and remaining.
class _BudgetView extends StatelessWidget {
  const _BudgetView({required this.month, required this.currency});
  final DateTime month;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final budgets = store.budgets.where((b) => b.currency == currency).toList()
      ..sort((a, b) => (a.categoryId == null ? 0 : 1).compareTo(b.categoryId == null ? 0 : 1));
    final r = store.periodRange(month);
    final txns = store.txns.where((t) => t.type == TxType.expense && !t.date.isBefore(r.start) && t.date.isBefore(r.end));
    int spentFor(String? catId) => txns
        .where((t) => catId == null || store.topCategory(t.categoryId)?.id == catId || t.categoryId == catId)
        .fold(0, (s, t) => s + store.baseAmount(t));
    final now = DateTime.now();
    final pace = now.isBefore(r.start)
        ? 0.0
        : now.isAfter(r.end)
            ? 1.0
            : now.difference(r.start).inHours / r.end.difference(r.start).inHours;
    final overall = budgets.where((b) => b.categoryId == null).firstOrNull;
    final limitTotal = overall?.amount ?? budgets.fold<int>(0, (s, b) => s + b.amount);
    final spentTotal = overall != null ? spentFor(null) : budgets.fold<int>(0, (s, b) => s + spentFor(b.categoryId));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Залишок (місяць)', style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            AnimatedMoney(limitTotal - spentTotal, currency,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: limitTotal - spentTotal < 0 ? AppPalette.of(context).expense : null)),
          ]),
        ),
        FilledButton.tonal(
          onPressed: () => editBudget(context, currency: currency),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Новий бюджет'), Icon(Icons.chevron_right_rounded, size: 18)]),
        ),
      ]),
      const SizedBox(height: 18),
      if (budgets.isEmpty)
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Text('Задай місячний ліміт на всі витрати або на категорію. Позначка «Сьогодні» показує, скільки мало б бути витрачено на цей день.',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        )
      else
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (final (i, b) in budgets.indexed) ...[
              if (i > 0) Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
              InkWell(
                onTap: () => editBudget(context, currency: currency, existing: b),
                child: _BudgetRow(
                  title: store.category(b.categoryId)?.name ?? 'Усі витрати',
                  limit: b.amount,
                  spent: spentFor(b.categoryId),
                  pace: pace,
                  currency: currency,
                  showToday: i == 0,
                  index: i,
                ),
              ),
            ],
          ]),
        ),
    ]);
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.title,
    required this.limit,
    required this.spent,
    required this.pace,
    required this.currency,
    required this.showToday,
    required this.index,
  });
  final String title;
  final int limit;
  final int spent;
  final double pace;
  final String currency;
  final bool showToday;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final over = spent > limit;
    final ratio = limit == 0 ? 0.0 : spent / limit;
    final barColor = over ? AppPalette.of(context).expense : scheme.primary;
    final muted = scheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, showToday ? 26 : 10, 16, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 118,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted)),
            const SizedBox(height: 4),
            Text(money(limit, currency), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LayoutBuilder(builder: (context, c) {
              final x = (c.maxWidth * pace).clamp(0.0, c.maxWidth - 2);
              return Stack(clipBehavior: Clip.none, children: [
                Container(height: 26, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(7))),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio.clamp(0, 1)),
                  duration: Duration(milliseconds: 700 + index * 60),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Container(
                    height: 26,
                    width: c.maxWidth * v,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      gradient: LinearGradient(colors: [barColor.withValues(alpha: 0.75), barColor]),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(child: Text('${(ratio * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white))),
                ),
                Positioned(left: x, top: -2, bottom: -2, child: Container(width: 2, color: Colors.white.withValues(alpha: 0.85))),
                if (showToday)
                  Positioned(
                    left: (x - 34).clamp(0.0, c.maxWidth - 70),
                    top: -26,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(10)),
                      child: const Text('Сьогодні', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ]);
            }),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text(money(spent, currency), style: TextStyle(color: barColor, fontWeight: FontWeight.w600))),
              Text(money(limit - spent, currency), style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Pie with outside labels and leader lines (as in Money Manager), drawn as a
/// thick ring in the PF style.
class LabeledPie extends StatelessWidget {
  const LabeledPie({super.key, required this.slices, required this.total});
  final List<Slice> slices;
  final int total;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Outfit', fontFamilyFallback: const ['Manrope']);
    final sub = style.copyWith(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        size: const Size.fromHeight(290),
        painter: _PiePainter(
          values: [for (final s in slices) s.amount / (total == 0 ? 1 : total)],
          colors: [for (final s in slices) Color(s.category?.color ?? 0xFF8E8E93)],
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
        canvas.drawArc(rect, start, sweep, false, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring + 8
          ..color = colors[i].withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        canvas.drawArc(rect, start, sweep, false, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring
          ..shader = SweepGradient(
            startAngle: start,
            endAngle: start + sweep + 0.0001,
            colors: [colors[i], Color.lerp(colors[i], Colors.white, 0.2)!],
          ).createShader(rect));
        // Thin separator between slices.
        if (values.length > 1) {
          final dir = Offset(math.cos(start), math.sin(start));
          canvas.drawLine(c + dir * (r - ring), c + dir * r, Paint()
            ..color = const Color(0xFF0B0C14)
            ..strokeWidth = 1.5);
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
        canvas.drawPath(Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy), paint);
        final maxW = size.width / 2 - r - 34;
        final name = TextPainter(text: TextSpan(text: names[l.i], style: style), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…')
          ..layout(maxWidth: maxW);
        final pct = TextPainter(text: TextSpan(text: '${(values[l.i] * 100).toStringAsFixed(1)} %', style: sub), textDirection: TextDirection.ltr)
          ..layout(maxWidth: maxW);
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
  const CategoryRow({super.key, required this.slice, required this.total, required this.currency, required this.index, this.onTap, this.fallbackName = 'Без категорії', this.color});
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
    final col = color ?? Color(c?.color ?? 0xFF8E8E93);
    final share = total == 0 ? 0.0 : slice.amount / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index.clamp(0, 10) * 60),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child)),
      child: ListTile(
        onTap: onTap,
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(color: col.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(8)),
          child: Text('${(share * 100).round()}%', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
        title: Row(children: [
          if (c != null && c.parentId == null && hasIcon(c.emoji)) ...[Text(c.emoji), const SizedBox(width: 6)],
          Expanded(child: Text(c?.name ?? fallbackName, overflow: TextOverflow.ellipsis)),
          Text(money(slice.amount, currency), style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

Future<void> editBudget(BuildContext context, {required String currency, Budget? existing}) async {
  final store = StoreScope.read(context);
  String? catId = existing?.categoryId;
  final ctrl = TextEditingController(text: existing == null ? '' : minorToInput(existing.amount, currency));
  final used = store.budgets.where((b) => b.currency == currency && b.id != existing?.id).map((b) => b.categoryId).toSet();
  final cats = store.categoriesOf(TxType.expense).where((c) => !used.contains(c.id)).toList();

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? 'Новий бюджет' : 'Бюджет'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
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
        ]),
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
              store.saveBudget(existing?.copyWith(amount: v) ?? Budget(categoryId: catId, amount: v, currency: currency));
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

    return Column(children: [
      SizedBox(
        height: 140,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final (i, d) in data.indexed)
            Expanded(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (!single || type == TxType.income) _Bar(value: d.inc / maxV, color: inc, delay: i, wide: single),
                if (!single) const SizedBox(width: 3),
                if (!single || type == TxType.expense) _Bar(value: d.exp / maxV, color: p.expense, delay: i, wide: single),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 6),
      Row(children: [
        for (final m in months) Expanded(child: Text(monthTitle(m).substring(0, 3), textAlign: TextAlign.center, style: label)),
      ]),
      if (!single) ...[
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.circle, size: 10, color: inc),
          const Text(' Доходи   '),
          Icon(Icons.circle, size: 10, color: p.expense),
          const Text(' Витрати'),
        ]),
      ],
    ]);
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
