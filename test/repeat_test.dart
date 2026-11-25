import 'package:flutter_test/flutter_test.dart';
import 'package:money_app/data/models.dart';

void main() {
  final t = Txn(type: TxType.expense, amount: 100, accountId: 'a', date: DateTime(2026, 1, 1));
  List<DateTime> first(RepeatEvery e, DateTime start, int n) => RepeatRule(template: t, every: e, start: start).occurrences.take(n).toList();

  test('weekdays skip Saturday and Sunday', () {
    // 2026-11-20 is a Friday.
    expect(first(RepeatEvery.weekdays, DateTime(2026, 11, 20), 3), [DateTime(2026, 11, 20), DateTime(2026, 11, 23), DateTime(2026, 11, 24)]);
  });

  test('weekends keep only Saturday and Sunday', () {
    expect(first(RepeatEvery.weekends, DateTime(2026, 11, 20), 3), [DateTime(2026, 11, 21), DateTime(2026, 11, 22), DateTime(2026, 11, 28)]);
  });

  test('end of month is the last day of each month', () {
    expect(first(RepeatEvery.monthEnd, DateTime(2026, 1, 10), 3), [DateTime(2026, 1, 31), DateTime(2026, 2, 28), DateTime(2026, 3, 31)]);
  });

  test('every 6 months clamps the day', () {
    expect(first(RepeatEvery.halfYear, DateTime(2026, 8, 31), 2), [DateTime(2026, 8, 31), DateTime(2027, 2, 28)]);
  });

  test('upcoming leaves out what is already created and what has ended', () {
    final r = RepeatRule(
      template: t,
      every: RepeatEvery.day,
      start: DateTime(2026, 11, 20, 9),
      end: DateTime(2026, 11, 28),
      lastDone: DateTime(2026, 11, 26, 9),
    );
    // Now is the 25th, 10:00: the 26th was already created in advance.
    // The end is the 28th at 0:00, so the 28th at 9:00 is past it.
    expect(r.upcoming(DateTime(2026, 11, 25, 10), DateTime(2026, 11, 30)), [DateTime(2026, 11, 27, 9)]);
    // Later today counts as upcoming too.
    final m = RepeatRule(template: t, every: RepeatEvery.month, start: DateTime(2026, 10, 25, 18));
    expect(m.upcoming(DateTime(2026, 11, 25, 10), DateTime(2026, 11, 27)), [DateTime(2026, 11, 25, 18)]);
    expect(m.upcoming(DateTime(2026, 11, 25, 19), DateTime(2026, 11, 27)), isEmpty);
  });
}
