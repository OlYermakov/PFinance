@Tags(['manual'])
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_app/data/db_factory_memory.dart';
import 'package:money_app/data/models.dart';
import 'package:money_app/data/repository.dart';
import 'package:money_app/state/app_store.dart';
import 'package:money_app/state/seed.dart';

/// Writes a demo backup (for screenshots) to $OUT.
void main() {
  test('demo backup', () async {
    final s = AppStore(Repository(await openMemoryDatabase(newId())));
    await s.load();
    for (final c in sampleCategories()) {
      await s.saveCategory(c);
    }
    final rnd = Random(3);
    final acc = s.accounts;
    final exp = s.categoriesOf(TxType.expense);
    final inc = s.categoriesOf(TxType.income);
    const notesBy = {
      'Продукти': ['Rewe', 'Aldi', 'Lidl', 'Edeka', ''],
      'Кафе': ['Starbucks', 'Wolt', 'Lieferando', ''],
      'Транспорт': ['Shell', 'DB', 'Uber', ''],
      "Здоров'я": ['Apotheke', 'dm', ''],
    };
    for (var m = 6; m <= 11; m++) {
      await s.saveTxn(Txn(type: TxType.income, amount: 320000 + rnd.nextInt(20000), accountId: acc[1].id, categoryId: inc[0].id, date: DateTime(2026, m, 1, 9)));
      await s.saveTxn(Txn(type: TxType.expense, amount: 85000, accountId: acc[1].id, categoryId: s.subcategoriesOf(exp[3].id).first.id, date: DateTime(2026, m, 3, 10), note: 'Miete'));
      for (var d = 1; d <= (m == 11 ? 21 : 28); d++) {
        for (var k = 0; k < rnd.nextInt(3); k++) {
          final c = exp[[0, 0, 0, 1, 1, 2, 2, 5, 7, 8, 12][rnd.nextInt(11)]];
          final subs = s.subcategoriesOf(c.id);
          await s.saveTxn(Txn(
            type: TxType.expense,
            amount: 300 + rnd.nextInt(7000),
            accountId: acc[rnd.nextInt(3)].id,
            categoryId: subs.isEmpty ? c.id : subs[rnd.nextInt(subs.length)].id,
            date: DateTime(2026, m, d, 8 + rnd.nextInt(12), rnd.nextInt(60)),
            note: (notesBy[c.name] ?? const [''])[rnd.nextInt((notesBy[c.name] ?? const ['']).length)],
          ));
        }
      }
    }
    await s.saveTxn(Txn(type: TxType.transfer, amount: 20000, accountId: acc[1].id, toAccountId: acc[0].id, date: DateTime(2026, 11, 14, 18)));
    await s.saveTxn(Txn(type: TxType.expense, amount: 120000, accountId: acc[3].id, categoryId: exp[10].id, date: DateTime(2026, 11, 12, 12), note: 'Курси'));
    await s.saveBudget(Budget(amount: 160000, currency: 'EUR'));
    await s.saveBudget(Budget(categoryId: exp[0].id, amount: 45000, currency: 'EUR'));
    await s.saveBudget(Budget(categoryId: exp[1].id, amount: 15000, currency: 'EUR'));
    File(Platform.environment['OUT']!).writeAsStringSync(await s.exportJson());
  });
}
