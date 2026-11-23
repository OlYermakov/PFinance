import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../state/app_store.dart';
import 'edit_transaction.dart' show openTxnEditor;
import 'format.dart';
import 'more_page.dart' show currencySymbol;
import 'stats_page.dart' show slicesFor, CategoryRow;
import 'theme.dart';
import 'widgets.dart';

const kindLabels = {
  AccountKind.cash: ('Готівка', Icons.payments_outlined),
  AccountKind.card: ('Картки', Icons.credit_card_rounded),
  AccountKind.bank: ('Банк', Icons.account_balance_outlined),
  AccountKind.savings: ('Заощадження', Icons.savings_outlined),
  AccountKind.credit: ('Кредити', Icons.credit_score_outlined),
  AccountKind.investment: ('Інвестиції', Icons.trending_up_rounded),
  AccountKind.other: ('Інше', Icons.wallet_outlined),
};

String groupOf(Account a) => (a.group?.trim().isNotEmpty ?? false) ? a.group!.trim() : kindLabels[a.kind]!.$1;

/// Change of an account's balance caused by [t].
int accountDelta(Txn t, String accountId) {
  var d = 0;
  if (t.accountId == accountId) d += t.type == TxType.income ? t.amount : -t.amount;
  if (t.type == TxType.transfer && t.toAccountId == accountId) d += t.toAmount ?? t.amount;
  return d;
}

