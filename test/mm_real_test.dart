@Tags(['manual'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_app/data/mm_import.dart';
import 'package:money_app/data/models.dart';

// Runs against a local Money Manager backup: MMBAK=/path/file.mmbak
void main() {
  test('import real mmbak', () {
    final path = Platform.environment['MMBAK'];
    if (path == null) return;
    final res = importMoneyManager(File(path).readAsBytesSync(), {}, now: DateTime(2026, 11, 22));
    // ignore: avoid_print
    print(res.stats);
    final txns = [for (final j in res.backup['transactions'] as List) Txn.fromJson(j as Map<String, Object?>)];
    final accs = [for (final j in res.backup['accounts'] as List) Account.fromJson(j as Map<String, Object?>)];
    for (final a in accs) {
      var b = 0;
      for (final t in txns) {
        if (t.accountId == a.id) b += t.type == TxType.income ? t.amount : -t.amount;
        if (t.toAccountId == a.id) b += t.toAmount ?? t.amount;
      }
      // ignore: avoid_print
      print('${a.name} ${a.group} ${a.kind.name} ${a.currency} ${b / 100}');
    }
    // ignore: avoid_print
    print((res.backup['settings'] as Map)['prefs']);
  });
}
