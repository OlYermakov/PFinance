import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../state/app_store.dart';
import 'edit_transaction.dart';
import 'export_pf.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets.dart';

enum RecordsView { day, calendar, month, summary }

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key, this.initialView = RecordsView.day});
  final RecordsView initialView;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late DateTime _month = StoreScope.read(context).currentPeriod;
  late RecordsView _view = widget.initialView;
  String _query = '';
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    var list = store.txnsInPeriod(_month);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((t) {
        return t.note.toLowerCase().contains(q) ||
            txnTitle(store, t).toLowerCase().contains(q) ||
            (store.account(t.accountId)?.name.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    final tot = store.totalsBase(list);
    final cur = store.baseCurrency;

    final Widget content = switch (_view) {
      RecordsView.day => _DayView(txns: list),
      RecordsView.calendar => _CalendarView(month: _month, txns: list),
      RecordsView.month => _WeeksView(month: _month, txns: list),
      RecordsView.summary => _SummaryView(month: _month, txns: list),
    };

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 0),
              child: Row(children: [
                const Spacer(),
                IconButton(
                  tooltip: 'Пошук',
                  icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
                  onPressed: () => setState(() {
                    _searching = !_searching;
                    _query = '';
                  }),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: _searching
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: TextField(
                        autofocus: true,
                        decoration: const InputDecoration(hintText: 'Нотатка, категорія або рахунок', prefixIcon: Icon(Icons.search_rounded)),
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(child: MonthSwitcher(month: _month, onChanged: (m) => setState(() => _month = m))),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _ViewTabs(value: _view, onChanged: (v) => setState(() => _view = v)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TotalsStrip(
                income: tot.income,
                expense: tot.expense,
                currency: cur,
                carry: store.prefs.carryOver && _query.isEmpty ? store.carryBefore(store.periodRange(_month).start) : null,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
              child: KeyedSubtree(key: ValueKey('$_view$_month'), child: content),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

/// Pill tabs: День · Календар · Місяць · Підсумок.
class _ViewTabs extends StatelessWidget {
  const _ViewTabs({required this.value, required this.onChanged});
  final RecordsView value;
  final ValueChanged<RecordsView> onChanged;

  static const _labels = {
    RecordsView.day: 'День',
    RecordsView.calendar: 'Календар',
    RecordsView.month: 'Місяць',
    RecordsView.summary: 'Підсумок',
  };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final idx = RecordsView.values.indexOf(value);
    return GlassCard(
      radius: 999,
      blur: 16,
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / 4;
        return SizedBox(
          height: 36,
          child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              left: idx * w,
              top: 0,
              bottom: 0,
              width: w,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(colors: [p.gradient.first.withValues(alpha: 0.85), p.gradient.last.withValues(alpha: 0.85)]),
                  boxShadow: [BoxShadow(color: p.gradient.first.withValues(alpha: 0.35), blurRadius: 14)],
                ),
              ),
            ),
            Row(children: [
              for (final v in RecordsView.values)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(v),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontFamilyFallback: const ['Manrope'],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: v == value ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        child: Text(_labels[v]!),
                      ),
                    ),
                  ),
                ),
            ]),
          ]),
        );
      }),
    );
  }
}

// ---- День -------------------------------------------------------------------

class _DayView extends StatelessWidget {
  const _DayView({required this.txns});
  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    if (txns.isEmpty) {
      return const EmptyState(icon: Icons.receipt_long_outlined, text: 'Записів за цей період немає.\nНатисни «+», щоб додати.');
    }
    final days = <DateTime, List<Txn>>{};
    for (final t in txns) {
      days.putIfAbsent(DateTime(t.date.year, t.date.month, t.date.day), () => []).add(t);
    }
    return Column(children: [
      for (final (i, e) in days.entries.indexed)
        _Appear(
          index: i,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DayCard(day: e.key, txns: e.value),
          ),
        ),
    ]);
  }
}

class _Appear extends StatelessWidget {
  const _Appear({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 380 + (index.clamp(0, 8)) * 60),
        curve: Curves.easeOutCubic,
        builder: (context, t, c) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: c)),
        child: child,
      );
}

