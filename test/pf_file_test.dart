@Tags(['manual'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_app/data/db_factory_memory.dart';
import 'package:money_app/data/models.dart';
import 'package:money_app/data/repository.dart';
import 'package:money_app/state/app_store.dart';
import 'package:money_app/ui/export_pf.dart';

void main() {
  test('write sample PF export', () async {
    final s = AppStore(Repository(await openMemoryDatabase(newId())));
    await s.load();
    final acc = s.accounts;
    final cats = s.categoriesOf(TxType.expense);
    for (var d = 1; d <= 20; d++) {
      final c = cats[d % cats.length];
      final subs = s.subcategoriesOf(c.id);
      await s.saveTxn(Txn(type: TxType.expense, amount: 1000 + d * 137, accountId: acc[d % 3].id, categoryId: subs.isEmpty ? c.id : subs.first.id, date: DateTime(2026, 11, d, 12), note: 'n$d'));
    }
    await s.saveTxn(Txn(type: TxType.income, amount: 320000, accountId: acc[1].id, categoryId: s.categoriesOf(TxType.income).first.id, date: DateTime(2026, 11, 1, 9)));
    await s.saveTxn(Txn(type: TxType.transfer, amount: 20000, accountId: acc[1].id, toAccountId: acc[0].id, date: DateTime(2026, 11, 5, 9)));
    await s.saveTxn(Txn(type: TxType.expense, amount: 50000, accountId: acc[3].id, categoryId: cats.first.id, date: DateTime(2026, 11, 6, 9)));
    File(Platform.environment['OUT']!).writeAsBytesSync(buildPfWorkbook(s));
  });
}
