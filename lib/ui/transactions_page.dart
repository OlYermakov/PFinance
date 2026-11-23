import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../state/app_store.dart';
import 'edit_transaction.dart';
import 'accounts_page.dart' show groupOf;
import 'export_pf.dart';
import 'more_page.dart' show RepeatsPage;
import 'stats_page.dart' show editBudget;
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
    // MM "Місяці": the whole year, month by month.
    final yearMode = _view == RecordsView.month;
    final yr = (start: store.periodRange(DateTime(_month.year, 1)).start, end: store.periodRange(DateTime(_month.year, 12)).end);
    var list = yearMode ? store.txns.where((t) => !t.date.isBefore(yr.start) && t.date.isBefore(yr.end)).toList() : store.txnsInPeriod(_month);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((t) {
        return t.note.toLowerCase().contains(q) ||
            txnTitle(store, t).toLowerCase().contains(q) ||
            (store.account(t.accountId)?.name.toLowerCase().contains(q) ??
                false);
      }).toList();
    }
    final tot = store.totalsBase(list);
    final cur = store.baseCurrency;

    final Widget content = switch (_view) {
      RecordsView.day => _DayView(txns: list),
      RecordsView.calendar => _CalendarView(month: _month, txns: list),
      RecordsView.month => _MonthsView(month: _month, txns: list),
      RecordsView.summary => _SummaryView(month: _month, txns: list),
    };

    final swipePeriod = store.prefs.swipe == 'period';
    return GestureDetector(
      onHorizontalDragEnd: !swipePeriod
          ? null
          : (d) {
              final v = d.primaryVelocity ?? 0;
              if (v.abs() < 300) return;
              setState(
                () => _month = DateTime(
                  _month.year,
                  _month.month + (v < 0 ? 1 : -1),
                ),
              );
            },
      child: SafeArea(
        bottom: false,
        // MM: the period, view tabs and totals stay put; only the list scrolls.
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.zero,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: _searching
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: TextField(
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Нотатка, категорія або рахунок',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                          onChanged: (v) => setState(() => _query = v.trim()),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ),
            Padding(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MonthSwitcher(
                        month: _month,
                        year: yearMode,
                        onChanged: (m) => setState(() => _month = m),
                      ),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          tooltip: 'Пошук',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            _searching
                                ? Icons.close_rounded
                                : Icons.search_rounded,
                          ),
                          onPressed: () => setState(() {
                            _searching = !_searching;
                            _query = '';
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _ViewTabs(
                  value: _view,
                  onChanged: (v) => setState(() => _view = v),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TotalsStrip(
                  income: tot.income,
                  expense: tot.expense,
                  currency: cur,
                  carry: store.prefs.carryOver && _query.isEmpty
                      ? store.carryBefore(yearMode ? yr.start : store.periodRange(_month).start)
                      : null,
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (c, a) =>
                          FadeTransition(opacity: a, child: c),
                      child: KeyedSubtree(
                        key: ValueKey(yearMode ? '$_view${_month.year}' : '$_view$_month'),
                        child: content,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(3),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / 4;
          return SizedBox(
            height: 30,
            child: Stack(
              children: [
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
                      gradient: LinearGradient(
                        colors: [
                          p.gradient.first.withValues(alpha: 0.85),
                          p.gradient.last.withValues(alpha: 0.85),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: p.gradient.first.withValues(alpha: 0.35),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
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
                                color: v == value
                                    ? Colors.white
                                    : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                              ),
                              child: Text(_labels[v]!),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
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
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        text: 'Записів за цей період немає.\nНатисни «+», щоб додати.',
      );
    }
    final days = <DateTime, List<Txn>>{};
    for (final t in txns) {
      days
          .putIfAbsent(
            DateTime(t.date.year, t.date.month, t.date.day),
            () => [],
          )
          .add(t);
    }
    return Column(
      children: [
        for (final (i, e) in days.entries.indexed)
          _Appear(
            index: i,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DayCard(day: e.key, txns: e.value),
            ),
          ),
      ],
    );
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
    builder: (context, t, c) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: c),
    ),
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
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Column(
        children: [
          // MM: tapping the date line starts a new record on that day
          InkWell(
            onTap: () => openTxnEditor(context, date: day),
            child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color:
                        (weekend
                                ? p.expense
                                : Theme.of(context).colorScheme.primary)
                            .withValues(alpha: 0.18),
                  ),
                  child: Text(
                    weekdayShort(day),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: weekend ? p.expense : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormatCache.monthYear(day),
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                const Spacer(),
                if (t.income > 0)
                  Text(
                    money(t.income, cur),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: incomeColor(context, store),
                    ),
                  ),
                if (t.income > 0 && t.expense > 0) const SizedBox(width: 10),
                if (t.expense > 0)
                  Text(
                    money(t.expense, cur),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: p.expense,
                    ),
                  ),
              ],
            ),
          ),
          ),
          Divider(
            height: 1,
            indent: 18,
            endIndent: 18,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          for (final x in txns) TxnTile(txn: x),
        ],
      ),
    );
  }
}