/// A glass card for one day: big date, weekday, day totals and its records.
class DayCard extends StatelessWidget {
  const DayCard({super.key, required this.day, required this.txns});
  final DateTime day;
  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = AppPalette.of(context);
    final t = store.totalsBase(txns);
    final cur = store.baseCurrency;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final weekend = day.weekday >= 6;
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('${day.day}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: (weekend ? p.expense : Theme.of(context).colorScheme.primary).withValues(alpha: 0.18),
              ),
              child: Text(weekdayShort(day), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: weekend ? p.expense : null)),
            ),
            const SizedBox(width: 8),
            Text(DateFormatCache.monthYear(day), style: TextStyle(fontSize: 12, color: muted)),
            const Spacer(),
            if (t.income > 0) Text(money(t.income, cur), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: incomeColor(context, store))),
            if (t.income > 0 && t.expense > 0) const SizedBox(width: 10),
            if (t.expense > 0) Text(money(t.expense, cur), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.expense)),
          ]),
        ),
        Divider(height: 1, indent: 18, endIndent: 18, color: Colors.white.withValues(alpha: 0.08)),
        for (final x in txns) TxnTile(txn: x),
      ]),
    );
  }
}

class DateFormatCache {
  static String monthYear(DateTime d) => '${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class TxnTile extends StatelessWidget {
  const TxnTile({super.key, required this.txn});
  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = AppPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final acc = store.account(txn.accountId);
    final cur = acc?.currency ?? store.baseCurrency;
    final top = store.topCategory(txn.categoryId);
    final cat = store.category(txn.categoryId);

    final String title;
    final String subtitle;
    final Widget avatar;
    final Color amountColor;
    final String amountText;
    switch (txn.type) {
      case TxType.transfer:
        final to = store.account(txn.toAccountId);
        title = 'Переказ';
        subtitle = [
          '${acc?.name ?? '?'} → ${to?.name ?? '?'}',
          if (txn.note.isNotEmpty) txn.note,
        ].join(' · ');
        avatar = EmojiAvatar(emoji: '🔄', color: scheme.primary);
        amountColor = scheme.onSurface;
        amountText = money(txn.amount, cur);
      case TxType.income || TxType.expense:
        title = top?.name ?? 'Без категорії';
        subtitle = [
          if (cat != null && top != null && cat.id != top.id) cat.name,
          if (txn.note.isNotEmpty) txn.note,
          acc?.name ?? '',
        ].join(' · ');
        avatar = EmojiAvatar(emoji: top?.emoji ?? '•', color: Color(top?.color ?? 0xFF8E8E93), size: 38);
        final income = txn.type == TxType.income;
        amountColor = income ? incomeColor(context, store) : p.expense;
        amountText = money(txn.amount, cur);
    }

    return Dismissible(
      key: ValueKey(txn.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: p.expense.withValues(alpha: 0.15),
        child: Icon(Icons.delete_outline_rounded, color: p.expense),
      ),
      onDismissed: (_) {
        store.deleteTxn(txn);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: const Text('Запис видалено'),
            action: SnackBarAction(label: 'Повернути', onPressed: () => store.saveTxn(txn.copyWith(deleted: false))),
          ));
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        visualDensity: const VisualDensity(vertical: -1),
        leading: avatar,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant)),
        trailing: Text(amountText, style: TextStyle(color: amountColor, fontWeight: FontWeight.w700, fontSize: 15)),
        onTap: () => openTxnEditor(context, existing: txn),
      ),
    );
  }
}

// ---- Календар -----------------------------------------------------------------

