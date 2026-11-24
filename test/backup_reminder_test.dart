import 'package:flutter_test/flutter_test.dart';
import 'package:money_app/data/db_factory_memory.dart';
import 'package:money_app/data/models.dart';
import 'package:money_app/data/repository.dart';
import 'package:money_app/state/app_store.dart';

void main() {
  test('backup reminder: due only with changes since an old enough backup', () async {
    final s = AppStore(Repository(await openMemoryDatabase(newId())));
    s.fetchRatesNow = (_) async => null;
    await s.load();
    expect(s.backupDue, isFalse, reason: 'no records yet');

    await s.saveTxn(Txn(type: TxType.expense, amount: 500, accountId: s.accounts.first.id, date: DateTime.now()));
    expect(s.backupDue, isTrue, reason: 'never backed up');

    await s.markBackedUp();
    expect(s.backupDue, isFalse, reason: 'just backed up');

    // A backup 8 days ago with a record changed since → due (weekly).
    await s.updatePrefs((p) => p.lastBackup = DateTime.now().subtract(const Duration(days: 8)).millisecondsSinceEpoch);
    expect(s.backupDue, isTrue);

    await s.updatePrefs((p) => p.backupRemindDays = 30);
    expect(s.backupDue, isFalse, reason: 'monthly');
    await s.updatePrefs((p) => p.backupRemindDays = 0);
    expect(s.backupDue, isFalse, reason: 'never');
  });
}