class DateFormatCache {
  static String monthYear(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}.${d.year}';
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

    // MM-style row: category on the left (grey), note in bold with the
    // account (and repeat frequency) under it, amount on the right.
    final String left1, left2, title, under;
    final Color amountColor;
    final showNote = store.prefs.showNote && txn.note.isNotEmpty;
    final rule = store.repeats.where((r) {
      final t = r.template;
      return t.type == txn.type &&
          t.accountId == txn.accountId &&
          t.categoryId == txn.categoryId &&
          t.note == txn.note &&
          t.amount == txn.amount;
    }).firstOrNull;
    final repeat = rule == null ? '' : ' (${repeatLabel(rule.every)})';
    switch (txn.type) {
      case TxType.transfer:
        final to = store.account(txn.toAccountId);
        left1 = 'Переказ';
        left2 = '';
        title = showNote
            ? txn.note
            : '${acc?.name ?? '?'} → ${to?.name ?? '?'}';
        under = showNote
            ? '${acc?.name ?? '?'} → ${to?.name ?? '?'}$repeat'
            : repeat.trim();
        final f = store.flowOf(txn);
        amountColor = f == TxType.expense
            ? p.expense
            : (f == TxType.income
                  ? incomeColor(context, store)
                  : scheme.onSurfaceVariant); // MM: a plain transfer is grey
      case TxType.income || TxType.expense:
        left1 = top?.name ?? 'Без категорії';
        left2 = cat != null && top != null && cat.id != top.id ? cat.name : '';
        title = showNote ? txn.note : '';
        under = '${acc?.name ?? ''}$repeat';
        amountColor = txn.type == TxType.income
            ? incomeColor(context, store)
            : p.expense;
    }
    final timeText = store.prefs.timeMode == 2
        ? TimeOfDay.fromDateTime(txn.date).format(context)
        : null;
    final muted = TextStyle(
      color: scheme.onSurfaceVariant,
      fontSize: 13,
      height: 1.25,
    );
    final second = [?timeText, if (under.isNotEmpty) under].join(' · ');
    final tile = InkWell(
      onTap: () => openTxnEditor(context, existing: txn),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Row(
            children: [
              SizedBox(
                width: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      left1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                    if (left2.isNotEmpty)
                      Text(
                        left2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // MM: a transfer's "A → B" line is grey, not white
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          height: 1.25,
                          color: txn.type == TxType.transfer ? scheme.onSurfaceVariant : null,
                        ),
                      ),
                    if (second.isNotEmpty)
                      Text(
                        second,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                // MM: shown in the currency it was typed in
                txn.enteredAmount != null && txn.enteredCur != null ? money(txn.enteredAmount!, txn.enteredCur!) : money(txn.amount, cur),
                style: TextStyle(
                  color: amountColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (store.prefs.swipe != 'delete') return tile;
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
          ..showSnackBar(
            SnackBar(
              content: const Text('Запис видалено'),
              action: SnackBarAction(
                label: 'Повернути',
                onPressed: () => store.saveTxn(txn.copyWith(deleted: false)),
              ),
            ),
          );
      },
      child: tile,
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
    for (
      var d = gridStart;
      d.isBefore(r.end) || days.length % 7 != 0;
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      days.add(d);
    }
    final byDay = <DateTime, ({int inc, int exp})>{};
    for (final t in txns) {
      final k = DateTime(t.date.year, t.date.month, t.date.day);
      final cur = byDay[k] ?? (inc: 0, exp: 0);
      final f = store.flowOf(t);
      if (f == TxType.income) {
        byDay[k] = (inc: cur.inc + store.baseAmount(t), exp: cur.exp);
      }
      if (f == TxType.expense) {
        byDay[k] = (inc: cur.inc, exp: cur.exp + store.baseAmount(t));
      }
    }
    final today = DateTime.now();
    final names = monday
        ? ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд']
        : ['Нд', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
    String compact(int minor) {
      final v = minor / 100;
      if (v >= 1000) {
        return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
      }
      return v.toStringAsFixed(0);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 24,
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                for (final (i, n) in names.indexed)
                  Expanded(
                    child: Center(
                      child: Text(
                        n,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: (monday ? i >= 5 : (i == 0 || i == 6))
                              ? p.expense
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
                  Builder(
                    builder: (context) {
                      final inRange = !d.isBefore(r.start) && d.isBefore(r.end);
                      final v = byDay[d];
                      final isToday =
                          d.year == today.year &&
                          d.month == today.month &&
                          d.day == today.day;
                      return GestureDetector(
                        onTap: inRange ? () => _openDay(context, d) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isToday
                                ? scheme.primary.withValues(alpha: 0.22)
                                : Colors.white.withValues(
                                    alpha: inRange ? 0.04 : 0,
                                  ),
                            border: isToday
                                ? Border.all(
                                    color: scheme.primary.withValues(
                                      alpha: 0.7,
                                    ),
                                  )
                                : null,
                          ),
                          child: Opacity(
                            opacity: inRange ? 1 : 0.3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${d.day}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                if (v != null && v.inc > 0)
                                  FittedBox(
                                    child: Text(
                                      compact(v.inc),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: incomeColor(context, store),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (v != null && v.exp > 0)
                                  FittedBox(
                                    child: Text(
                                      compact(v.exp),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: p.expense,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                dayTitle(d),
                style: Theme.of(ctx).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Записів немає', textAlign: TextAlign.center),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [for (final t in list) TxnTile(txn: t)],
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Додати на цей день'),
                onPressed: () {
                  Navigator.pop(ctx);
                  openTxnEditor(context, date: d);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---- Місяці (MM: the year by months; a month opens into its weeks) ------------

class _MonthsView extends StatefulWidget {
  const _MonthsView({required this.month, required this.txns});
  final DateTime month; // the year's selected month opens by default
  final List<Txn> txns; // the year's records (search applied)

  @override
  State<_MonthsView> createState() => _MonthsViewState();
}

class _MonthsViewState extends State<_MonthsView> {
  late int? _open = widget.month.month;

  static String _d(DateTime d) => '${d.day}.${d.month}.';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final p = AppPalette.of(context);
    final cur = store.baseCurrency;
    final now = DateTime.now();
    final y = widget.month.year;
    final line = Colors.white.withValues(alpha: 0.07);
    final firstWeekday = store.prefs.weekStartsMonday ? DateTime.monday : DateTime.sunday;

    Widget amounts(({int income, int expense}) t, {String? totalLabel}) => Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(money(t.income, cur), style: TextStyle(fontSize: 15, color: incomeColor(context, store))),
            const SizedBox(width: 18),
            SizedBox(
              width: 104,
              child: Text(money(t.expense, cur), textAlign: TextAlign.end, style: TextStyle(fontSize: 15, color: p.expense)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${totalLabel ?? ''}${money(t.income - t.expense, cur)}',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );

    final rows = <Widget>[];
    for (var m = 12; m >= 1; m--) {
      final r = store.periodRange(DateTime(y, m));
      if (r.start.isAfter(now)) continue; // MM lists months up to today
      final t = store.totalsBase(widget.txns.where((x) => !x.date.isBefore(r.start) && x.date.isBefore(r.end)));
      final open = _open == m;
      rows.add(
        InkWell(
          onTap: () => setState(() => _open = open ? null : m),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('LLL', 'uk').format(DateTime(y, m)), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text('${_d(r.start)} ~ ${_d(r.end.subtract(const Duration(days: 1)))}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                amounts(t, totalLabel: open ? 'Всього ' : null),
              ],
            ),
          ),
        ),
      );
      if (!open) continue;
      // Whole weeks touching this month, newest first; each sums its full week.
      var ws = r.start;
      while (ws.weekday != firstWeekday) {
        ws = DateTime(ws.year, ws.month, ws.day - 1);
      }
      final weeks = <DateTime>[];
      for (var s = ws; s.isBefore(r.end); s = DateTime(s.year, s.month, s.day + 7)) {
        weeks.add(s);
      }
      for (final a in weeks.reversed) {
        final b = DateTime(a.year, a.month, a.day + 7);
        final wt = store.totalsBase(store.txns.where((x) => !x.date.isBefore(a) && x.date.isBefore(b)));
        final current = !now.isBefore(a) && now.isBefore(b);
        rows.add(
          Container(
            padding: const EdgeInsets.fromLTRB(52, 8, 16, 8),
            decoration: BoxDecoration(
              color: current ? p.expense.withValues(alpha: 0.28) : Colors.black.withValues(alpha: 0.12),
              border: Border(bottom: BorderSide(color: line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text('${_d(a)} ~ ${_d(DateTime(b.year, b.month, b.day - 1))}', style: const TextStyle(fontSize: 15))),
                amounts(wt),
              ],
            ),
          ),
        );
      }
    }
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: panelColor(context),
      child: Column(children: rows),
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
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final cur = store.baseCurrency;
    final now = store.totalsBase(txns);
    final range = store.periodRange(month);

    // Accounts: expenses (with the account groups they came from) and
    // transfers into accounts marked "Переказ-витрата".
    final groups = <String>{};
    var transferOut = 0;
    for (final t in txns) {
      final a = store.account(t.accountId);
      if (t.type == TxType.expense && a != null) groups.add(groupOf(a));
      if (t.type == TxType.transfer) {
        final to = store.account(t.toAccountId ?? '');
        if (to != null && store.prefs.transferExpense.contains(to.id)) {
          transferOut += store.baseAmount(t);
        }
      }
    }

    // Total budget: an explicit overall budget, else the sum of the expense
    // category budgets (as Money Manager does).
    final overall = store.budgets
        .where((b) => b.categoryId == null && b.currency == cur)
        .firstOrNull;
    final catSum = store.budgets
        .where(
          (b) =>
              b.categoryId != null &&
              b.currency == cur &&
              store.category(b.categoryId)?.type == TxType.expense &&
              store.category(b.categoryId)?.parentId == null,
        )
        .fold<int>(0, (s, b) => s + b.amount);
    final limit = overall?.amount ?? (catSum > 0 ? catSum : null);

    // Repeating records still due in this period (from today on).
    final today = DateTime.now();
    final from = today.isAfter(range.start) ? today : range.start;
    final upcoming = <(DateTime, RepeatRule)>[];
    for (final r in store.repeats) {
      for (var n = 0; n < 5000; n++) {
        final d = r.occurrence(n);
        if (!d.isBefore(range.end) || (r.end != null && d.isAfter(r.end!))) {
          break;
        }
        if (!d.isBefore(from) &&
            (r.lastDone == null || d.isAfter(r.lastDone!))) {
          upcoming.add((d, r));
        }
      }
    }
    upcoming.sort((a, b) => a.$1.compareTo(b.$1));

    Widget section(
      IconData icon,
      String title, {
      Widget? trailing,
      required Widget child,
    }) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      color: scheme.surface.withValues(alpha: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 21, color: muted),
              const SizedBox(width: 12),
              Expanded(
                child: title.isEmpty
                    ? const SizedBox()
                    : Text.rich(
                        _titleSpan(title, p.expense),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );

    Widget box(List<Widget> rows) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: rows),
    );

    Widget line(String label, String value, {Color? color, String? lead}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              if (lead != null)
                SizedBox(
                  width: 52,
                  child: Text(lead, style: TextStyle(color: muted)),
                ),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                value,
                style: TextStyle(
                  color: color ?? muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );

    final divider = Divider(
      height: 1,
      thickness: 1,
      color: scheme.onSurface.withValues(alpha: 0.08),
    );
    final groupList = groups.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          Icons.account_balance_wallet_outlined,
          'Рахунки',
          child: box([
            line(
              groupList.isEmpty
                  ? 'Витрати'
                  : 'Витрати (${groupList.join(', ')})',
              money(now.expense, cur),
            ),
            if (transferOut > 0)
              line('Переказ-витрата', money(transferOut, cur)),
          ]),
        ),
        divider,
        section(
          Icons.track_changes_rounded,
          'Бюджет',
          child: limit == null
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => editBudget(context, currency: cur),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Встановити загальний бюджет'),
                  ),
                )
              : InkWell(
                  onTap: overall == null
                      ? null
                      : () => editBudget(
                          context,
                          currency: cur,
                          existing: overall,
                        ),
                  child: _SummaryBudget(
                    spent: now.expense,
                    limit: limit,
                    currency: cur,
                    range: range,
                  ),
                ),
        ),
        divider,
        section(
          Icons.repeat_rounded,
          'Повтор (${upcoming.length})',
          trailing: IconButton(
            tooltip: 'Повторювані записи',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RepeatsPage()),
            ),
          ),
          child: upcoming.isEmpty
              ? Text(
                  'Немає запланованих записів до кінця періоду',
                  style: TextStyle(color: muted),
                )
              : box([
                  for (final (d, r) in upcoming)
                    line(
                      '${r.template.note.isNotEmpty ? r.template.note : txnTitle(store, r.template)}, ${repeatLabel(r.every).toLowerCase()}',
                      money(
                        r.template.amount,
                        store.account(r.template.accountId)?.currency ?? cur,
                      ),
                      lead:
                          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}',
                      color: r.template.type == TxType.income
                          ? incomeColor(context, store)
                          : r.template.type == TxType.expense
                          ? p.expense
                          : null,
                    ),
                ]),
        ),
        divider,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.18)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              foregroundColor: scheme.onSurface,
            ),
            onPressed: () => exportForPf(context),
            icon: const Icon(
              Icons.table_view_rounded,
              color: Color(0xFF21A366),
            ),
            label: const Text('Експорт даних в Excel'),
          ),
        ),
      ],
    );
  }

  /// "Повтор (5)": the count in the accent red, like the reference.
  static InlineSpan _titleSpan(String title, Color accent) {
    final m = RegExp(r'^(.*) \((\d+)\)$').firstMatch(title);
    if (m == null) return TextSpan(text: title);
    return TextSpan(
      children: [
        TextSpan(text: '${m.group(1)} '),
        TextSpan(
          text: '(${m.group(2)})',
          style: TextStyle(color: accent, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}

/// Total budget row: label and amount on the left, a bar with a "Сьогодні"
/// marker and percent on the right, spent and remaining underneath.
class _SummaryBudget extends StatelessWidget {
  const _SummaryBudget({
    required this.spent,
    required this.limit,
    required this.currency,
    required this.range,
  });
  final int spent, limit;
  final String currency;
  final ({DateTime start, DateTime end}) range;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = AppPalette.of(context);
    final muted = scheme.onSurfaceVariant;
    final now = DateTime.now();
    final total = range.end.difference(range.start).inMinutes;
    final pace = now.isBefore(range.start)
        ? 0.0
        : now.isAfter(range.end)
        ? 1.0
        : now.difference(range.start).inMinutes / total;
    final ratio = limit == 0 ? 0.0 : spent / limit;
    final barColor = ratio > 1 ? p.expense : scheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Загальний бюджет',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                money(limit, currency),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final x = (w * pace).clamp(0.0, w);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 26,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: (x - 32).clamp(0.0, w - 64),
                          width: 64,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Сьогодні',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 26,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                            color: scheme.onSurface.withValues(alpha: 0.08),
                          ),
                        ),
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: ratio.clamp(0.0, 1.0),
                              heightFactor: 1,
                              child: ColoredBox(color: barColor),
                            ),
                          ),
                        ),
                        Positioned(
                          left: x - 1,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 1.5, color: scheme.surface),
                        ),
                        Positioned(
                          right: 6,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Text(
                              '${(ratio * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        money(spent, currency),
                        style: TextStyle(color: barColor, fontSize: 15),
                      ),
                      const Spacer(),
                      Text(
                        money(limit - spent, currency),
                        style: TextStyle(
                          fontSize: 15,
                          color: limit - spent < 0 ? p.expense : null,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Budget progress with a "today" pace marker.
class BudgetBar extends StatelessWidget {
  const BudgetBar({
    super.key,
    required this.title,
    required this.spent,
    required this.limit,
    required this.currency,
    required this.month,
    this.leading,
  });
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
    final pace = now.isBefore(r.start)
        ? 0.0
        : now.isAfter(r.end)
        ? 1.0
        : now.difference(r.start).inHours / total;
    final ratio = limit == 0 ? 0.0 : spent / limit;
    final over = ratio > 1;
    final color = over
        ? p.expense
        : (ratio > pace + 0.05 ? const Color(0xFFFF9F0A) : p.income);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final daysLeft = r.end
        .difference(
          now.isBefore(r.start)
              ? r.start
              : DateTime(now.year, now.month, now.day),
        )
        .inDays
        .clamp(1, 31);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${money(spent, currency)} / ${money(limit, currency)}',
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio.clamp(0, 1)),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 10,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                Positioned(
                  left: (c.maxWidth * pace).clamp(0, c.maxWidth - 2),
                  top: -4,
                  child: Container(
                    width: 2,
                    height: 18,
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.8),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          over
              ? 'Перевищено на ${money(spent - limit, currency)}'
              : 'Залишилось ${money(limit - spent, currency)} · ${money(((limit - spent) / daysLeft).round(), currency)} на день',
          style: TextStyle(fontSize: 12, color: over ? p.expense : muted),
        ),
      ],
    );
  }
}
