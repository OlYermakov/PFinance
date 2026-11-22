import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../state/app_store.dart';
import 'edit_transaction.dart' show openTxnEditor;
import 'format.dart';
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
          child: Column(children: [
            Text(label, style: TextStyle(fontSize: 13, color: muted)),
            const SizedBox(height: 2),
            FittedBox(child: AnimatedMoney(v, base, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color))),
          ]),
        );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Row(children: [
            const SizedBox(width: 96),
            Expanded(child: Text('Рахунки', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
            IconButton(tooltip: 'Редагувати список', icon: const Icon(Icons.edit_outlined), onPressed: () => _push(context, const _EditAccountsPage())),
            IconButton(tooltip: 'Новий рахунок', icon: const Icon(Icons.add_rounded), onPressed: () => editAccount(context)),
          ]),
          const SizedBox(height: 8),
          GradientCard(
            child: Row(children: [
              stat('Активи', nw.assets, scheme.primary),
              stat('Пасиви', -nw.liabilities, p.expense),
              stat('Разом', nw.total, null),
            ]),
          ),
          for (final e in groups.entries) ...[
            const SizedBox(height: 14),
            Builder(builder: (context) {
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
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Row(children: [
                  Expanded(child: Text(e.key, style: TextStyle(color: muted, fontWeight: FontWeight.w600, fontSize: 15))),
                  if (anyExc) Text(money(exc, base), style: TextStyle(color: muted)),
                  if (anyExc && anyInc) const SizedBox(width: 16),
                  if (anyInc) Text(money(inc, base), style: TextStyle(color: inc < 0 ? p.expense : scheme.primary, fontWeight: FontWeight.w700)),
                ]),
              );
            }),
            GlassCard(
              radius: 22,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final (i, a) in e.value.indexed) ...[
                  if (i > 0) Divider(height: 1, indent: 16, color: Colors.white.withValues(alpha: 0.06)),
                  _AccountRow(account: a),
                ],
              ]),
            ),
          ],
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Center(
                child: TextButton(
                  onPressed: () => _push(context, const _EditAccountsPage()),
                  child: Text('Приховані рахунки: $hidden'),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Сірим показано рахунки, що не входять у загальні підсумки.',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AuroraBackground(child: page)));

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final balance = store.balanceOf(account);
    final color = !account.includeInTotal
        ? scheme.onSurfaceVariant
        : balance < 0
            ? AppPalette.of(context).expense
            : scheme.primary;
    return InkWell(
      onTap: () => _push(context, AccountPage(account: account)),
      onLongPress: () => editAccount(context, existing: account),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(children: [
          Container(width: 4, height: 22, decoration: BoxDecoration(color: Color(account.color), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(child: Text(account.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          AnimatedMoney(balance, account.currency, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
        ]),
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
      _AccView.day => store.prefs.monthStartDay == 1
          ? monthTitle(_month)
          : '${shortDayMonth(range.start)} – ${shortDayMonth(range.end.subtract(const Duration(days: 1)))}',
      _AccView.month => '$_year',
      _AccView.year => '$firstYear – ${DateTime.now().year}',
    };

    Widget cell(String label, String v, Color? c) => Expanded(
          child: Column(children: [
            Text(label, style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 2),
            FittedBox(child: Text(v, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c))),
          ]),
        );
    String plain(int v) => money(v, cur).replaceAll(RegExp(r'[^\d\s ,.−+-]'), '').trim();

    final Widget body = switch (_view) {
      _AccView.day => _dayList(store, a, all, after, range, muted, p, scheme),
      _AccView.month => Column(children: [
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
        ]),
      _AccView.year => Column(children: [
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
        ]),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(a.name),
        centerTitle: true,
        actions: [
          IconButton(tooltip: 'Графік', icon: const Icon(Icons.bar_chart_rounded), onPressed: () => _push(context, _AccountChartPage(account: a))),
          IconButton(tooltip: 'Змінити рахунок', icon: const Icon(Icons.edit_outlined), onPressed: () => editAccount(context, existing: a)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Новий запис',
        onPressed: () => openTxnEditor(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), children: [
        Row(children: [
          if (_view != _AccView.year)
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => setState(() => _view == _AccView.day ? _month = DateTime(_month.year, _month.month - 1) : _year--),
            )
          else
            const SizedBox(width: 48),
          Expanded(child: Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          if (_view != _AccView.year)
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => setState(() => _view == _AccView.day ? _month = DateTime(_month.year, _month.month + 1) : _year++),
            )
          else
            const SizedBox(width: 48),
        ]),
        Row(children: [
          for (final (v, label) in [(_AccView.day, 'По днях'), (_AccView.month, 'По місяцях'), (_AccView.year, 'По роках')])
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _view = v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _view == v ? scheme.primary : Colors.white.withValues(alpha: 0.10), width: _view == v ? 3 : 1)),
                  ),
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: _view == v ? FontWeight.w700 : FontWeight.w500, color: _view == v ? null : muted)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        GlassCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Row(children: [
            cell('Надходження', plain(total.dep), scheme.primary),
            cell('Списання', plain(total.wd), p.expense),
            cell('Разом', plain(total.dep - total.wd), null),
            if (_view != _AccView.year) cell('Баланс', plain(balanceAt(range.end)), null),
          ]),
        ),
        const SizedBox(height: 12),
        body,
      ]),
    );
  }

  Widget _dayList(AppStore store, Account a, List<Txn> all, Map<String, int> after, ({DateTime start, DateTime end}) r, Color muted,
      AppPalette p, ColorScheme scheme) {
    final list = all.where((t) => !t.date.isBefore(r.start) && t.date.isBefore(r.end)).toList().reversed.toList();
    if (list.isEmpty) return const EmptyState(icon: Icons.receipt_long_outlined, text: 'Записів за цей період немає');
    final days = <DateTime, List<Txn>>{};
    for (final t in list) {
      days.putIfAbsent(DateTime(t.date.year, t.date.month, t.date.day), () => []).add(t);
    }
    final cur = a.currency;
    return Column(children: [
      for (final e in days.entries) ...[
        GlassCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Row(children: [
                Text('${e.key.day}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
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
                Text(money(e.value.map((t) => accountDelta(t, a.id)).where((d) => d > 0).fold(0, (s, d) => s + d), cur),
                    style: TextStyle(color: scheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Text(money(-e.value.map((t) => accountDelta(t, a.id)).where((d) => d < 0).fold(0, (s, d) => s + d), cur),
                    style: TextStyle(color: p.expense, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
            for (final t in e.value) ...[
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              InkWell(
                onTap: () => openTxnEditor(context, existing: t),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          t.type == TxType.transfer
                              ? '${store.account(t.accountId)?.name ?? '?'} → ${store.account(t.toAccountId)?.name ?? '?'}'
                              : t.note,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        if (t.type == TxType.transfer && t.note.isNotEmpty) Text(t.note, style: TextStyle(color: muted, fontSize: 13)),
                        if (t.type != TxType.transfer) Text(a.name, style: TextStyle(color: muted, fontSize: 13)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(accountDelta(t, a.id).abs(), cur),
                          style: TextStyle(fontWeight: FontWeight.w700, color: accountDelta(t, a.id) >= 0 ? scheme.primary : p.expense)),
                      Text('Баланс ${money(after[t.id] ?? 0, cur)}', style: TextStyle(color: muted, fontSize: 12)),
                    ]),
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
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(subtitle, style: TextStyle(color: muted, fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money(dep, currency), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
            Text(money(dep - wd, currency, sign: true), style: TextStyle(color: muted, fontSize: 12)),
          ]),
          const SizedBox(width: 18),
          SizedBox(
            width: 100,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(money(wd, currency), style: TextStyle(color: p.expense, fontWeight: FontWeight.w600)),
              Text('(${money(end, currency)})', style: TextStyle(color: muted, fontSize: 12)),
            ]),
          ),
        ]),
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
            child: SegmentedButton<bool>(
              segments: const [ButtonSegment(value: false, label: Text('М')), ButtonSegment(value: true, label: Text('Р'))],
              selected: {_years},
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (s) => setState(() => _years = s.first),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => setState(() => _anchor = _years ? DateTime(_anchor.year - 1, _anchor.month) : DateTime(_anchor.year, _anchor.month - 1)),
          ),
          Expanded(
            child: Text(_years ? '${_anchor.year}' : monthTitle(_anchor),
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => setState(() => _anchor = _years ? DateTime(_anchor.year + 1, _anchor.month) : DateTime(_anchor.year, _anchor.month + 1)),
          ),
        ]),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: _BalanceLine(
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
        for (final (label, slices, total, color) in [
          ('Доходи', inc, incTotal, incomeColor(context, store)),
          ('Витрати', exp, expTotal, p.expense),
        ]) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            child: Row(children: [
              Expanded(child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600))),
              Text(money(total, base), style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ]),
          ),
          if (slices.isEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: Text('Немає', style: TextStyle(color: scheme.onSurfaceVariant)))
          else
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final (i, s) in slices.indexed) CategoryRow(slice: s, total: total, currency: base, index: i),
              ]),
            ),
        ],
      ]),
    );
  }
}