class _CalendarView extends StatelessWidget {
  const _CalendarView({required this.month, required this.txns});
  final DateTime month;
  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = AppPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final r = store.periodRange(month);
    final monday = store.prefs.weekStartsMonday;
    final firstWeekday = monday ? 1 : 7;
    var gridStart = r.start;
    while (gridStart.weekday != firstWeekday) {
      gridStart = gridStart.subtract(const Duration(days: 1));
    }
    final days = <DateTime>[];
    for (var d = gridStart; d.isBefore(r.end) || days.length % 7 != 0; d = DateTime(d.year, d.month, d.day + 1)) {
      days.add(d);
    }
    final byDay = <DateTime, ({int inc, int exp})>{};
    for (final t in txns) {
      final k = DateTime(t.date.year, t.date.month, t.date.day);
      final cur = byDay[k] ?? (inc: 0, exp: 0);
      if (t.type == TxType.income) byDay[k] = (inc: cur.inc + store.baseAmount(t), exp: cur.exp);
      if (t.type == TxType.expense) byDay[k] = (inc: cur.inc, exp: cur.exp + store.baseAmount(t));
    }
    final today = DateTime.now();
    final names = monday ? ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'] : ['Нд', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
    String compact(int minor) {
      final v = minor / 100;
      if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
      return v.toStringAsFixed(0);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 24,
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Row(children: [
            for (final (i, n) in names.indexed)
              Expanded(
                child: Center(
                  child: Text(n,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: (monday ? i >= 5 : (i == 0 || i == 6)) ? p.expense : scheme.onSurfaceVariant)),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.72,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              for (final d in days)
                Builder(builder: (context) {
                  final inRange = !d.isBefore(r.start) && d.isBefore(r.end);
                  final v = byDay[d];
                  final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
                  return GestureDetector(
                    onTap: inRange ? () => _openDay(context, d) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isToday ? scheme.primary.withValues(alpha: 0.22) : Colors.white.withValues(alpha: inRange ? 0.04 : 0),
                        border: isToday ? Border.all(color: scheme.primary.withValues(alpha: 0.7)) : null,
                      ),
                      child: Opacity(
                        opacity: inRange ? 1 : 0.3,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${d.day}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          if (v != null && v.inc > 0)
                            FittedBox(child: Text(compact(v.inc), style: TextStyle(fontSize: 10, color: incomeColor(context, store), fontWeight: FontWeight.w600))),
                          if (v != null && v.exp > 0)
                            FittedBox(child: Text(compact(v.exp), style: TextStyle(fontSize: 10, color: p.expense, fontWeight: FontWeight.w600))),
                        ]),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ]),
      ),
    );
  }

  void _openDay(BuildContext context, DateTime d) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) {
        final store = StoreScope.of(ctx);
        final list = store.txnsOnDay(d);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(dayTitle(d), style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (list.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('Записів немає', textAlign: TextAlign.center))
            else
              Flexible(child: ListView(shrinkWrap: true, children: [for (final t in list) TxnTile(txn: t)])),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Додати на цей день'),
              onPressed: () {
                Navigator.pop(ctx);
                openTxnEditor(context, date: d);
              },
            ),
          ]),
        );
      },
    );
  }
}

// ---- Місяць (тижні) -----------------------------------------------------------

class _WeeksView extends StatelessWidget {
  const _WeeksView({required this.month, required this.txns});
  final DateTime month;
  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = AppPalette.of(context);
    final r = store.periodRange(month);
    final firstWeekday = store.prefs.weekStartsMonday ? 1 : 7;
    final weeks = <(DateTime, DateTime)>[];
    var s = r.start;
    while (s.isBefore(r.end)) {
      var e = DateTime(s.year, s.month, s.day + 1);
      while (e.isBefore(r.end) && e.weekday != firstWeekday) {
        e = DateTime(e.year, e.month, e.day + 1);
      }
      weeks.add((s, e));
      s = e;
    }
    final cur = store.baseCurrency;
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 24,
        child: Column(children: [
          for (final (a, b) in weeks.reversed)
            Builder(builder: (context) {
              final t = store.totalsBase(txns.where((x) => !x.date.isBefore(a) && x.date.isBefore(b)));
              final current = !now.isBefore(a) && now.isBefore(b);
              return Container(
                color: current ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) : null,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(children: [
                  Expanded(
                    child: Text('${shortDayMonth(a)} – ${shortDayMonth(b.subtract(const Duration(days: 1)))}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(money(t.income, cur), style: TextStyle(fontSize: 13, color: incomeColor(context, store))),
                    Text(money(t.expense, cur), style: TextStyle(fontSize: 13, color: p.expense)),
                  ]),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 96,
                    child: Text(money(t.income - t.expense, cur, sign: true),
                        textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
              );
            }),
        ]),
      ),
    );
  }
}

