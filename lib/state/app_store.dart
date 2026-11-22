import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../ui/format.dart' as fmt;
import 'seed.dart';

enum StartPage { day, calendar, month, summary, stats, accounts }

/// User preferences (the "Більше → Налаштування" screen).
class Prefs {
  String themeId = 'aurora';
  ThemeMode themeMode = ThemeMode.dark;
  String baseCurrency = 'EUR';
  int monthStartDay = 1; // 1..28, e.g. salary day
  bool weekStartsMonday = true;
  StartPage startPage = StartPage.day;
  bool incomeBlue = false; // false: green/red, true: blue/red
  bool showDecimals = true;
  bool subcategories = true;
  bool noteSuggestions = true;
  bool continueAfterSave = false;
  bool carryOver = false; // add the balance of earlier periods to "Разом"
  bool copyToToday = true; // a copied record gets today's date (else the original date)
  String? pin; // 4 digits; local convenience lock, not encryption
  Map<String, double> rates = {}; // 1 unit of currency = rate × base

  Map<String, Object?> toJson() => {
        'themeId': themeId,
        'themeMode': themeMode.name,
        'baseCurrency': baseCurrency,
        'monthStartDay': monthStartDay,
        'weekStartsMonday': weekStartsMonday,
        'startPage': startPage.name,
        'incomeBlue': incomeBlue,
        'showDecimals': showDecimals,
        'subcategories': subcategories,
        'noteSuggestions': noteSuggestions,
        'continueAfterSave': continueAfterSave,
        'carryOver': carryOver,
        'copyToToday': copyToToday,
        'pin': pin,
        'rates': rates,
      };

  void apply(Map<String, Object?> j) {
    themeId = j['themeId'] as String? ?? themeId;
    themeMode = ThemeMode.values.asNameMap()[j['themeMode']] ?? themeMode;
    baseCurrency = j['baseCurrency'] as String? ?? baseCurrency;
    monthStartDay = (j['monthStartDay'] as num?)?.toInt() ?? monthStartDay;
    weekStartsMonday = j['weekStartsMonday'] as bool? ?? weekStartsMonday;
    startPage = StartPage.values.asNameMap()[j['startPage']] ?? startPage;
    incomeBlue = j['incomeBlue'] as bool? ?? incomeBlue;
    showDecimals = j['showDecimals'] as bool? ?? showDecimals;
    subcategories = j['subcategories'] as bool? ?? subcategories;
    noteSuggestions = j['noteSuggestions'] as bool? ?? noteSuggestions;
    continueAfterSave = j['continueAfterSave'] as bool? ?? continueAfterSave;
    carryOver = j['carryOver'] as bool? ?? carryOver;
    copyToToday = j['copyToToday'] as bool? ?? copyToToday;
    pin = j['pin'] as String?;
    final r = j['rates'];
    if (r is Map) {
      rates = {for (final e in r.entries) e.key as String: (e.value as num).toDouble()};
    }
  }
}

/// Single source of truth for the UI. Keeps everything in memory (a personal
/// finance dataset is small) and writes every change through to [Repository].
class AppStore extends ChangeNotifier {
  AppStore(this.repo);

  final Repository repo;

  List<Account> _accounts = [];
  List<Category> _categories = [];
  List<Txn> _txns = [];
  List<Budget> _budgets = [];
  List<RepeatRule> _repeats = [];
  List<Txn> _templates = [];

  final prefs = Prefs();
  bool unlocked = false;

  String get themeId => prefs.themeId;
  ThemeMode get themeMode => prefs.themeMode;
  String get baseCurrency => prefs.baseCurrency;

  // ---- Loading -----------------------------------------------------------

  Future<void> load() async {
    _accounts = await repo.loadAccounts();
    _categories = await repo.loadCategories();
    _txns = await repo.loadTxns();
    _budgets = await repo.loadBudgets();
    final p = await repo.getSetting('prefs');
    if (p is Map) prefs.apply(Map<String, Object?>.from(p));
    if (await repo.getSetting('seeded') != true) {
      await _seed();
    }
    final r = await repo.getSetting('repeats');
    _repeats = [
      if (r is List)
        for (final e in r) RepeatRule.fromJson(Map<String, Object?>.from(e as Map)),
    ];
    final tp = await repo.getSetting('templates');
    _templates = [
      if (tp is List)
        for (final e in tp) Txn.fromJson(Map<String, Object?>.from(e as Map)),
    ];
    await runRepeats();
    unlocked = prefs.pin == null;
    fmt.showDecimals = prefs.showDecimals;
    _sortTxns();
    notifyListeners();
  }

