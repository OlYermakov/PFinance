import '../data/models.dart';

/// Default categories with sub-categories (Money Manager style two levels),
/// named so that the PF dashboard groups them sensibly after export.
List<Category> defaultCategories() {
  var i = 0;
  final out = <Category>[];
  void add(TxType type, String name, String emoji, int color, [List<String> subs = const []]) {
    final c = Category(name: name, type: type, emoji: emoji, color: color, sort: i++);
    out.add(c);
    var j = 0;
    for (final s in subs) {
      out.add(Category(name: s, type: type, parentId: c.id, emoji: emoji, color: color, sort: j++));
    }
  }

  const e = TxType.expense, inc = TxType.income;
  add(e, 'Продукти', '🛒', 0xFF34C759, ['Супермаркет', 'Ринок', 'Пекарня']);
  add(e, 'Кафе', '🍜', 0xFFFF9F0A, ['Ресторан', 'Кава', 'Доставка']);
  add(e, 'Транспорт', '🚇', 0xFF0A84FF, ['Пальне', 'Громадський', 'Таксі', 'Паркування']);
  add(e, 'Житло', '🏠', 0xFF5E5CE6, ['Оренда', 'Ремонт', 'Меблі']);
  add(e, 'Комуналка', '💡', 0xFFFFD60A, ['Електрика', 'Опалення', 'Інтернет', 'Мобільний']);
  add(e, 'Здоров\'я', '💊', 0xFFFF375F, ['Аптека', 'Лікар', 'Спорт']);
  add(e, 'Одяг', '👕', 0xFFBF5AF2);
  add(e, 'Розваги', '🎬', 0xFFFF6B6B, ['Кіно', 'Подорожі', 'Хобі']);
  add(e, 'Підписки', '🔁', 0xFF64D2FF);
  add(e, 'Подарунки', '🎁', 0xFFFF2D55);
  add(e, 'Освіта', '📚', 0xFF30B0C7);
  add(e, 'Непередбачене', '⚠️', 0xFFFF9500);
  add(e, 'Інше', '📦', 0xFF8E8E93);
  add(inc, 'Зарплата', '💼', 0xFF30D158);
  add(inc, 'Соц. виплати', '🏛️', 0xFF0A84FF);
  add(inc, 'Фриланс', '💻', 0xFF5E5CE6);
  add(inc, 'Відсотки', '📈', 0xFF00C2A8);
  add(inc, 'Подарунки', '🎁', 0xFFFF9F0A);
  add(inc, 'Інше', '📦', 0xFF8E8E93);
  return out;
}

List<Account> defaultAccounts() => [
      Account(name: 'Готівка', kind: AccountKind.cash, currency: 'EUR', color: 0xFF30D158, sort: 0),
      Account(name: 'Основна картка', kind: AccountKind.card, currency: 'EUR', color: 0xFF1FB8E6, sort: 1),
      Account(name: 'Ощадний рахунок', kind: AccountKind.card, currency: 'EUR', color: 0xFF7ED957, sort: 2),
      Account(name: 'Картка UAH', kind: AccountKind.card, currency: 'UAH', color: 0xFF2B2B2B, sort: 3),
    ];
