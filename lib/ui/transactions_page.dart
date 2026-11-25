import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../state/app_store.dart';
import 'edit_transaction.dart';
import 'accounts_page.dart' show groupOf;
import 'export_pf.dart';
import 'more_page.dart' show RepeatsPage, shareBackup, showInstallHelp, backupAgo;
import 'pwa.dart';
import 'stats_page.dart' show editBudget, budgetTotals, BudgetRow;
import 'format.dart';
import 'theme.dart';
import 'widgets.dart';
import '../l10n/l10n.dart';

enum RecordsView { day, calendar, month, summary }

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key, this.initialView = RecordsView.day});
  final RecordsView initialView;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late DateTime _month = StoreScope.read(context).currentPeriod;
  late DateTime _week = StoreScope.read(context).weekOf(DateTime.now());
  late RecordsView _view = widget.initialView;

  // MM «Тижні»: the Day and Summary views go week by week; the calendar
  // and the year stay as they are. Week and month follow each other.
  void _setMonth(AppStore store, DateTime m) {
    _month = m;
    final r = store.periodRange(m);
    if (_week.isBefore(store.weekOf(r.start)) || !_week.isBefore(r.end)) _week = store.weekOf(r.start);
  }

  void _setWeek(AppStore store, DateTime w) {
    _week = store.weekOf(w);
    _month = store.periodOf(_week);
  }

  String _query = '';
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    // MM "Місяці": the whole year, month by month.
    final yearMode = _view == RecordsView.month;
    final weekMode = store.prefs.weeklyPeriod && (_view == RecordsView.day || _view == RecordsView.summary);
    final wr = store.weekRange(_week);
    final yr = (start: store.periodRange(DateTime(_month.year, 1)).start, end: store.periodRange(DateTime(_month.year, 12)).end);
    var list = yearMode
        ? store.txns.where((t) => !t.date.isBefore(yr.start) && t.date.isBefore(yr.end)).toList()
        : weekMode
        ? store.txns.where((t) => !t.date.isBefore(wr.start) && t.date.isBefore(wr.end)).toList()
        : store.txnsInPeriod(_month);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((t) {
        return t.note.toLowerCase().contains(q) ||
            t.memo.toLowerCase().contains(q) ||
            txnTitle(store, t).toLowerCase().contains(q) ||
            (store.account(t.accountId)?.name.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    final tot = store.totalsBase(list);
    final cur = store.baseCurrency;

    final Widget content = switch (_view) {
      RecordsView.day => const SizedBox.shrink(), // a lazy sliver, below
      RecordsView.calendar => _CalendarView(month: _month, txns: list),
      RecordsView.month => _MonthsView(month: _month, txns: list),
      RecordsView.summary => _SummaryView(month: _month, txns: list, range: weekMode ? wr : null),
    };

    // Swipe: switch the view tabs (default) or the period.
    final swipe = store.prefs.swipe;
    return GestureDetector(
      onHorizontalDragEnd: swipe != 'tabs' && swipe != 'period'
          ? null
          : (d) {
              final v = d.primaryVelocity ?? 0;
              if (v.abs() < 300) return;
              final step = v < 0 ? 1 : -1;
              setState(() {
                if (swipe == 'period') {
                  if (weekMode) {
                    _setWeek(store, DateTime(_week.year, _week.month, _week.day + 7 * step));
                  } else {
                    _setMonth(store, DateTime(_month.year, _month.month + step * (yearMode ? 12 : 1)));
                  }
                } else {
                  final i = RecordsView.values.indexOf(_view) + step;
                  if (i >= 0 && i < RecordsView.values.length) _view = RecordsView.values[i];
                }
              });
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
                          decoration: InputDecoration(hintText: tr('Нотатка, категорія або рахунок'), prefixIcon: Icon(Icons.search_rounded)),
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
                        month: weekMode ? _week : _month,
                        year: yearMode,
                        week: weekMode,
                        onChanged: (m) => setState(() => weekMode ? _setWeek(store, m) : _setMonth(store, m)),
                      ),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          tooltip: tr('Пошук'),
                          visualDensity: VisualDensity.compact,
                          icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
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
                child: _ViewTabs(value: _view, onChanged: (v) => setState(() => _view = v)),
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
                      ? store.carryBefore(yearMode ? yr.start : (weekMode ? wr.start : store.periodRange(_month).start))
                      : null,
                ),
              ),
            ),
            const _DataNotice(),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (_view == RecordsView.day) _DayView(txns: list) else SliverToBoxAdapter(child: content),
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

/// One quiet line under the totals: add the app to the home screen (iPhone
/// in Safari) or make a backup when one is due.
class _DataNotice extends StatefulWidget {
  const _DataNotice();

  static bool _backupClosed = false; // until the app is opened again

  @override
  State<_DataNotice> createState() => _DataNoticeState();
}

class _DataNoticeState extends State<_DataNotice> {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final install = isIos && !isStandalone && !store.prefs.installHintHidden;
    final backup = !install && !_DataNotice._backupClosed && store.backupDue;
    Widget? child;
    if (install || backup) {
      child = Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
        decoration: ShapeDecoration(
          color: panelColor(context),
          shape: StadiumBorder(side: BorderSide(color: hairline(context, 0.1))),
        ),
        child: Row(
          children: [
            Icon(install ? Icons.add_to_home_screen_rounded : Icons.cloud_upload_outlined, size: 20, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                install ? tr('Додай на головний екран') : tr('Остання копія: {0}', [backupAgo(store.prefs.lastBackup)]),
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(shape: const StadiumBorder(), visualDensity: VisualDensity.compact),
              onPressed: () => install ? showInstallHelp(context) : shareBackup(context),
              child: Text(install ? tr('Як?') : tr('Зберегти')),
            ),
            IconButton(
              tooltip: tr('Закрити'),
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
              onPressed: () {
                if (install) {
                  store.updatePrefs((p) => p.installHintHidden = true);
                } else {
                  setState(() => _DataNotice._backupClosed = true);
                }
              },
            ),
          ],
        ),
      );
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: child ?? const SizedBox(width: double.infinity),
    );
  }
}