  Future<void> _seed() async {
    // No starter categories: the user creates their own.
    for (final a in defaultAccounts()) {
      _accounts.add(a);
      await repo.put(a);
    }
    prefs.rates = {'UAH': 0.022, 'USD': 0.92};
    await repo.setSetting('prefs', prefs.toJson());
    await repo.setSetting('seeded', true);
  }

  void _sortTxns() => _txns.sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.updatedAt.compareTo(a.updatedAt);
      });

  // ---- Periods -----------------------------------------------------------

  /// The accounting month that contains [d] (respects "month starts on day N").
  DateTime periodOf(DateTime d) {
    final s = prefs.monthStartDay;
    return d.day >= s ? DateTime(d.year, d.month) : DateTime(d.year, d.month - 1);
  }

  DateTime get currentPeriod => periodOf(DateTime.now());

  ({DateTime start, DateTime end}) periodRange(DateTime month) {
    final s = prefs.monthStartDay;
    return (start: DateTime(month.year, month.month, s), end: DateTime(month.year, month.month + 1, s));
  }

  // ---- Views -------------------------------------------------------------

  List<Account> get accounts =>
      _accounts.where((a) => !a.deleted).toList()..sort((a, b) => a.sort.compareTo(b.sort));
  List<Account> get activeAccounts => accounts.where((a) => !a.archived).toList();

  /// Top-level categories of a type.
  List<Category> categoriesOf(TxType type) =>
      _categories.where((c) => !c.deleted && c.type == type && c.parentId == null).toList()
        ..sort((a, b) => a.sort.compareTo(b.sort));

  List<Category> subcategoriesOf(String parentId) =>
      _categories.where((c) => !c.deleted && c.parentId == parentId).toList()
        ..sort((a, b) => a.sort.compareTo(b.sort));

  List<Txn> get txns => _txns.where((t) => !t.deleted).toList();
  List<Budget> get budgets => _budgets.where((b) => !b.deleted).toList();

  Account? account(String? id) => _accounts.where((a) => a.id == id).firstOrNull;
  Category? category(String? id) => _categories.where((c) => c.id == id).firstOrNull;

  /// Top-level category of a transaction (a sub-category resolves to its parent).
  Category? topCategory(String? id) {
    final c = category(id);
    if (c?.parentId != null) return category(c!.parentId);
    return c;
  }

  String currencyOf(Txn t) => account(t.accountId)?.currency ?? baseCurrency;

  List<Txn> txnsInPeriod(DateTime month) {
    final r = periodRange(month);
    return txns.where((t) => !t.date.isBefore(r.start) && t.date.isBefore(r.end)).toList();
  }

  // Kept for older call sites/tests.
  List<Txn> txnsInMonth(DateTime month) => txnsInPeriod(month);

  List<Txn> txnsOnDay(DateTime d) =>
      txns.where((t) => t.date.year == d.year && t.date.month == d.month && t.date.day == d.day).toList();

  /// Converts minor units of [currency] to minor units of the base currency
  /// using the manual rates in settings.
  int toBase(int minor, String currency) {
    if (currency == baseCurrency) return minor;
    final rate = prefs.rates[currency];
    if (rate == null) return 0;
    final from = fmt.decimalsOf(currency), to = fmt.decimalsOf(baseCurrency);
    var v = minor * rate;
    for (var i = from; i < to; i++) {
      v *= 10;
    }
    for (var i = to; i < from; i++) {
      v /= 10;
    }
    return v.round();
  }

  bool hasRate(String currency) => currency == baseCurrency || prefs.rates.containsKey(currency);

  int baseAmount(Txn t) => toBase(t.amount, currencyOf(t));

  int balanceOf(Account a) {
    var b = a.initialBalance;
    for (final t in txns) {
      if (t.accountId == a.id) {
        b += t.type == TxType.income ? t.amount : -t.amount;
      }
      if (t.type == TxType.transfer && t.toAccountId == a.id) {
        b += t.toAmount ?? t.amount;
      }
    }
    return b;
  }

  /// Assets, liabilities and net worth in base currency.
  ({int assets, int liabilities, int total}) netWorthBase() {
    var assets = 0, liab = 0;
    for (final a in accounts.where((a) => a.includeInTotal)) {
      final v = toBase(balanceOf(a), a.currency);
      if (v >= 0) {
        assets += v;
      } else {
        liab += v;
      }
    }
    return (assets: assets, liabilities: liab, total: assets + liab);
  }

  /// Net worth per currency over accounts included in totals.
  Map<String, int> netWorth() {
    final m = <String, int>{};
    for (final a in accounts.where((a) => a.includeInTotal)) {
      m[a.currency] = (m[a.currency] ?? 0) + balanceOf(a);
    }
    return m;
  }

  /// Income / expense sums per currency.
  ({Map<String, int> income, Map<String, int> expense}) totals(Iterable<Txn> list) {
    final inc = <String, int>{}, exp = <String, int>{};
    for (final t in list) {
      final cur = currencyOf(t);
      if (t.type == TxType.income) inc[cur] = (inc[cur] ?? 0) + t.amount;
      if (t.type == TxType.expense) exp[cur] = (exp[cur] ?? 0) + t.amount;
    }
    return (income: inc, expense: exp);
  }

  /// Income / expense in base currency.
  ({int income, int expense}) totalsBase(Iterable<Txn> list) {
    var inc = 0, exp = 0;
    for (final t in list) {
      if (t.type == TxType.income) inc += baseAmount(t);
      if (t.type == TxType.expense) exp += baseAmount(t);
    }
    return (income: inc, expense: exp);
  }

  List<String> get currenciesInUse => {baseCurrency, ...accounts.map((a) => a.currency)}.toList();

  /// Previously used notes for a category, most frequent first (autocomplete).
  List<String> noteSuggestions(String? categoryId, String prefix) {
    if (!prefs.noteSuggestions) return const [];
    final counts = <String, int>{};
    final q = prefix.toLowerCase();
    for (final t in txns) {
      if (t.note.isEmpty) continue;
      if (categoryId != null && t.categoryId != categoryId) continue;
      if (q.isNotEmpty && !t.note.toLowerCase().contains(q)) continue;
      counts[t.note] = (counts[t.note] ?? 0) + 1;
    }
    final list = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return list.take(6).toList();
  }

  // ---- Mutations ---------------------------------------------------------

  Future<void> _save(Entity e) async {
    await repo.put(e);
    notifyListeners();
  }

  void _replace<T extends Entity>(List<T> list, T e) {
    final i = list.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      list[i] = e;
    } else {
      list.add(e);
    }
  }

  Future<void> saveAccount(Account a) {
    _replace(_accounts, a);
    return _save(a);
  }

  Future<void> saveCategory(Category c) {
    _replace(_categories, c);
    return _save(c);
  }

  Future<void> saveTxn(Txn t) {
    _replace(_txns, t);
    _sortTxns();
    return _save(t);
  }

  Future<void> deleteTxn(Txn t) => saveTxn(t.copyWith(deleted: true));

  Future<void> saveBudget(Budget b) {
    _replace(_budgets, b);
    return _save(b);
  }

  // ---- Repeating records ---------------------------------------------------

  List<RepeatRule> get repeats => List.unmodifiable(_repeats);

  Future<void> _saveRepeats() => repo.setSetting('repeats', [for (final r in _repeats) r.toJson()]);

  /// Creates the records that have come due since the last run.
  Future<int> runRepeats({DateTime? now}) async {
    final at = now ?? DateTime.now();
    var made = 0;
    for (var i = 0; i < _repeats.length; i++) {
      final r = _repeats[i];
      final due = r.dueUntil(at);
      if (due.isEmpty) continue;
      for (final d in due) {
        final t = r.template;
        await saveTxn(Txn(
          type: t.type,
          amount: t.amount,
          accountId: t.accountId,
          toAccountId: t.toAccountId,
          toAmount: t.toAmount,
          categoryId: t.categoryId,
          date: d,
          note: t.note,
        ));
        made++;
      }
      _repeats[i] = r.copyWith(lastDone: due.last);
    }
    if (made > 0) {
      await _saveRepeats();
      notifyListeners();
    }
    return made;
  }

  Future<void> saveRepeat(RepeatRule r) async {
    _replaceRule(r);
    await _saveRepeats();
    await runRepeats();
    notifyListeners();
  }

  void _replaceRule(RepeatRule r) {
    final i = _repeats.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      _repeats[i] = r;
    } else {
      _repeats.add(r);
    }
  }

  Future<void> deleteRepeat(RepeatRule r) async {
    _repeats.removeWhere((e) => e.id == r.id);
    await _saveRepeats();
    notifyListeners();
  }

  // ---- Templates ("зірочка" in the editor, MM bookmarks) --------------------

  List<Txn> get templates => List.unmodifiable(_templates);

  Future<void> saveTemplate(Txn t) async {
    _templates.add(t);
    await repo.setSetting('templates', [for (final x in _templates) x.toJson()]);
    notifyListeners();
  }

  Future<void> deleteTemplate(Txn t) async {
    _templates.removeWhere((x) => x.id == t.id);
    await repo.setSetting('templates', [for (final x in _templates) x.toJson()]);
    notifyListeners();
  }

  /// Account of the most recent record: the default for a new one.
  String? get lastUsedAccountId {
    final active = activeAccounts.map((a) => a.id).toSet();
    for (final t in txns) {
      if (active.contains(t.accountId)) return t.accountId;
    }
    return activeAccounts.firstOrNull?.id;
  }

  /// Income minus expense (base currency) of everything before [start]:
  /// Money Manager's "carry-over".
  int carryBefore(DateTime start) {
    var v = 0;
    for (final t in txns) {
      if (!t.date.isBefore(start)) continue;
      if (t.type == TxType.income) v += baseAmount(t);
      if (t.type == TxType.expense) v -= baseAmount(t);
    }
    return v;
  }

  /// Hashtags used in notes ("#відпустка"), most used first.
  List<({String tag, int count, int sum})> tags() {
    final m = <String, ({int count, int sum})>{};
    final re = RegExp(r'#([\p{L}\p{N}_-]+)', unicode: true);
    for (final t in txns) {
      for (final x in re.allMatches(t.note)) {
        final k = x.group(1)!.toLowerCase();
        final o = m[k] ?? (count: 0, sum: 0);
        final signed = t.type == TxType.income ? baseAmount(t) : (t.type == TxType.expense ? -baseAmount(t) : 0);
        m[k] = (count: o.count + 1, sum: o.sum + signed);
      }
    }
    final out = [for (final e in m.entries) (tag: e.key, count: e.value.count, sum: e.value.sum)];
    out.sort((a, b) => b.count.compareTo(a.count));
    return out;
  }

  Future<void> updatePrefs(void Function(Prefs p) change) async {
    change(prefs);
    fmt.showDecimals = prefs.showDecimals;
    await repo.setSetting('prefs', prefs.toJson());
    notifyListeners();
  }

  Future<void> setTheme(String id) => updatePrefs((p) => p.themeId = id);
  Future<void> setThemeMode(ThemeMode m) => updatePrefs((p) => p.themeMode = m);
  Future<void> setBaseCurrency(String c) => updatePrefs((p) => p.baseCurrency = c);

  void unlock() {
    unlocked = true;
    notifyListeners();
  }

  // ---- Backup ------------------------------------------------------------

  Future<String> exportJson() async => const JsonEncoder.withIndent('  ').convert(await repo.exportAll());

  Future<void> importJson(String json) async {
    final data = jsonDecode(json) as Map<String, Object?>;
    await repo.importAll(data);
    await load();
  }

  Future<void> resetAll() async {
    await repo.wipe();
    _accounts = [];
    _categories = [];
    _txns = [];
    _budgets = [];
    final fresh = Prefs()..themeId = prefs.themeId..themeMode = prefs.themeMode;
    prefs.apply(fresh.toJson());
    await load();
  }
}

/// Makes [AppStore] available to the widget tree and rebuilds dependents on change.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  static AppStore read(BuildContext context) => context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
