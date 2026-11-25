import '../data/models.dart';
import '../l10n/l10n.dart';

/// Default categories with sub-categories (Money Manager style two levels),
/// named so that the PF dashboard groups them sensibly after export.
/// Sample categories for tests and demo data; the app starts with none.
List<Category> sampleCategories() {
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
  add(e, tr('Продукти'), '🛒', 0xFF34C759, [tr('Супермаркет'), tr('Ринок'), tr('Пекарня')]);
  add(e, tr('Кафе'), '🍜', 0xFFFF9F0A, [tr('Ресторан'), tr('Кава'), tr('Доставка')]);
  add(e, tr('Транспорт'), '🚇', 0xFF0A84FF, [tr('Пальне'), tr('Громадський'), tr('Таксі'), tr('Паркування')]);
  add(e, tr('Житло'), '🏠', 0xFF5E5CE6, [tr('Оренда'), tr('Ремонт'), tr('Меблі')]);
  add(e, tr('Комуналка'), '💡', 0xFFFFD60A, [tr('Електрика'), tr('Опалення'), tr('Інтернет'), tr('Мобільний')]);
  add(e, tr('Здоров\'я'), '💊', 0xFFFF375F, [tr('Аптека'), tr('Лікар'), tr('Спорт')]);
  add(e, tr('Одяг'), '👕', 0xFFBF5AF2);
  add(e, tr('Розваги'), '🎬', 0xFFFF6B6B, [tr('Кіно'), tr('Подорожі'), tr('Хобі')]);
  add(e, tr('Підписки'), '🔁', 0xFF64D2FF);
  add(e, tr('Подарунки'), '🎁', 0xFFFF2D55);
  add(e, tr('Освіта'), '📚', 0xFF30B0C7);
  add(e, tr('Непередбачене'), '⚠️', 0xFFFF9500);
  add(e, tr('Інше'), '📦', 0xFF8E8E93);
  add(inc, tr('Зарплата'), '💼', 0xFF30D158);
  add(inc, tr('Соц. виплати'), '🏛️', 0xFF0A84FF);
  add(inc, tr('Фриланс'), '💻', 0xFF5E5CE6);
  add(inc, tr('Відсотки'), '📈', 0xFF00C2A8);
  add(inc, tr('Подарунки'), '🎁', 0xFFFF9F0A);
  add(inc, tr('Інше'), '📦', 0xFF8E8E93);
  return out;
}

List<Account> defaultAccounts() => [
      Account(name: tr('Готівка'), kind: AccountKind.cash, currency: 'EUR', color: 0xFF30D158, sort: 0),
      Account(name: tr('Основна картка'), kind: AccountKind.card, currency: 'EUR', color: 0xFF1FB8E6, sort: 1),
      Account(name: tr('Ощадний рахунок'), kind: AccountKind.card, currency: 'EUR', color: 0xFF7ED957, sort: 2),
      Account(name: tr('Картка UAH'), kind: AccountKind.card, currency: 'UAH', color: 0xFF2B2B2B, sort: 3),
    ];
