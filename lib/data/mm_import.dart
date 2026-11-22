// Import of a Money Manager backup (.mmbak, an SQLite database).
//
// Converts accounts, categories, records, currencies with rates, repeating
// records and monthly budgets into a PFinance backup snapshot, which the app
// then restores like its own backup.

import 'dart:typed_data';

import '../ui/format.dart' show decimalsOf;
import 'models.dart';
import 'sqlite_reader.dart';

class MmImportResult {
  MmImportResult(this.backup, this.stats);

  /// A snapshot in the app's own backup format.
  final Map<String, Object?> backup;

  /// Counts of imported items, for the confirmation message.
  final Map<String, int> stats;
}

/// MM stores dates as seconds since 2001-01-01 (Apple reference date).
DateTime _appleDate(num s) => DateTime.fromMillisecondsSinceEpoch(((s + 978307200) * 1000).round());

bool _active(Object? isDel) => isDel == null || isDel == 0;

String _s(Object? v) => v == null ? '' : '$v';

int _minor(num v, String currency) {
  var x = v.abs().toDouble();
  for (var i = 0; i < decimalsOf(currency); i++) {
    x *= 10;
  }
  return x.round();
}

AccountKind _kindOf(String groupId, String groupName) {
  final n = groupName.toLowerCase();
  if (groupId == '8' || n.contains('інвест') || n.contains('инвест')) return AccountKind.investment;
  if (groupId == '1' || n.contains('банк')) return AccountKind.bank;
  if (groupId == '2' || groupId == '3' || n.contains('карт')) return AccountKind.card;
  if (groupId == '4' || n.contains('депозит')) return AccountKind.savings;
  if (groupId == '9' || groupId == '5' || n.contains('кредит')) return AccountKind.credit;
  if (groupId == '11' || n.contains('гаман') || n.contains('готів') || n.contains('кошел')) return AccountKind.cash;
  return AccountKind.other;
}

RepeatEvery? _every(int type) => switch (type) {
  0 => RepeatEvery.day,
  1 => RepeatEvery.month,
  3 => RepeatEvery.quarter,
  15 => RepeatEvery.fourWeeks,
  17 => RepeatEvery.year,
  _ => null,
};

const _palette = [0xFF4F7CFF, 0xFF34C759, 0xFFFF9500, 0xFFAF52DE, 0xFFFF2D55, 0xFF5AC8FA, 0xFFFFCC00, 0xFF30B0C7];