// ---- Main list --------------------------------------------------------------------

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = AppPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final base = store.baseCurrency;
    final nw = store.netWorthBase();
    final groups = <String, List<Account>>{};
    for (final a in store.accounts.where((a) => !a.archived)) {
      groups.putIfAbsent(groupOf(a), () => []).add(a);
    }
    final hidden = store.accounts.where((a) => a.archived).length;
    final muted = scheme.onSurfaceVariant;

    Widget stat(String label, int v, Color? color) => Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 1),
          FittedBox(
            child: AnimatedMoney(
              v,
              base,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: color),
            ),
          ),
        ],
      ),
    );

    return SafeArea(
      bottom: false,
      // MM: the title and totals stay put; only the accounts scroll.
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 80),
                    Expanded(
                      child: Text(
                        'Рахунки',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 17),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Редагувати список',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _push(context, const EditAccountsPage()),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Новий рахунок',
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () => editAccount(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                GradientCard(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Row(
                    children: [
                      stat('Активи', nw.assets, incomeColor(context, store)),
                      stat('Пасиви', -nw.liabilities, p.expense),
                      stat('Разом', nw.total, null),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              children: [
                for (final e in groups.entries) ...[
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      var inc = 0, exc = 0;
                      for (final a in e.value) {
                        final v = store.toBase(store.balanceOf(a), a.currency);
                        if (a.includeInTotal) {
                          inc += v;
                        } else {
                          exc += v;
                        }
                      }
                      final anyInc = e.value.any((a) => a.includeInTotal), anyExc = e.value.any((a) => !a.includeInTotal);
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.key,
                                style: TextStyle(color: muted, fontWeight: FontWeight.w500, fontSize: 14),
                              ),
                            ),
                            if (anyExc) Text(money(exc, base), style: TextStyle(color: muted)),
                            if (anyExc && anyInc) const SizedBox(width: 16),
                            if (anyInc)
                              Text(
                                money(inc, base),
                                style: TextStyle(color: inc < 0 ? p.expense : incomeColor(context, store), fontWeight: FontWeight.w700),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  GlassCard(
                    radius: 22,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final (i, a) in e.value.indexed) ...[
                          if (i > 0) Divider(height: 1, indent: 16, color: Colors.white.withValues(alpha: 0.06)),
                          _AccountRow(account: a),
                        ],
                      ],
                    ),
                  ),
                ],
                if (hidden > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Center(
                      child: TextButton(onPressed: () => _push(context, const EditAccountsPage()), child: Text('Приховані рахунки: $hidden')),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Сірим показано рахунки, що не входять у загальні підсумки.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AuroraBackground(child: page)));

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final balance = store.balanceOf(account);
    final cycle = store.prefs.cardDisplay == 'balance' ? store.cardCycle(account) : null;
    final color = !account.includeInTotal
        ? scheme.onSurfaceVariant
        : balance < 0
        ? AppPalette.of(context).expense
        : incomeColor(context, store);
    return InkWell(
      onTap: () => _push(context, AccountPage(account: account)),
      onLongPress: () => editAccount(context, existing: account),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(color: Color(account.color), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  if (cycle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'До сплати ${money(-cycle.payable, account.currency)} · до ${cycle.due.day}.${cycle.due.month.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                    Text('Поточний цикл ${money(cycle.outstanding, account.currency)}', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            AnimatedMoney(
              balance,
              account.currency,
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kept for older call sites: opens the account page.
void openStatement(BuildContext context, Account a) => _push(context, AccountPage(account: a));

// ---- Account page: daily / monthly / annually -----------------------------------------

enum _AccView { day, month, year }

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.account});
  final Account account;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  _AccView _view = _AccView.day;
  late DateTime _month = StoreScope.read(context).currentPeriod;
  late int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final a = store.account(widget.account.id) ?? widget.account;
    final cur = a.currency;
    final p = AppPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;

    // Running balance after every record, oldest first.
    final all = store.txns.where((t) => t.accountId == a.id || t.toAccountId == a.id).toList()
      ..sort((x, y) {
        final c = x.date.compareTo(y.date);
        return c != 0 ? c : x.updatedAt.compareTo(y.updatedAt);
      });
    final after = <String, int>{};
    var run = a.initialBalance;
    for (final t in all) {
      run += accountDelta(t, a.id);
      after[t.id] = run;
    }
    int balanceAt(DateTime end) {
      var b = a.initialBalance;
      for (final t in all) {
        if (!t.date.isBefore(end)) break;
        b += accountDelta(t, a.id);
      }
      return b;
    }

    ({int dep, int wd}) sums(DateTime s, DateTime e) {
      var dep = 0, wd = 0;
      for (final t in all) {
        if (t.date.isBefore(s) || !t.date.isBefore(e)) continue;
        final d = accountDelta(t, a.id);
        if (d >= 0) {
          dep += d;
        } else {
          wd -= d;
        }
      }
      return (dep: dep, wd: wd);
    }

    final firstYear = all.isEmpty ? DateTime.now().year : all.first.date.year;
    final ({DateTime start, DateTime end}) range = switch (_view) {
      _AccView.day => store.periodRange(_month),
      _AccView.month => (start: store.periodRange(DateTime(_year, 1)).start, end: store.periodRange(DateTime(_year + 1, 1)).start),
      _AccView.year => (start: DateTime(firstYear), end: DateTime(DateTime.now().year + 2)),
    };
    final total = sums(range.start, range.end);
    final title = switch (_view) {
      _AccView.day =>
        store.prefs.monthStartDay == 1 ? monthTitle(_month) : '${shortDayMonth(range.start)} – ${shortDayMonth(range.end.subtract(const Duration(days: 1)))}',
      _AccView.month => '$_year',
      _AccView.year => '$firstYear – ${DateTime.now().year}',
    };

    Widget cell(String label, String v, Color? c) => Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(
              v,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: c),
            ),
          ),
        ],
      ),
    );
    String plain(int v) => money(v, cur).replaceAll(RegExp(r'[^\d\s ,.−+-]'), '').trim();

    final Widget body = switch (_view) {
      _AccView.day => _dayList(store, a, all, after, range, muted, p, scheme),
      _AccView.month => Column(
        children: [
          for (var m = 12; m >= 1; m--)
            () {
              final r = store.periodRange(DateTime(_year, m));
              final s = sums(r.start, r.end);
              final now = DateTime.now();
              return _PeriodRow(
                title: monthTitle(DateTime(_year, m)).split(' ').first,
                subtitle: '${r.start.day}.${r.start.month}. – ${r.end.subtract(const Duration(days: 1)).day}.${r.end.subtract(const Duration(days: 1)).month}.',
                dep: s.dep,
                wd: s.wd,
                end: balanceAt(r.end),
                currency: cur,
                current: !now.isBefore(r.start) && now.isBefore(r.end),
                onTap: () => setState(() {
                  _month = DateTime(_year, m);
                  _view = _AccView.day;
                }),
              );
            }(),
        ],
      ),
      _AccView.year => Column(
        children: [
          for (var y = DateTime.now().year + 1; y >= firstYear; y--)
            () {
              final s = sums(DateTime(y), DateTime(y + 1));
              return _PeriodRow(
                title: '$y',
                subtitle: '1.1.$y – 31.12.$y',
                dep: s.dep,
                wd: s.wd,
                end: balanceAt(DateTime(y + 1)),
                currency: cur,
                current: y == DateTime.now().year,
                onTap: () => setState(() {
                  _year = y;
                  _view = _AccView.month;
                }),
              );
            }(),
        ],
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(a.name),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Графік',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => _push(context, _AccountChartPage(account: a)),
          ),
          IconButton(
            tooltip: 'Змінити рахунок',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => editAccount(context, existing: a),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(tooltip: 'Новий запис', onPressed: () => openTxnEditor(context), child: const Icon(Icons.add_rounded)),
      // MM: period, tabs and totals stay put; only the records scroll.
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    if (_view != _AccView.year)
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () => setState(() => _view == _AccView.day ? _month = DateTime(_month.year, _month.month - 1) : _year--),
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_view != _AccView.year)
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () => setState(() => _view == _AccView.day ? _month = DateTime(_month.year, _month.month + 1) : _year++),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
                PillTabs<_AccView>(
                  value: _view,
                  items: const {_AccView.day: 'По днях', _AccView.month: 'По місяцях', _AccView.year: 'По роках'},
                  onChanged: (v) => setState(() => _view = v),
                ),
                const SizedBox(height: 8),
                GlassCard(
                  radius: 20,
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                  child: Row(
                    children: [
                      cell('Надходження', plain(total.dep), incomeColor(context, store)),
                      cell('Списання', plain(total.wd), p.expense),
                      cell('Разом', plain(total.dep - total.wd), null),
                      if (_view != _AccView.year) cell('Баланс', plain(balanceAt(range.end)), null),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [body]),
          ),
        ],
      ),
    );
  }

  Widget _dayList(
    AppStore store,
    Account a,
    List<Txn> all,
    Map<String, int> after,
    ({DateTime start, DateTime end}) r,
    Color muted,
    AppPalette p,
    ColorScheme scheme,
  ) {
    final list = all.where((t) => !t.date.isBefore(r.start) && t.date.isBefore(r.end)).toList().reversed.toList();
    if (list.isEmpty) return const EmptyState(icon: Icons.receipt_long_outlined, text: 'Записів за цей період немає');
    final days = <DateTime, List<Txn>>{};
    for (final t in list) {
      days.putIfAbsent(DateTime(t.date.year, t.date.month, t.date.day), () => []).add(t);
    }
    final cur = a.currency;
    return Column(
      children: [
        for (final e in days.entries) ...[
          GlassCard(
            radius: 20,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
                  child: Row(
                    children: [
                      Text('${e.key.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: (e.key.weekday >= 6 ? p.expense : scheme.primary).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(weekdayShort(e.key), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Text('${e.key.month.toString().padLeft(2, '0')}.${e.key.year}', style: TextStyle(color: muted, fontSize: 12)),
                      const Spacer(),
                      Text(
                        money(e.value.map((t) => accountDelta(t, a.id)).where((d) => d > 0).fold(0, (s, d) => s + d), cur),
                        style: TextStyle(color: scheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        money(-e.value.map((t) => accountDelta(t, a.id)).where((d) => d < 0).fold(0, (s, d) => s + d), cur),
                        style: TextStyle(color: p.expense, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                for (final t in e.value) ...[
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                  InkWell(
                    onTap: () => openTxnEditor(context, existing: t),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 92,
                            child: Text(
                              t.type == TxType.transfer
                                  ? 'Переказ'
                                  : [
                                      store.topCategory(t.categoryId)?.name ?? 'Без категорії',
                                      if (store.category(t.categoryId)?.parentId != null) store.category(t.categoryId)!.name,
                                    ].join('\n'),
                              style: TextStyle(color: muted, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.type == TxType.transfer
                                      ? '${store.account(t.accountId)?.name ?? '?'} → ${store.account(t.toAccountId)?.name ?? '?'}'
                                      : t.note,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                                if (t.type == TxType.transfer && t.note.isNotEmpty) Text(t.note, style: TextStyle(color: muted, fontSize: 13)),
                                if (t.type != TxType.transfer) Text(a.name, style: TextStyle(color: muted, fontSize: 13)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                money(accountDelta(t, a.id).abs(), cur),
                                style: TextStyle(fontWeight: FontWeight.w700, color: accountDelta(t, a.id) >= 0 ? incomeColor(context, store) : p.expense),
                              ),
                              Text('Баланс ${money(after[t.id] ?? 0, cur)}', style: TextStyle(color: muted, fontSize: 12)),
                            ],
                          ),
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
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.title,
    required this.subtitle,
    required this.dep,
    required this.wd,
    required this.end,
    required this.currency,
    required this.current,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final int dep;
  final int wd;
  final int end;
  final String currency;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = AppPalette.of(context);
    final muted = scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        radius: 18,
        tint: current ? scheme.primary : null,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(subtitle, style: TextStyle(color: muted, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  money(dep, currency),
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                ),
                Text(money(dep - wd, currency, sign: true), style: TextStyle(color: muted, fontSize: 12)),
              ],
            ),
            const SizedBox(width: 18),
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(wd, currency),
                    style: TextStyle(color: p.expense, fontWeight: FontWeight.w600),
                  ),
                  Text('(${money(end, currency)})', style: TextStyle(color: muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Balance chart -----------------------------------------------------------------

class _AccountChartPage extends StatefulWidget {
  const _AccountChartPage({required this.account});
  final Account account;

  @override
  State<_AccountChartPage> createState() => _AccountChartPageState();
}

class _AccountChartPageState extends State<_AccountChartPage> {
  bool _years = true;
  late DateTime _anchor = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final a = store.account(widget.account.id) ?? widget.account;
    final scheme = Theme.of(context).colorScheme;
    final p = AppPalette.of(context);
    final all = store.txns.where((t) => t.accountId == a.id || t.toAccountId == a.id).toList();
    int balanceAt(DateTime end) => a.initialBalance + all.where((t) => t.date.isBefore(end)).fold(0, (s, t) => s + accountDelta(t, a.id));

    // Points: the selected period in the middle-right, like Money Manager.
    final points = <({String label, DateTime start, DateTime end})>[
      for (var i = -4; i <= 2; i++)
        _years
            ? (label: '${_anchor.year + i}', start: DateTime(_anchor.year + i), end: DateTime(_anchor.year + i + 1))
            : () {
                final m = DateTime(_anchor.year, _anchor.month + i);
                final r = store.periodRange(m);
                return (label: monthTitle(m).substring(0, 3), start: r.start, end: r.end);
              }(),
    ];
    final values = [for (final pt in points) balanceAt(pt.end)];
    final sel = points[4];
    final inPeriod = all.where((t) => !t.date.isBefore(sel.start) && t.date.isBefore(sel.end));
    final inc = slicesFor(store, inPeriod.where((t) => t.type == TxType.income && t.accountId == a.id));
    final exp = slicesFor(store, inPeriod.where((t) => t.type == TxType.expense && t.accountId == a.id));
    final incTotal = inc.fold<int>(0, (s, x) => s + x.amount), expTotal = exp.fold<int>(0, (s, x) => s + x.amount);
    final base = store.baseCurrency;

    return Scaffold(
      appBar: AppBar(
        title: Text(a.name),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 96,
              child: PillTabs<bool>(value: _years, items: const {false: 'М', true: 'Р'}, onChanged: (v) => setState(() => _years = v)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(() => _anchor = _years ? DateTime(_anchor.year - 1, _anchor.month) : DateTime(_anchor.year, _anchor.month - 1)),
              ),
              Expanded(
                child: Text(
                  _years ? '${_anchor.year}' : monthTitle(_anchor),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => setState(() => _anchor = _years ? DateTime(_anchor.year + 1, _anchor.month) : DateTime(_anchor.year, _anchor.month + 1)),
              ),
            ],
          ),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: TrendLine(
              labels: [for (final pt in points) pt.label],
              values: values,
              selected: 4,
              currency: a.currency,
              color: scheme.primary,
              onTap: (i) => setState(() {
                final d = i - 4;
                _anchor = _years ? DateTime(_anchor.year + d, _anchor.month) : DateTime(_anchor.year, _anchor.month + d);
              }),
            ),
          ),
          const SizedBox(height: 14),
          for (final (label, slices, total, color) in [('Доходи', inc, incTotal, incomeColor(context, store)), ('Витрати', exp, expTotal, p.expense)]) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    money(total, base),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (slices.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text('Немає', style: TextStyle(color: scheme.onSurfaceVariant)),
              )
            else
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [for (final (i, s) in slices.indexed) CategoryRow(slice: s, total: total, currency: base, index: i)],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The app's line chart (account balance, category totals): value labels
/// over the points, gradient area, the selected period highlighted; tap a
/// point to open it. Every line chart in the app uses this.
class TrendLine extends StatelessWidget {
  const TrendLine({
    super.key,
    required this.labels,
    required this.values,
    required this.selected,
    required this.currency,
    required this.color,
    required this.onTap,
  });
  final List<String> labels;
  final List<int> values;
  final int selected;
  final String currency;
  final Color color;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth / labels.length;
        return Column(
          children: [
            GestureDetector(
              onTapUp: (d) => onTap((d.localPosition.dx / w).floor().clamp(0, labels.length - 1)),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(values.join(',')),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => CustomPaint(
                  size: Size(c.maxWidth, 190),
                  painter: _LinePainter(
                    values: values,
                    selected: selected,
                    color: color,
                    progress: t,
                    labelStyle: TextStyle(fontSize: 10, color: muted, fontFamily: 'Outfit', fontFamilyFallback: const ['Manrope']),
                    format: (v) => money(v, currency).replaceAll(RegExp(r'[^\d\s ,.−-]'), '').trim(),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final (i, l) in labels.indexed)
                  Expanded(
                    child: Text(
                      l,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: i == selected ? color : muted, fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.values, required this.selected, required this.color, required this.progress, required this.labelStyle, required this.format});
  final List<int> values;
  final int selected;
  final Color color;
  final double progress;
  final TextStyle labelStyle;
  final String Function(int) format;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce(math.max).toDouble(), minV = values.reduce(math.min).toDouble();
    final span = (maxV - minV).abs() < 1 ? 1.0 : maxV - minV;
    final w = size.width / values.length;
    const top = 24.0, bottom = 14.0;
    Offset pt(int i) => Offset(w * i + w / 2, top + (size.height - top - bottom) * (1 - (values[i] - minV) / span * progress));
    final grid = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var i = 0; i <= 4; i++) {
      final y = top + (size.height - top - bottom) * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    final fill = Path.from(path)
      ..lineTo(pt(values.length - 1).dx, size.height)
      ..lineTo(pt(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < values.length; i++) {
      final o = pt(i);
      canvas.drawCircle(o, i == selected ? 7 : 5, Paint()..color = color);
      if (i == selected) canvas.drawCircle(o, 3, Paint()..color = Colors.white);
      final tp = TextPainter(
        text: TextSpan(
          text: format(values[i]),
          style: labelStyle.copyWith(color: i == selected ? Colors.white : null, fontWeight: i == selected ? FontWeight.w700 : null),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w + 20);
      tp.paint(canvas, Offset(o.dx - tp.width / 2, o.dy - tp.height - 8));
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.progress != progress || old.values != values || old.selected != selected;
}

// ---- Settings list (MM: Рахунки → pencil = edit mode) -------------------------------------

/// Accounts by group in the Accounts-tab order, as list entries: a String is a
/// group header, an Account is a row.
List<Object> _groupedEntries(List<Account> accounts) {
  final groups = <String, List<Account>>{};
  for (final a in accounts) {
    groups.putIfAbsent(groupOf(a), () => []).add(a);
  }
  return [
    for (final e in groups.entries) ...[e.key, ...e.value],
  ];
}

/// Groups to offer when adding an account: those in use, else MM's defaults.
List<String> accountGroupNames(AppStore store) {
  final used = {for (final a in store.accounts) groupOf(a)};
  return used.isEmpty ? ['Готівка', 'Банк', 'Картки', 'Інвестиції'] : used.toList();
}

class EditAccountsPage extends StatefulWidget {
  const EditAccountsPage({super.key});

  @override
  State<EditAccountsPage> createState() => _EditAccountsPageState();
}

class _EditAccountsPageState extends State<EditAccountsPage> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final entries = _groupedEntries(store.accounts);
    final line = scheme.onSurface.withValues(alpha: 0.08);

    Widget header(String g) => Container(
      key: ValueKey('g:$g'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      alignment: Alignment.centerLeft,
      child: Text(g, style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
    );

    Widget row(Account a, int i) {
      final name = Text(
        a.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 16, color: a.archived ? scheme.onSurfaceVariant : scheme.onSurface),
      );
      return Material(
        key: ValueKey(a.id),
        color: panelColor(context),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: line)),
          ),
          child: _editing
              ? Row(
                  children: [
                    IconButton(tooltip: 'Видалити', icon: const MinusBadge(), onPressed: () => _delete(context, a)),
                    Expanded(child: name),
                    IconButton(
                      tooltip: a.archived ? 'Показувати' : 'Приховати',
                      icon: Icon(a.archived ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: scheme.onSurfaceVariant),
                      onPressed: () => store.saveAccount(a.copyWith(archived: !a.archived)),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
                        child: Icon(Icons.menu_rounded, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                )
              : InkWell(
                  onTap: () => editAccount(context, existing: a),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [Expanded(child: name)]),
                  ),
                ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: _editing ? IconButton(tooltip: 'Готово', icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _editing = false)) : null,
        title: Text(_editing ? 'Редаг.' : 'Рахунки'),
        centerTitle: true,
        actions: [
          if (!_editing) IconButton(tooltip: 'Редагувати', icon: const Icon(Icons.edit_outlined), onPressed: () => setState(() => _editing = true)),
          IconButton(tooltip: 'Новий рахунок', icon: const Icon(Icons.add_rounded), onPressed: () => editAccount(context)),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 40),
        buildDefaultDragHandles: false,
        itemCount: entries.length,
        // MM: a row can be dragged into another group; it then joins that group.
        onReorderItem: (from, to) async {
          final l = [...entries];
          final moved = l.removeAt(from);
          l.insert(to, moved);
          if (l.first is! String) {
            // Dropped above the first header: it belongs to the first group.
            final h = l.firstWhere((e) => e is String);
            l
              ..remove(h)
              ..insert(0, h);
          }
          String? g;
          var sort = 0;
          for (final e in l) {
            if (e is String) {
              g = e;
            } else if (e is Account) {
              if (e.sort != sort || groupOf(e) != g) await store.saveAccount(e.copyWith(sort: sort, group: g));
              sort++;
            }
          }
        },
        itemBuilder: (context, i) => switch (entries[i]) {
          final String g => header(g),
          final Account a => row(a, i),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, Account a) async {
    final store = StoreScope.read(context);
    final related = store.txns.where((t) => t.accountId == a.id || t.toAccountId == a.id).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Видалити «${a.name}»?'),
        content: Text(
          related.isEmpty
              ? 'Рахунок буде видалено.'
              : 'Разом із рахунком буде видалено ${related.length} його записів. Якщо записи треба зберегти, краще приховай рахунок (значок ока).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final t in related) {
      await store.deleteTxn(t);
    }
    await store.saveAccount(a.copyWith(deleted: true));
  }
}

// ---- Account form (MM: Додати) ------------------------------------------------------------

Future<void> editAccount(BuildContext context, {Account? existing}) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (_) => AuroraBackground(child: _AccountForm(existing: existing)),
  ),
);

class _AccountForm extends StatefulWidget {
  const _AccountForm({this.existing});
  final Account? existing;

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  late final AppStore store = StoreScope.read(context);
  late final Account? ex = widget.existing;
  late String group = ex == null ? (accountGroupNames(store).firstOrNull ?? 'Банк') : groupOf(ex!);
  late final name = TextEditingController(text: ex?.name ?? '');
  late String currency = ex?.currency ?? store.baseCurrency;
  late final amount = TextEditingController(text: ex == null || ex!.initialBalance == 0 ? '' : minorToInput(ex!.initialBalance, currency));
  late final note = TextEditingController(text: ex?.note ?? '');
  late final List<String> curList = {currency, store.baseCurrency, ...store.prefs.rates.keys}.toList();
  late int color = ex?.color ?? colorChoices.first;
  late bool include = ex?.includeInTotal ?? true;
  late bool card = ex?.isCard ?? false;
  late int settleDay = ex?.settleDay ?? 1;
  late int payDay = ex?.payDay ?? 15;
  late String? payFrom = ex?.payFrom;
  late final bool hasTxns = ex != null && store.txns.any((t) => t.accountId == ex!.id || t.toAccountId == ex!.id);

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final red = AppPalette.of(context).expense;
    final muted = scheme.onSurfaceVariant;
    InputDecoration plain([String? hint]) =>
        const InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ).copyWith(
          hintText: hint,
          hintStyle: TextStyle(color: muted.withValues(alpha: 0.6)),
        );
    const valueStyle = TextStyle(fontSize: 16);

    return Scaffold(
      appBar: AppBar(title: Text(ex == null ? 'Додати' : 'Редаг.'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _AccRow(
            label: 'Група',
            onTap: _pickGroup,
            child: Text(group, style: valueStyle),
          ),
          _AccRow(
            label: 'Назва',
            child: TextField(controller: name, autofocus: ex == null, style: valueStyle, decoration: plain()),
          ),
          _AccRow(
            label: 'Сума',
            child: TextField(
              controller: amount,
              style: valueStyle,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: plain('0'),
            ),
          ),
          _AccRow(
            label: 'Валюта',
            height: 56,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in curList) _curChip(c, red, muted),
                  if (!hasTxns) _chip('+', selected: false, red: red, muted: muted, onTap: _addCurrency),
                ],
              ),
            ),
          ),
          _AccRow(
            label: 'Деталі',
            child: TextField(controller: note, style: valueStyle, decoration: plain()),
          ),
          const SizedBox(height: 28),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: red,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _save,
            child: const Text('Зберегти', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
          ),
          const SizedBox(height: 28),
          Text('Додатково', style: TextStyle(fontSize: 14, color: muted)),
          const SizedBox(height: 8),
          ColorPickerRow(value: color, onChanged: (v) => setState(() => color = v)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Враховувати в підсумках'),
            value: include,
            onChanged: (v) => setState(() => include = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Картка з датою розрахунку'),
            subtitle: const Text('Кредитна картка: витрати сплачуються раз на місяць'),
            value: card,
            onChanged: (v) => setState(() => card = v),
          ),
          if (card) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: settleDay,
                    decoration: const InputDecoration(labelText: 'Дата розрахунку'),
                    items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d число'))],
                    onChanged: (v) => setState(() => settleDay = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: payDay,
                    decoration: const InputDecoration(labelText: 'Дата платежу'),
                    items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d число'))],
                    onChanged: (v) => setState(() => payDay = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: store.accounts.any((a) => a.id == payFrom) ? payFrom : null,
              decoration: const InputDecoration(labelText: 'Сплачується з рахунку'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('—')),
                for (final a in store.accounts.where((a) => a.id != ex?.id)) DropdownMenuItem<String?>(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => payFrom = v),
            ),
          ],
          if (hasTxns)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Валюту не можна змінити, бо в рахунку є записи.', style: TextStyle(fontSize: 12, color: muted)),
            ),
        ],
      ),
    );
  }

  Widget _curChip(String c, Color red, Color muted) => _chip(
    currencySymbol(c) == c ? c : currencySymbol(c),
    selected: c == currency,
    red: red,
    muted: muted,
    onTap: hasTxns ? null : () => setState(() => currency = c),
  );

  Widget _chip(String text, {required bool selected, required Color red, required Color muted, VoidCallback? onTap}) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 48),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? red : null,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? red : muted.withValues(alpha: 0.5)),
        ),
        child: Text(text, style: TextStyle(fontSize: 15, color: selected ? Colors.white : null)),
      ),
    ),
  );

  /// MM: an action sheet titled «Група рахунків» with the groups and Cancel.
  Future<void> _pickGroup() async {
    FocusScope.of(context).unfocus();
    final scheme = Theme.of(context).colorScheme;
    final groups = accountGroupNames(store);
    Widget sheetButton(String text, VoidCallback onTap, {bool bold = false}) => InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Center(
          child: Text(
            text,
            style: TextStyle(fontSize: 18, color: scheme.primary, fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
          ),
        ),
      ),
    );
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final panel = panelColor(context);
        final line = scheme.onSurface.withValues(alpha: 0.1);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Material(
                    color: panel,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text('Група рахунків', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                        ),
                        for (final g in groups) ...[Divider(height: 1, color: line), sheetButton(g, () => Navigator.pop(context, g))],
                        Divider(height: 1, color: line),
                        sheetButton('Нова група…', () => Navigator.pop(context, '\u0000new')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Material(color: panel, child: sheetButton('Скасувати', () => Navigator.pop(context), bold: true)),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (v == null || !mounted) return;
    if (v == '\u0000new') {
      final c = TextEditingController();
      final n = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Нова група'),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Назва групи'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
            FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('OK')),
          ],
        ),
      );
      if (n != null && n.isNotEmpty) setState(() => group = n);
      return;
    }
    setState(() => group = v);
  }

  Future<void> _addCurrency() async {
    final c = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Валюта'),
        children: [
          for (final c in currencies.where((c) => !curList.contains(c)))
            SimpleDialogOption(onPressed: () => Navigator.pop(context, c), child: Text('$c  ${currencySymbol(c)}')),
        ],
      ),
    );
    if (c == null) return;
    setState(() {
      curList.add(c);
      currency = c;
    });
  }

  void _save() {
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введи назву рахунку')));
      return;
    }
    final txt = amount.text.trim();
    final neg = txt.startsWith('-') || txt.startsWith('−');
    final v = parseMoney(neg ? txt.substring(1) : txt, currency) ?? 0;
    final base = ex ?? Account(name: '', currency: currency, sort: _sortFor(group));
    final kind = kindLabels.entries.where((e) => e.value.$1 == group).firstOrNull?.key ?? base.kind;
    store.saveAccount(
      base.copyWith(
        name: name.text.trim(),
        kind: kind,
        group: group,
        currency: currency,
        initialBalance: neg ? -v : v,
        note: note.text.trim(),
        color: color,
        includeInTotal: include,
        card: card ? (settleDay, payDay, payFrom) : (null, null, null),
      ),
    );
    Navigator.pop(context);
  }

  /// A new account goes to the end of its group, not the end of the list.
  int _sortFor(String g) {
    final all = store.accounts;
    final inGroup = all.where((a) => groupOf(a) == g).toList();
    if (inGroup.isEmpty) return all.isEmpty ? 0 : all.last.sort + 1;
    final after = inGroup.last.sort;
    // Shift the accounts behind the group down by one.
    for (final a in all.where((a) => a.sort > after)) {
      store.saveAccount(a.copyWith(sort: a.sort + 1));
    }
    return after + 1;
  }
}

/// MM form row: a grey label column and the value over a hairline.
class _AccRow extends StatelessWidget {
  const _AccRow({required this.label, required this.child, this.onTap, this.height = 50});
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 74,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(label, style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant)),
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: scheme.onSurface.withValues(alpha: 0.12))),
                ),
                alignment: Alignment.centerLeft,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
