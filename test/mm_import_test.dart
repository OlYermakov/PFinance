import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_app/data/mm_import.dart';
import 'package:money_app/data/models.dart';
import 'package:money_app/data/sqlite_reader.dart';

void main() {
  final bytes = File('test/fixtures/mm_sample.mmbak').readAsBytesSync();

  test('sqlite reader walks interior pages and overflow', () {
    final db = SqliteReader(bytes);
    expect(db.rows('ZCATEGORY').length, 404);
    final t2 = db.rows('ZINOUTCOME').firstWhere((r) => r['ZUID'] == 'T2');
    expect((t2['ZMEMO'] as String).length, 6006);
    expect(t2['ZAMOUNT'], 12.5);
    expect(t2['Z_PK'], isA<int>());
  });

  test('imports a Money Manager backup', () {
    final res = importMoneyManager(bytes, {
      'prefs': {'themeId': 'x'},
    }, now: DateTime(2026, 6, 1));
    expect(res.stats, {'accounts': 2, 'categories': 3, 'transactions': 4, 'repeats': 2, 'budgets': 1});
    final b = res.backup;
    final txns = {for (final j in b['transactions'] as List) (j as Map)['id']: Txn.fromJson(j as Map<String, Object?>)};
    expect(txns['T1']!.type, TxType.income);
    expect(txns['T1']!.amount, 200000);
    expect(txns['T2']!.categoryId, 'C2');
    expect(txns['T2']!.note, 'Bread');
    expect(txns['T2']!.memo, startsWith('#trip'));
    expect(txns['T4']!.type, TxType.transfer);
    expect(txns['T4']!.toAccountId, 'A2');
    expect(txns['T4']!.toAmount, 11000);
    expect(txns['T6']!.type, TxType.income);
    expect(txns['T6']!.atBase, 500); // MM's own value in EUR on that day
    expect(txns['T6']!.atBaseCur, 'EUR');
    expect(txns['T1']!.atBase, isNull);
    expect(txns['T6']!.categoryId, isNull);
    final cats = [for (final j in b['categories'] as List) Category.fromJson(j as Map<String, Object?>)];
    expect(cats.firstWhere((c) => c.id == 'C2').parentId, 'C1');
    expect(cats.firstWhere((c) => c.id == 'C3').type, TxType.income);
    final settings = b['settings'] as Map;
    final prefs = settings['prefs'] as Map;
    expect(prefs['themeId'], 'x');
    expect(prefs['baseCurrency'], 'EUR');
    expect(prefs['rates'], {'USD': 0.9});
    expect(prefs['transferExpense'], ['A2']);
    final reps = [for (final j in settings['repeats'] as List) RepeatRule.fromJson(j as Map<String, Object?>)];
    expect(reps.first.every, RepeatEvery.fourWeeks);
    expect(reps[1].template.type, TxType.transfer);
    final budget = Budget.fromJson((b['budgets'] as List).single as Map<String, Object?>);
    expect(budget.amount, 10000); // MM's starting amount (period 0)
    expect(budget.amountAt(DateTime(2026, 6)), 30000); // in force in June 2026
    expect(budget.amountAt(DateTime(2027, 1)), 99900); // a later change
  });

  test('rejects other files', () {
    expect(() => importMoneyManager(bytes.sublist(0, 50), {}), throwsFormatException);
  });
}