/// [settings] are the current app settings; display preferences are kept and
/// the base currency, rates, repeats and transfer-expense list are replaced.
MmImportResult importMoneyManager(Uint8List bytes, Map<String, Object?> settings, {DateTime? now}) {
  final db = SqliteReader(bytes);
  for (final t in ['ZASSET', 'ZCATEGORY', 'ZINOUTCOME']) {
    if (!db.hasTable(t)) throw const FormatException('Це не резервна копія Money Manager');
  }
  now ??= DateTime.now();

  // ---- Currencies ----------------------------------------------------------
  final curIso = <String, String>{};
  var base = 'EUR';
  final rates = <String, double>{};
  for (final c in db.rows('ZCURRENCY')) {
    final iso = _s(c['ZISO']);
    if (iso.isEmpty) continue;
    curIso[_s(c['ZUID'])] = iso;
    if (c['ZISMAINCURRENCY'] == 1) base = iso;
  }
  for (final c in db.rows('ZCURRENCY')) {
    final iso = _s(c['ZISO']);
    final r = c['ZRATE'];
    if (iso.isNotEmpty && iso != base && r is num && r > 0) rates[iso] = r.toDouble();
  }
  String isoOf(Object? uid) {
    final u = _s(uid);
    return curIso[u] ?? (u.contains('_') ? u.split('_').last : base);
  }

  // ---- Accounts ------------------------------------------------------------
  final groups = {for (final g in db.rows('ZASSETGROUP')) _s(g['ZUID']): _s(g['ZASSETGROUPNAME'])};
  final accounts = <Account>[];
  final transferExpense = <String>[];
  final assetRows = db.rows('ZASSET').where((a) => _active(a['ZISDEL'])).toList()
    ..sort((a, b) => ((a['ZORDER'] as num?) ?? 0).compareTo((b['ZORDER'] as num?) ?? 0));
  for (final a in assetRows) {
    final gid = _s(a['ZGROUPUID']);
    final acc = Account(
      id: _s(a['ZUID']),
      name: _s(a['ZNICNAME']),
      kind: _kindOf(gid, groups[gid] ?? ''),
      currency: isoOf(a['ZCURRENCYUID']),
      color: _palette[accounts.length % _palette.length],
      sort: accounts.length,
      group: groups[gid],
      // MM card accounts carry the statement and payment days
      settleDay: int.tryParse(_s(a['ZCARD_DAYFIN'])),
      payDay: int.tryParse(_s(a['ZCARD_DAYPAY'])),
      payFrom: _s(a['ZCARDASSETUID']).isEmpty || a['ZCARDASSETUID'] == a['ZUID'] ? null : _s(a['ZCARDASSETUID']),
    );
    accounts.add(acc);
    if (a['ZTRANSFEREXPENSE'] == 1) transferExpense.add(acc.id);
  }
  final accById = {for (final a in accounts) a.id: a};

  // ---- Categories ----------------------------------------------------------
  final catRows = db.rows('ZCATEGORY').where((c) => _active(c['ZISDEL'])).toList()
    ..sort((a, b) => ((a['ZORDER'] as num?) ?? 0).compareTo((b['ZORDER'] as num?) ?? 0));
  final catIds = {for (final c in catRows) _s(c['ZUID'])};
  final categories = <Category>[];
  final sortIn = <String, int>{};
  for (final c in catRows) {
    final type = _s(c['ZDOTYPE']) == '0' ? TxType.income : TxType.expense;
    var parent = _s(c['ZPUID']);
    if (parent.isEmpty || parent == '0' || !catIds.contains(parent)) parent = '';
    final key = '${type.name}/$parent';
    final sort = sortIn[key] = (sortIn[key] ?? -1) + 1;
    categories.add(
      Category(
        id: _s(c['ZUID']),
        name: _s(c['ZNAME']).trim(),
        type: type,
        parentId: parent.isEmpty ? null : parent,
        color: _palette[categories.length % _palette.length],
        sort: sort,
      ),
    );
  }

  // ---- Records -------------------------------------------------------------
  final rows = db.rows('ZINOUTCOME').where((r) => _active(r['ZISDEL']) && accById.containsKey(_s(r['ZASSETUID']))).toList();
  final incoming = <String, Map<String, Object?>>{};
  for (final r in rows) {
    if (_s(r['ZDO_TYPE']) == '4' && _s(r['ZTXUIDTRANS']).isNotEmpty) incoming[_s(r['ZTXUIDTRANS'])] = r;
  }
  final txns = <Txn>[];
  for (final r in rows) {
    final code = _s(r['ZDO_TYPE']);
    final acc = accById[_s(r['ZASSETUID'])]!;
    final amountAcc = (r['ZAMOUNTACCOUNT'] ?? r['ZAMOUNTSUB'] ?? r['ZAMOUNT']) as num? ?? 0;
    final date = r['ZDATE'] is num ? _appleDate(r['ZDATE'] as num) : DateTime.tryParse(_s(r['ZTXDATESTR'])) ?? now;
    final parts = [_s(r['ZCONTENT']).trim(), _s(r['ZMEMO']).trim()].where((s) => s.isNotEmpty);
    var note = parts.join(' ');
    final txCur = isoOf(r['ZCURRENCYUID']);
    final sub = r['ZAMOUNTSUB'];
    if (txCur != acc.currency && sub is num && code != '3' && code != '4') {
      note = [note, '(${formatPlain(sub, txCur)})'].where((s) => s.isNotEmpty).join(' ');
    }
    final cat = _s(r['ZCATEGORYUID']);
    // MM keeps the value in the main currency at the rate of the record's day.
    final mainAmt = r['ZAMOUNT'];
    final atBase = acc.currency != base && mainAmt is num ? _minor(mainAmt, base) : null;
    switch (code) {
      case '0' || '1' || '7' || '8':
        txns.add(
          Txn(
            id: _s(r['ZUID']),
            type: code == '0' || code == '7' ? TxType.income : TxType.expense,
            amount: _minor(amountAcc, acc.currency),
            accountId: acc.id,
            categoryId: catIds.contains(cat) ? cat : null,
            date: date,
            note: note,
            atBase: atBase,
            atBaseCur: atBase == null ? null : base,
          ),
        );
      case '3':
        final inc = incoming[_s(r['ZTXUIDTRANS'])];
        final to = accById[_s(inc?['ZASSETUID'] ?? r['ZTOASSETUID'])];
        if (to == null) continue;
        final toAmt = inc == null ? null : (inc['ZAMOUNTACCOUNT'] ?? inc['ZAMOUNTSUB']) as num?;
        txns.add(
          Txn(
            id: _s(r['ZUID']),
            type: TxType.transfer,
            amount: _minor(amountAcc, acc.currency),
            accountId: acc.id,
            toAccountId: to.id,
            toAmount: to.currency != acc.currency && toAmt != null ? _minor(toAmt, to.currency) : null,
            date: date,
            note: note,
            atBase: atBase,
            atBaseCur: atBase == null ? null : base,
          ),
        );
      default:
        break; // '4' is the incoming half of a transfer
    }
  }

  // ---- Repeating records ---------------------------------------------------
  final repeats = <RepeatRule>[];
  if (db.hasTable('ZREPEATTRANSACTION')) {
    for (final r in db.rows('ZREPEATTRANSACTION')) {
      if (!_active(r['ZISDEL'])) continue;
      final acc = accById[_s(r['ZASSETUID'])];
      final every = _every((r['ZREPEATTYPE'] as num?)?.toInt() ?? 1);
      final next = r['ZNEXTDATE'];
      if (acc == null || every == null || next is! num) continue;
      final code = _s(r['ZDOTYPE']);
      final to = accById[_s(r['ZTOASSETUID'])];
      final type = code == '0' ? TxType.income : (code == '3' ? TxType.transfer : TxType.expense);
      if (type == TxType.transfer && to == null) continue;
      final start = DateTime.fromMillisecondsSinceEpoch(next.toInt());
      final end = r['ZENDDATE'];
      final cat = _s(r['ZCATEGORYUID']);
      final note = [_s(r['ZPAYEE']).trim(), _s(r['ZMEMO']).trim()].where((s) => s.isNotEmpty).join(' ');
      repeats.add(
        RepeatRule(
          template: Txn(
            type: type,
            amount: _minor((r['ZAMOUNTSUB'] as num?) ?? 0, acc.currency),
            accountId: acc.id,
            toAccountId: type == TxType.transfer ? to!.id : null,
            categoryId: type != TxType.transfer && catIds.contains(cat) ? cat : null,
            date: start,
            note: note,
          ),
          every: every,
          start: start,
          end: end is num && end > 0 ? DateTime.fromMillisecondsSinceEpoch(end.toInt()) : null,
        ),
      );
    }
  }

  // ---- Monthly budgets -----------------------------------------------------
  final budgets = <Budget>[];
  if (db.hasTable('ZBUDGET') && db.hasTable('ZBUDGETAMOUNT')) {
    final amounts = <String, Map<int, num>>{};
    for (final a in db.rows('ZBUDGETAMOUNT')) {
      if (!_active(a['ZISDEL']) || a['ZAMOUNT'] is! num) continue;
      (amounts[_s(a['ZBUDGETUID'])] ??= {})[(a['ZBUDGETPERIOD'] as num?)?.toInt() ?? 0] = a['ZAMOUNT'] as num;
    }
    final month = now.year * 100 + now.month;
    for (final b in db.rows('ZBUDGET')) {
      final target = _s(b['ZTARGETUID']);
      final uid = _s(b['ZUID']);
      // monthly (6), plain category budgets only (UID "<cat>_<type>_0_0_6")
      if (!_active(b['ZISDEL']) || b['ZPERIODTYPEINT'] != 6 || !catIds.contains(target)) continue;
      final seg = uid.split('_');
      if (seg.length >= 5 && seg[seg.length - 2] != '0') continue;
      final m = amounts[uid];
      if (m == null) continue;
      final periods = m.keys.where((p) => p > 0 && p <= month).toList()..sort();
      final amount = periods.isNotEmpty ? m[periods.last]! : m[0];
      if (amount == null || amount <= 0) continue;
      budgets.add(Budget(id: 'mm-$uid', categoryId: target, amount: _minor(amount, base), currency: base));
    }
  }

  final prefs = Map<String, Object?>.from((settings['prefs'] as Map?) ?? const {});
  prefs['baseCurrency'] = base;
  prefs['rates'] = rates;
  prefs['transferExpense'] = transferExpense;

  final backup = <String, Object?>{
    'format': 'money_app_backup',
    'version': 1,
    'exportedAt': now.toIso8601String(),
    'accounts': [for (final a in accounts) a.toJson()],
    'categories': [for (final c in categories) c.toJson()],
    'transactions': [for (final t in txns) t.toJson()],
    'budgets': [for (final b in budgets) b.toJson()],
    'settings': {
      ...settings,
      'prefs': prefs,
      'repeats': [for (final r in repeats) r.toJson()],
      'seeded': true,
    },
  };
  return MmImportResult(backup, {
    'accounts': accounts.length,
    'categories': categories.length,
    'transactions': txns.length,
    'repeats': repeats.length,
    'budgets': budgets.length,
  });
}

/// "500 UAH" style, without the app's number formatting.
String formatPlain(num v, String currency) {
  final s = v.abs().toStringAsFixed(decimalsOf(currency));
  return '${s.endsWith('.00') ? s.substring(0, s.length - 3) : s} $currency';
}
