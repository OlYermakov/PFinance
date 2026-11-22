import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_app/ui/format.dart' as fmt;
import 'package:money_app/data/db_factory_memory.dart';
import 'package:money_app/data/models.dart';
import 'package:money_app/data/repository.dart';
import 'package:money_app/state/app_store.dart';
import 'package:money_app/state/seed.dart';
import 'package:money_app/ui/edit_transaction.dart' show evalExpression;
import 'package:money_app/ui/export_pf.dart';
import 'package:money_app/ui/format.dart';

Future<AppStore> _store() async {
  final store = AppStore(Repository(await openMemoryDatabase(newId())))..fetchDayRates = (d, b) async => null;
  await store.load();
  for (final c in sampleCategories()) {
    await store.saveCategory(c);
  }
  return store;
}

void main() {
  test('amount calculator', () {
    expect(evalExpression('12,5+3×2'), 18.5);
    expect(evalExpression('100−20÷4'), 95);
    expect(evalExpression('12+'), 12);
    expect(evalExpression('5÷0'), isNull);
    expect(evalExpression(''), isNull);
  });

  test('repeating records: monthly with day clamp, catch-up, survives reload', () async {
    final s = await _store();
    final acc = s.accounts.first;
    final cat = s.categoriesOf(TxType.expense).first;
    final first = Txn(type: TxType.expense, amount: 1000, accountId: acc.id, categoryId: cat.id, date: DateTime(2026, 1, 31, 9), note: 'Netflix');
    await s.saveTxn(first);
    await s.saveRepeat(RepeatRule(template: first, every: RepeatEvery.month, start: first.date, lastDone: first.date));
    final made = await s.runRepeats(now: DateTime(2026, 4, 15));
    expect(made, 0); // saveRepeat already caught up to the real "now"
    final dates = s.txns.where((t) => t.note == 'Netflix').map((t) => t.date).toList()..sort();
    expect(dates.take(4), [DateTime(2026, 1, 31, 9), DateTime(2026, 2, 28, 9), DateTime(2026, 3, 31, 9), DateTime(2026, 4, 30, 9)]);
    final n = dates.length;
    await s.load();
    expect(s.repeats, hasLength(1));
    expect(s.txns.where((t) => t.note == 'Netflix'), hasLength(n)); // no duplicates on reopen
  });

  test('carry-over and tags', () async {
    final s = await _store();
    final acc = s.accounts.first;
    final inc = s.categoriesOf(TxType.income).first, exp = s.categoriesOf(TxType.expense).first;
    await s.saveTxn(Txn(type: TxType.income, amount: 50000, accountId: acc.id, categoryId: inc.id, date: DateTime(2026, 9, 1)));
    await s.saveTxn(Txn(type: TxType.expense, amount: 20000, accountId: acc.id, categoryId: exp.id, date: DateTime(2026, 9, 5), note: 'Квитки #Відпустка'));
    await s.saveTxn(Txn(type: TxType.expense, amount: 5000, accountId: acc.id, categoryId: exp.id, date: DateTime(2026, 10, 2), note: 'готель #відпустка'));
    expect(s.carryBefore(DateTime(2026, 10, 1)), 30000);
    final tags = s.tags();
    expect(tags.single.tag, 'відпустка');
    expect(tags.single.count, 2);
    expect(tags.single.sum, -25000);
  });

  test('seeds default accounts but no categories', () async {
    final s = AppStore(Repository(await openMemoryDatabase(newId())));
    await s.load();
    expect(s.accounts, hasLength(4));
    expect(s.baseCurrency, 'EUR');
    expect(s.categoriesOf(TxType.expense), isEmpty);
    expect(s.categoriesOf(TxType.income), isEmpty);
  });

  test('balances and transfers', () async {
    final s = await _store();
    final cash = s.accounts[0], card = s.accounts[1];
    final food = s.categoriesOf(TxType.expense).first;
    final salary = s.categoriesOf(TxType.income).first;
    final now = DateTime.now();
    await s.saveTxn(Txn(type: TxType.income, amount: 100000, accountId: card.id, categoryId: salary.id, date: now));
    await s.saveTxn(Txn(type: TxType.expense, amount: 2550, accountId: card.id, categoryId: food.id, date: now));
    await s.saveTxn(Txn(type: TxType.transfer, amount: 10000, accountId: card.id, toAccountId: cash.id, date: now));
    expect(s.balanceOf(card), 100000 - 2550 - 10000);
    expect(s.balanceOf(cash), 10000);
    expect(s.netWorth()['EUR'], 100000 - 2550);
    final t = s.totals(s.txnsInMonth(now));
    expect(t.income['EUR'], 100000);
    expect(t.expense['EUR'], 2550);
  });

  test('soft delete hides transaction', () async {
    final s = await _store();
    final t = Txn(type: TxType.expense, amount: 500, accountId: s.accounts[0].id, categoryId: 'x', date: DateTime.now());
    await s.saveTxn(t);
    await s.deleteTxn(t);
    expect(s.txns, isEmpty);
  });

  test('export / import round-trip', () async {
    final a = await _store();
    await a.saveTxn(Txn(type: TxType.expense, amount: 1234, accountId: a.accounts[0].id, categoryId: 'x', date: DateTime(2026, 5, 1)));
    await a.setTheme('ember');
    final json = await a.exportJson();
    final b = await _store();
    await b.importJson(json);
    expect(b.txns.single.amount, 1234);
    expect(b.themeId, 'ember');
    expect(b.accounts, hasLength(4));
  });

  test('month start day shifts the period', () async {
    final s = await _store();
    await s.updatePrefs((p) => p.monthStartDay = 25);
    expect(s.periodOf(DateTime(2026, 11, 24)), DateTime(2026, 10));
    expect(s.periodOf(DateTime(2026, 11, 25)), DateTime(2026, 11));
    final r = s.periodRange(DateTime(2026, 11));
    expect(r.start, DateTime(2026, 11, 25));
    expect(r.end, DateTime(2026, 12, 25));
  });

  test('conversion to base currency', () async {
    final s = await _store();
    final mono = s.accounts.firstWhere((a) => a.currency == 'UAH');
    await s.updatePrefs((p) => p.rates = {'UAH': 0.02});
    await s.saveTxn(Txn(type: TxType.expense, amount: 100000, accountId: mono.id, categoryId: 'x', date: DateTime.now()));
    expect(s.totalsBase(s.txns).expense, 2000); // 1000 UAH -> 20 EUR
  });

  test('PF workbook export has PF headers and transfer pairs', () async {
    final s = await _store();
    final a = s.accounts[0], b = s.accounts[1];
    final food = s.categoriesOf(TxType.expense).first;
    final sub = s.subcategoriesOf(food.id).first;
    await s.saveTxn(Txn(type: TxType.expense, amount: 1250, accountId: a.id, categoryId: sub.id, date: DateTime(2026, 11, 3, 10), note: 'Rewe'));
    await s.saveTxn(Txn(type: TxType.transfer, amount: 5000, accountId: b.id, toAccountId: a.id, date: DateTime(2026, 11, 4)));
    final x = Excel.decodeBytes(buildPfWorkbook(s));
    final rows = x.tables.values.first.rows;
    String v(int r, int c) => rows[r][c]?.value.toString() ?? '';
    expect(v(0, 0), 'Period');
    expect(v(0, 6), 'Income/Expense');
    expect(v(1, 0), '03.11.2026, 10:00:00');
    expect(v(1, 2), food.name);
    expect(v(1, 3), sub.name);
    expect(v(1, 6), 'Exp.');
    expect(v(1, 8), '12.5');
    expect(v(2, 6), 'Transfer-Out');
    expect(v(3, 6), 'Transfer-In');
    expect(v(3, 1), a.name);
  });

  test('money parsing', () {
    expect(parseMoney('1 234,50', 'UAH'), 123450);
    expect(parseMoney('12.3', 'USD'), 1230);
    expect(parseMoney('500', 'JPY'), 500);
    expect(parseMoney('abc', 'UAH'), isNull);
  });

  test('settings: symbol position, reset contents, repeats in advance', () async {
    fmt.currencyFront = true;
    expect(money(150, 'EUR'), startsWith('€'));
    fmt.currencyFront = false;
    expect(money(150, 'EUR'), endsWith('€'));

    final s = await _store();
    final cat = s.categoriesOf(TxType.expense).first;
    final acc = s.accounts.first;
    await s.saveTxn(Txn(type: TxType.expense, amount: 500, accountId: acc.id, categoryId: cat.id, date: DateTime.now()));
    await s.resetContents();
    expect(s.txns, isEmpty);
    expect(s.accounts, isNotEmpty);
    expect(s.categoriesOf(TxType.expense), isNotEmpty);

    // Weekly rule starting today: in advance creates the rest of the period too.
    await s.updatePrefs((p) => p.repeatInAdvance = true);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, 1, 9);
    await s.saveRepeat(RepeatRule(
      template: Txn(type: TxType.expense, amount: 100, accountId: acc.id, categoryId: cat.id, date: start),
      every: RepeatEvery.week,
      start: start,
    ));
    await s.runRepeats(now: start);
    expect(s.txns.length, greaterThanOrEqualTo(4));
  });

  test('foreign records use the rate of their day', () async {
    final s = await _store();
    final uah = s.accounts.firstWhere((a) => a.currency == 'UAH');
    final asked = <String>[];
    s.fetchDayRates = (d, base) async {
      asked.add('$base ${d.month}-${d.day}');
      return d.day == 1 ? {'UAH': 0.02} : {'UAH': 0.025};
    };
    await s.updatePrefs((p) => p.rates = {'UAH': 0.03, 'USD': 0.9});
    final day1 = Txn(type: TxType.expense, amount: 10000, accountId: uah.id, date: DateTime(2026, 3, 1, 10));
    final day2 = Txn(type: TxType.expense, amount: 10000, accountId: uah.id, date: DateTime(2026, 3, 2, 10));
    final future = Txn(type: TxType.expense, amount: 10000, accountId: uah.id, date: DateTime(2100, 1, 1));
    for (final t in [day1, day2, future]) {
      await s.saveTxn(t);
    }
    await s.fillDayRates(now: DateTime(2026, 6, 1));
    int v(Txn t) => s.baseAmount(s.txns.firstWhere((x) => x.id == t.id));
    expect(v(day1), 200); // 100 ₴ × 0.02
    expect(v(day2), 250);
    expect(v(future), 300); // not yet: current rate
    // Cached: a second run asks for nothing new.
    final n = asked.length;
    await s.fillDayRates(now: DateTime(2026, 6, 1));
    expect(asked.length, n);
    // Editing the amount re-stamps at the same day's rate.
    await s.saveTxn(Txn(id: day1.id, type: TxType.expense, amount: 20000, accountId: uah.id, date: day1.date));
    await s.fillDayRates(now: DateTime(2026, 6, 1));
    expect(v(day1), 400);
  });

  test('transfers into a transfer-expense account count as expense', () async {
    final s = await _store();
    final a = s.accounts[0], b = s.accounts[1];
    await s.updatePrefs((p) => p.transferExpense = [b.id]);
    final now = DateTime.now();
    final into = Txn(type: TxType.transfer, amount: 1000, accountId: a.id, toAccountId: b.id, date: now);
    final back = Txn(type: TxType.transfer, amount: 300, accountId: b.id, toAccountId: a.id, date: now);
    final t = s.totalsBase([into, back]);
    expect(t.expense, s.baseAmount(into));
    expect(t.income, s.baseAmount(back));
    await s.updatePrefs((p) => p.transferExpense = []);
    expect(s.totalsBase([into, back]).expense, 0);
  });
}