class _BalanceLine extends StatelessWidget {
  const _BalanceLine({required this.labels, required this.values, required this.selected, required this.currency, required this.color, required this.onTap});
  final List<String> labels;
  final List<int> values;
  final int selected;
  final String currency;
  final Color color;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth / labels.length;
      return Column(children: [
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
        Row(children: [
          for (final (i, l) in labels.indexed)
            Expanded(
              child: Text(l,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: i == selected ? color : muted, fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500)),
            ),
        ]),
      ]);
    });
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
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)])
          .createShader(Offset.zero & size));
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < values.length; i++) {
      final o = pt(i);
      canvas.drawCircle(o, i == selected ? 7 : 5, Paint()..color = color);
      if (i == selected) canvas.drawCircle(o, 3, Paint()..color = Colors.white);
      final tp = TextPainter(
        text: TextSpan(text: format(values[i]), style: labelStyle.copyWith(color: i == selected ? Colors.white : null, fontWeight: i == selected ? FontWeight.w700 : null)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w + 20);
      tp.paint(canvas, Offset(o.dx - tp.width / 2, o.dy - tp.height - 8));
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.progress != progress || old.values != values || old.selected != selected;
}

// ---- Edit list: delete, hide, reorder ----------------------------------------------------

class _EditAccountsPage extends StatelessWidget {
  const _EditAccountsPage();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final list = store.accounts;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
        title: const Text('Рахунки'),
        centerTitle: true,
        actions: [IconButton(tooltip: 'Новий рахунок', icon: const Icon(Icons.add_rounded), onPressed: () => editAccount(context))],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        buildDefaultDragHandles: false,
        itemCount: list.length,
        onReorderItem: (from, to) async {
          final l = [...list];
          final moved = l.removeAt(from);
          l.insert(to, moved);
          for (final (i, a) in l.indexed) {
            if (a.sort != i) await store.saveAccount(a.copyWith(sort: i));
          }
        },
        itemBuilder: (context, i) {
          final a = list[i];
          return Padding(
            key: ValueKey(a.id),
            padding: const EdgeInsets.only(bottom: 6),
            child: GlassCard(
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                IconButton(
                  tooltip: 'Видалити',
                  icon: Icon(Icons.remove_circle_rounded, color: scheme.error),
                  onPressed: () => _delete(context, a),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => editAccount(context, existing: a),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: a.archived ? scheme.onSurfaceVariant : null)),
                        Text('${groupOf(a)} · ${a.currency}${a.includeInTotal ? '' : ' · не в підсумках'}',
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ]),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: a.archived ? 'Показувати' : 'Приховати',
                  icon: Icon(a.archived ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: scheme.onSurfaceVariant),
                  onPressed: () => store.saveAccount(a.copyWith(archived: !a.archived)),
                ),
                ReorderableDragStartListener(
                  index: i,
                  child: Padding(padding: const EdgeInsets.all(12), child: Icon(Icons.drag_handle_rounded, color: scheme.onSurfaceVariant)),
                ),
              ]),
            ),
          );
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
        content: Text(related.isEmpty
            ? 'Рахунок буде видалено.'
            : 'Разом із рахунком буде видалено ${related.length} його записів. Якщо записи треба зберегти, краще приховай рахунок (значок ока).'),
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

