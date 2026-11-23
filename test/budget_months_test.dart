import 'package:flutter_test/flutter_test.dart';
import 'package:money_app/data/models.dart';

void main() {
  final b = Budget(amount: 100, currency: 'EUR', months: {202501: 900});

  test('changes stay in force until the next one', () {
    expect(b.amountAt(DateTime(2024, 12)), 100);
    expect(b.amountAt(DateTime(2026, 11)), 900);
  });

  test('one month only keeps the following months', () {
    final x = b.withMonth(DateTime(2026, 11), 1300);
    expect(x.amountAt(DateTime(2026, 10)), 900);
    expect(x.amountAt(DateTime(2026, 11)), 1300);
    expect(x.amountAt(DateTime(2026, 12)), 900);
  });

  test('the default applies from the given month on', () {
    final x = b.withMonth(DateTime(2027, 3), 50).withDefault(700, DateTime(2026, 11));
    expect(x.amountAt(DateTime(2026, 10)), 900);
    expect(x.amountAt(DateTime(2026, 11)), 700);
    expect(x.amountAt(DateTime(2027, 3)), 700);
  });

  test('months survive JSON', () {
    expect(Budget.fromJson(b.toJson()).amountAt(DateTime(2026, 1)), 900);
  });
}