// ---- Підсумок -------------------------------------------------------------------

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.month, required this.txns});
  final DateTime month;
  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = AppPalette.of(context);
    final cur = store.baseCurrency;
    final prev = store.totalsBase(store.txnsInPeriod(DateTime(month.year, month.month - 1)));
    final now = store.totalsBase(txns);

    // Expenses per account.
    final perAcc = <String, int>{};
    for (final t in txns.where((t) => t.type == TxType.expense)) {
      perAcc[t.accountId] = (perAcc[t.accountId] ?? 0) + store.baseAmount(t);
    }
    final overall = store.budgets.where((b) => b.categoryId == null && b.currency == cur).firstOrNull;

    String diff(int a, int b) {
      if (b == 0) return '—';
      final pct = ((a - b) / b * 100).round();
      return '${pct > 0 ? '+' : ''}$pct%';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GlassCard(
          radius: 24,
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Порівняно з попереднім періодом', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _row(context, 'Дохід', money(prev.income, cur), diff(now.income, prev.income), incomeColor(context, store)),
            _row(context, 'Витрати', money(prev.expense, cur), diff(now.expense, prev.expense), p.expense),
          ]),
        ),
        if (overall != null) ...[
          const SizedBox(height: 12),
          GlassCard(
            radius: 24,
            padding: const EdgeInsets.all(18),
            child: BudgetBar(title: 'Загальний бюджет', spent: now.expense, limit: overall.amount, currency: cur, month: month),
          ),
        ],
        const SizedBox(height: 12),
        GlassCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.fromLTRB(18, 8, 18, 4), child: Text('Витрати за рахунками', style: TextStyle(fontWeight: FontWeight.w700))),
            if (perAcc.isEmpty) const Padding(padding: EdgeInsets.all(18), child: Text('Немає витрат')),
            for (final e in perAcc.entries)
              ListTile(
                dense: true,
                leading: Icon(Icons.circle, size: 12, color: Color(store.account(e.key)?.color ?? 0xFF8E8E93)),
                title: Text(store.account(e.key)?.name ?? '?'),
                trailing: Text(money(e.value, cur), style: TextStyle(fontWeight: FontWeight.w600, color: p.expense)),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        GlassCard(
          radius: 24,
          onTap: () => exportForPf(context),
          padding: const EdgeInsets.all(18),
          child: const Row(children: [
            Icon(Icons.table_view_rounded),
            SizedBox(width: 12),
            Expanded(child: Text('Експорт в Excel для PF', style: TextStyle(fontWeight: FontWeight.w700))),
            Icon(Icons.chevron_right_rounded),
          ]),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, String label, String prev, String diff, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text('було $prev', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(width: 12),
          SizedBox(width: 56, child: Text(diff, textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w700, color: color))),
        ]),
      );
}

/// Budget progress with a "today" pace marker.
class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.title, required this.spent, required this.limit, required this.currency, required this.month, this.leading});
  final String title;
  final int spent;
  final int limit;
  final String currency;
  final DateTime month;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = AppPalette.of(context);
    final r = store.periodRange(month);
    final now = DateTime.now();
    final total = r.end.difference(r.start).inHours;
    final pace = now.isBefore(r.start) ? 0.0 : now.isAfter(r.end) ? 1.0 : now.difference(r.start).inHours / total;
    final ratio = limit == 0 ? 0.0 : spent / limit;
    final over = ratio > 1;
    final color = over ? p.expense : (ratio > pace + 0.05 ? const Color(0xFFFF9F0A) : p.income);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final daysLeft = r.end.difference(now.isBefore(r.start) ? r.start : DateTime(now.year, now.month, now.day)).inDays.clamp(1, 31);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
        Text('${money(spent, currency)} / ${money(limit, currency)}', style: TextStyle(fontSize: 13, color: muted)),
      ]),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, c) {
        return Stack(clipBehavior: Clip.none, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio.clamp(0, 1)),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: v, minHeight: 10, color: color, backgroundColor: color.withValues(alpha: 0.15)),
            ),
          ),
          Positioned(
            left: (c.maxWidth * pace).clamp(0, c.maxWidth - 2),
            top: -4,
            child: Container(width: 2, height: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
          ),
        ]);
      }),
      const SizedBox(height: 6),
      Text(
        over
            ? 'Перевищено на ${money(spent - limit, currency)}'
            : 'Залишилось ${money(limit - spent, currency)} · ${money(((limit - spent) / daysLeft).round(), currency)} на день',
        style: TextStyle(fontSize: 12, color: over ? p.expense : muted),
      ),
    ]);
  }
}