/// Pill tabs: День · Календар · Місяць · Підсумок.
class _ViewTabs extends StatelessWidget {
  const _ViewTabs({required this.value, required this.onChanged});
  final RecordsView value;
  final ValueChanged<RecordsView> onChanged;

  static Map<RecordsView, String> get _labels => {RecordsView.day: tr('День'), RecordsView.calendar: tr('Календар'), RecordsView.month: tr('Місяць'), RecordsView.summary: tr('Підсумок')};

  @override
  Widget build(BuildContext context) => PillTabs<RecordsView>(value: value, items: _labels, onChanged: onChanged);
}

// ---- День -------------------------------------------------------------------

/// Day cards, built lazily as the list scrolls (a month can hold hundreds of
/// records).
class _DayView extends StatelessWidget {
  const _DayView({required this.txns});
  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    if (txns.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyState(icon: Icons.receipt_long_outlined, text: tr('Записів за цей період немає.\nНатисни «+», щоб додати.')),
      );
    }
    final days = <DateTime, List<Txn>>{};
    for (final t in txns) {
      days.putIfAbsent(DateTime(t.date.year, t.date.month, t.date.day), () => []).add(t);
    }
    final entries = days.entries.toList();
    return SliverList.builder(
      itemCount: entries.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: DayCard(day: entries[i].key, txns: entries[i].value),
      ),
    );
  }
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
    // MM: Sunday red, Saturday blue, other days in the accent.
    final dayColor = switch (day.weekday) {
      DateTime.sunday => p.expense,
      DateTime.saturday => const Color(0xFF4F9DF0),
      _ => null,
    };
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
                  Text('${day.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: (dayColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.18),
                    ),
                    child: Text(
                      weekdayShort(day),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: dayColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(DateFormatCache.monthYear(day), style: TextStyle(fontSize: 12, color: muted)),
                  const Spacer(),
                  if (t.income > 0)
                    Text(
                      money(t.income, cur),
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: incomeColor(context, store)),
                    ),
                  if (t.income > 0 && t.expense > 0) const SizedBox(width: 10),
                  if (t.expense > 0)
                    Text(
                      money(t.expense, cur),
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: p.expense),
                    ),
                ],
              ),
            ),
          ),
          Divider(height: 1, indent: 18, endIndent: 18, color: hairline(context, 0.08)),
          for (final x in store.prefs.timeAsc ? txns.reversed : txns) TxnTile(txn: x),
        ],
      ),
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

    // MM-style row: category on the left (grey), note in bold with the
    // account (and repeat frequency) under it, amount on the right.
    final String left1, left2, title, under;
    final Color amountColor;
    // MM «Показати деталі»: the description follows the note in grey.
    final details = store.prefs.showNote && txn.memo.isNotEmpty ? txn.memo : '';
    final showNote = txn.note.isNotEmpty || details.isNotEmpty;
    final rule = store.repeatOf(txn);
    final repeat = rule == null ? '' : ' (${repeatLabel(rule.every)})';
    switch (txn.type) {
      case TxType.transfer:
        final to = store.account(txn.toAccountId);
        left1 = tr('Переказ');
        left2 = '';
        title = showNote ? txn.note : '${acc?.name ?? '?'} → ${to?.name ?? '?'}';
        under = showNote ? '${acc?.name ?? '?'} → ${to?.name ?? '?'}$repeat' : repeat.trim();
        final f = store.flowOf(txn);
        amountColor = f == TxType.expense
            ? p.expense
            : (f == TxType.income ? incomeColor(context, store) : scheme.onSurfaceVariant); // MM: a plain transfer is grey
      case TxType.income || TxType.expense:
        left1 = top?.name ?? tr('Без категорії');
        left2 = cat != null && top != null && cat.id != top.id ? cat.name : '';
        title = showNote ? txn.note : '';
        under = '${acc?.name ?? ''}$repeat';
        amountColor = txn.type == TxType.income ? incomeColor(context, store) : p.expense;
    }
    final timeText = store.prefs.timeMode == 2 ? TimeOfDay.fromDateTime(txn.date).format(context) : null;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5, height: 1.3);
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
                    Text(left1, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                    if (left2.isNotEmpty) Text(left2, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty || details.isNotEmpty)
                      Text.rich(
                        TextSpan(
                          text: title,
                          children: [
                            if (details.isNotEmpty)
                              TextSpan(
                                text: title.isEmpty ? details : ' $details',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // MM: a transfer's "A → B" line is grey, not white
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14.5,
                          height: 1.25,
                          color: txn.type == TxType.transfer ? scheme.onSurfaceVariant : null,
                        ),
                      ),
                    if (second.isNotEmpty) Text(second, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                // MM: shown in the currency it was typed in
                txn.enteredAmount != null && txn.enteredCur != null ? money(txn.enteredAmount!, txn.enteredCur!) : money(txn.amount, cur),
                style: TextStyle(color: amountColor, fontWeight: FontWeight.w500, fontSize: 14.5),
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
      confirmDismiss: (_) => confirmDeleteRecord(context),
      onDismissed: (_) {
        store.deleteTxn(txn);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(tr('Запис видалено')),
              action: SnackBarAction(label: tr('Повернути'), onPressed: () => store.saveTxn(txn.copyWith(deleted: false))),
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
    final firstWeekday = store.prefs.weekStart;
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
      final f = store.flowOf(t);
      if (f == TxType.income) {
        byDay[k] = (inc: cur.inc + store.baseAmount(t), exp: cur.exp);
      }
      if (f == TxType.expense) {
        byDay[k] = (inc: cur.inc, exp: cur.exp + store.baseAmount(t));
      }
    }
    final today = DateTime.now();
    final names = weekdayNames(firstWeekday);
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
                          color: (firstWeekday - 1 + i) % 7 >= 5 ? p.expense : scheme.onSurfaceVariant,
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
                      final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
                      return GestureDetector(
                        onTap: inRange ? () => _openDay(context, d) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isToday ? scheme.primary.withValues(alpha: 0.22) : hairline(context, inRange ? 0.04 : 0),
                            border: isToday ? Border.all(color: scheme.primary.withValues(alpha: 0.7)) : null,
                          ),
                          child: Opacity(
                            opacity: inRange ? 1 : 0.3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${d.day}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                const Spacer(),
                                if (v != null && v.inc > 0)
                                  FittedBox(
                                    child: Text(
                                      compact(v.inc),
                                      style: TextStyle(fontSize: 10, color: incomeColor(context, store), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                if (v != null && v.exp > 0)
                                  FittedBox(
                                    child: Text(
                                      compact(v.exp),
                                      style: TextStyle(fontSize: 10, color: p.expense, fontWeight: FontWeight.w600),
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
              Text(dayTitle(d), style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (list.isEmpty)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(tr('Записів немає'), textAlign: TextAlign.center),
                )
              else
                Flexible(
                  child: ListView(shrinkWrap: true, children: [for (final t in list) TxnTile(txn: t)]),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: Text(tr('Додати на цей день')),
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
    final line = hairline(context, 0.07);
    final firstWeekday = store.prefs.weekStart;

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
              child: Text(
                money(t.expense, cur),
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 15, color: p.expense),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('${totalLabel ?? ''}${money(t.income - t.expense, cur)}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
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
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: line)),
            ),
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
                amounts(t, totalLabel: open ? tr('Всього ') : null),
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

double _pace(({DateTime start, DateTime end}) r) {
  final now = DateTime.now();
  if (now.isBefore(r.start)) return 0;
  if (now.isAfter(r.end)) return 1;
  return now.difference(r.start).inMinutes / r.end.difference(r.start).inMinutes;
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.month, required this.txns, this.range});
  final DateTime month;
  final List<Txn> txns;
  final ({DateTime start, DateTime end})? range; // a week (MM «Тижні»)

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = AppPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final cur = store.baseCurrency;
    final range = this.range ?? store.periodRange(month);

    // Accounts: expense records per account group (in the Accounts tab
    // order), and transfers into accounts marked "Переказ-витрата".
    final byGroup = <String, int>{};
    var transferOut = 0;
    final ordered = [...txns]..sort((x, y) => (store.account(x.accountId)?.sort ?? 0).compareTo(store.account(y.accountId)?.sort ?? 0));
    for (final t in ordered) {
      final a = store.account(t.accountId);
      if (t.type == TxType.expense && a != null) byGroup[groupOf(a)] = (byGroup[groupOf(a)] ?? 0) + store.baseAmount(t);
      if (t.type == TxType.transfer) {
        final to = store.account(t.toAccountId ?? '');
        if (to != null && store.prefs.transferExpense.contains(to.id)) {
          transferOut += store.baseAmount(t);
        }
      }
    }

    // Same total as the Budget tab (MM): an explicit overall budget, else the
    // sum of the top-level expense and transfer-expense budgets.
    final overall = store.budgets.where((b) => b.categoryId == null && b.currency == cur).firstOrNull;
    final bt = budgetTotals(store, month, cur, TxType.expense);
    final limit = overall != null || bt.limitTotal > 0 ? bt.limitTotal : null;

    // Repeating records still due in this period (from today on).
    final today = DateTime.now();
    final from = today.isAfter(range.start) ? today : range.start;
    final upcoming = <(DateTime, RepeatRule)>[];
    for (final r in store.repeats) {
      for (final d in r.occurrences) {
        if (!d.isBefore(range.end) || (r.end != null && d.isAfter(r.end!))) {
          break;
        }
        if (!d.isBefore(from) && (r.lastDone == null || d.isAfter(r.lastDone!))) {
          upcoming.add((d, r));
        }
      }
    }
    upcoming.sort((a, b) => a.$1.compareTo(b.$1));

    Widget section(IconData icon, String title, {Widget? trailing, required Widget child}) => Container(
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
                    : Text.rich(_titleSpan(title, p.expense), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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

    Widget line(String label, String value, {Color? color, String? lead}) => Padding(
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
            style: TextStyle(color: color ?? muted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );

    final divider = Divider(height: 1, thickness: 1, color: scheme.onSurface.withValues(alpha: 0.08));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          Icons.account_balance_wallet_outlined,
          tr('Рахунки'),
          child: box([
            if (byGroup.isEmpty) line(tr('Витрати'), money(0, cur)),
            for (final g in byGroup.entries) line(tr('Витрати ({0})', [g.key]), money(g.value, cur)),
            if (transferOut > 0) line(tr('Переказ-витрата'), money(transferOut, cur)),
          ]),
        ),
        divider,
        section(
          Icons.track_changes_rounded,
          tr('Бюджет'),
          child: limit == null
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => editBudget(context, currency: cur),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(tr('Встановити загальний бюджет')),
                  ),
                )
              : InkWell(
                  onTap: overall == null ? null : () => editBudget(context, currency: cur, existing: overall),
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    child: BudgetRow(
                      title: tr('Бюджет (Місяць)'),
                      limit: limit,
                      spent: bt.spentTotal,
                      pace: _pace(range),
                      currency: cur,
                      showToday: true,
                      index: 0,
                    ),
                  ),
                ),
        ),
        divider,
        section(
          Icons.repeat_rounded,
          tr('Повтор ({0})', [upcoming.length]),
          trailing: IconButton(
            tooltip: tr('Повторювані записи'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RepeatsPage())),
          ),
          child: upcoming.isEmpty
              ? Text(tr('Немає запланованих записів до кінця періоду'), style: TextStyle(color: muted))
              : box([
                  for (final (d, r) in upcoming)
                    line(
                      '${r.template.note.isNotEmpty ? r.template.note : txnTitle(store, r.template)}, ${repeatLabel(r.every).toLowerCase()}',
                      money(store.shownAmount(r.template), store.shownCurrency(r.template)),
                      lead: '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}',
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
              shape: const StadiumBorder(),
              foregroundColor: scheme.onSurface,
            ),
            onPressed: () => exportForPf(context, month: month),
            icon: const Icon(Icons.table_view_rounded, color: Color(0xFF21A366)),
            label: Text(tr('Експорт даних в Excel')),
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