// ---- Account editor ---------------------------------------------------------------------

Future<void> editAccount(BuildContext context, {Account? existing}) async {
  final store = StoreScope.read(context);
  final name = TextEditingController(text: existing?.name ?? '');
  final group = TextEditingController(text: existing == null ? '' : groupOf(existing));
  final groups = {for (final a in store.accounts) groupOf(a), 'Готівка', 'Банк', 'Картки', 'Інвестиції'}.toList();
  var currency = existing?.currency ?? store.baseCurrency;
  var color = existing?.color ?? colorChoices.first;
  var include = existing?.includeInTotal ?? true;
  var archived = existing?.archived ?? false;
  final initial = TextEditingController(text: existing == null ? '' : minorToInput(existing.initialBalance, currency));
  final hasTxns = existing != null && store.txns.any((t) => t.accountId == existing.id || t.toAccountId == existing.id);

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? 'Новий рахунок' : 'Рахунок'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: name, autofocus: existing == null, decoration: const InputDecoration(labelText: 'Назва')),
              const SizedBox(height: 12),
              TextField(controller: group, decoration: const InputDecoration(labelText: 'Група'), onChanged: (_) => setState(() {})),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final g in groups)
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(g),
                    selected: group.text.trim() == g,
                    onSelected: (_) => setState(() => group.text = g),
                  ),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: currency,
                decoration: InputDecoration(labelText: 'Валюта', helperText: hasTxns ? 'Валюту не можна змінити, бо є записи' : null),
                items: [for (final c in {...currencies, currency}) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: hasTxns ? null : (v) => setState(() => currency = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: initial,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: InputDecoration(labelText: 'Початковий баланс', suffixText: currency),
              ),
              const SizedBox(height: 16),
              ColorPickerRow(value: color, onChanged: (v) => setState(() => color = v)),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Враховувати в підсумках'),
                value: include,
                onChanged: (v) => setState(() => include = v),
              ),
              if (existing != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Приховати'),
                  value: archived,
                  onChanged: (v) => setState(() => archived = v),
                ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              final txt = initial.text.trim();
              final neg = txt.startsWith('-') || txt.startsWith('−');
              final v = parseMoney(neg ? txt.substring(1) : txt, currency) ?? 0;
              final base = existing ?? Account(name: '', currency: currency, sort: store.accounts.length);
              final g = group.text.trim();
              final kind = kindLabels.entries.where((e) => e.value.$1 == g).firstOrNull?.key ?? base.kind;
              store.saveAccount(base.copyWith(
                name: name.text.trim(),
                kind: kind,
                group: g,
                currency: currency,
                initialBalance: neg ? -v : v,
                color: color,
                includeInTotal: include,
                archived: archived,
              ));
              Navigator.pop(context);
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    ),
  );
}
