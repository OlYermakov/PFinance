import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../data/fx_rates.dart';
import '../data/mm_import.dart';
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
  int monthStartDay = 1; // 1..31, e.g. salary day; clamped to short months
  int monthStartShift = 0; // start on a weekend: 0 no change, 1 previous Friday, 2 next Monday
  int weekStart = DateTime.monday; // DateTime.monday..DateTime.sunday
  bool get weekStartsMonday => weekStart == DateTime.monday;
  StartPage startPage = StartPage.day;
  String incomeColor = 'green'; // income: 'green', 'blue' or 'accent' (theme accent); expenses are always red
  bool showDecimals = true;
  bool subcategories = true;
  bool accountGroupsInPicker = false; // MM: the account picker shows groups first
  bool noteSuggestions = true;
  bool continueAfterSave = false;
  bool carryOver = false; // add the balance of earlier periods to "Разом"
  bool copyToToday = true; // a copied record gets today's date (else the original date)
  String? pin; // 4 digits; local convenience lock, not encryption
  // MM "Transaction Settings"
  int timeMode = 1; // 0: no time, 1: input only, 2: input and show in lists
  bool timeAsc = false; // records of a day: oldest first (MM «Зрост.») instead of newest first
  String swipe = 'tabs'; // 'tabs' (switch view tabs), 'period' (change period), 'delete', 'off'
  bool showNote = true; // MM «Показати деталі»: show the description after the note
  bool amountFirst = false; // MM «Порядок введення»: start from the amount
  bool weeklyPeriod = false; // MM «Налаштування періоду»: Тижні instead of Місяці
  bool copyPaste = true; // copy button for records
  // MM "Main currency": symbol in front ("€ 1,00") or behind ("1,00 €")
  bool currencyFront = false;
  // MM "Repeat Setting → Timing of reflection": on the date or whole period in advance
  bool repeatInAdvance = false;
  // MM "Transfer-Expense": transfers into these accounts count as expenses
  List<String> transferExpense = [];
  List<String> savedTags = [];
  int appIcon = 0;
  // MM "Card expense display": 'moment' (A) or 'balance' (B, payable/outstanding)
  String cardDisplay = 'moment';
  Map<String, double> rates = {}; // 1 unit of currency = rate × base
  bool autoRates = true; // refresh [rates] from the internet once a day
  int ratesUpdated = 0; // when [rates] were last fetched (ms)

  Map<String, Object?> toJson() => {
    'themeId': themeId,
    'themeMode': themeMode.name,
    'baseCurrency': baseCurrency,
    'monthStartDay': monthStartDay,
    'monthStartShift': monthStartShift,
    'weekStart': weekStart,
    'startPage': startPage.name,
    'incomeColor': incomeColor,
    'showDecimals': showDecimals,
    'subcategories': subcategories,
    'accountGroupsInPicker': accountGroupsInPicker,
    'noteSuggestions': noteSuggestions,
    'swipeTabsV1': true,
    'continueAfterSave': continueAfterSave,
    'carryOver': carryOver,
    'copyToToday': copyToToday,
    'pin': pin,
    'rates': rates,
    'autoRates': autoRates,
    'ratesUpdated': ratesUpdated,
    'timeMode': timeMode,
    'timeAsc': timeAsc,
    'swipe': swipe,
    'showNote': showNote,
    'amountFirst': amountFirst,
    'weeklyPeriod': weeklyPeriod,
    'copyPaste': copyPaste,
    'currencyFront': currencyFront,
    'repeatInAdvance': repeatInAdvance,
    'transferExpense': transferExpense,
    'savedTags': savedTags,
    'appIcon': appIcon,
    'cardDisplay': cardDisplay,
  };

  void apply(Map<String, Object?> j) {
    themeId = j['themeId'] as String? ?? themeId;
    themeMode = ThemeMode.values.asNameMap()[j['themeMode']] ?? themeMode;
    baseCurrency = j['baseCurrency'] as String? ?? baseCurrency;
    monthStartDay = (j['monthStartDay'] as num?)?.toInt() ?? monthStartDay;
    monthStartShift = (j['monthStartShift'] as num?)?.toInt() ?? monthStartShift;
    weekStart = (j['weekStart'] as num?)?.toInt() ?? (j['weekStartsMonday'] == false ? DateTime.sunday : weekStart);
    startPage = StartPage.values.asNameMap()[j['startPage']] ?? startPage;
    incomeColor = j['incomeColor'] as String? ?? (j['incomeBlue'] == true ? 'blue' : incomeColor);
    showDecimals = j['showDecimals'] as bool? ?? showDecimals;
    subcategories = j['subcategories'] as bool? ?? subcategories;
    accountGroupsInPicker = j['accountGroupsInPicker'] as bool? ?? accountGroupsInPicker;
    noteSuggestions = j['noteSuggestions'] as bool? ?? noteSuggestions;
    continueAfterSave = j['continueAfterSave'] as bool? ?? continueAfterSave;
    carryOver = j['carryOver'] as bool? ?? carryOver;
    copyToToday = j['copyToToday'] as bool? ?? copyToToday;
    pin = j['pin'] as String?;
    timeMode = (j['timeMode'] as num?)?.toInt() ?? timeMode;
    timeAsc = j['timeAsc'] as bool? ?? timeAsc;
    swipe = j['swipe'] as String? ?? swipe;
    showNote = j['showNote'] as bool? ?? showNote;
    amountFirst = j['amountFirst'] as bool? ?? amountFirst;
    weeklyPeriod = j['weeklyPeriod'] as bool? ?? weeklyPeriod;
    // Alex: a swipe must switch the view tabs, never delete records.
    if (j['swipeTabsV1'] != true) swipe = 'tabs';
    copyPaste = j['copyPaste'] as bool? ?? copyPaste;
    currencyFront = j['currencyFront'] as bool? ?? currencyFront;
    repeatInAdvance = j['repeatInAdvance'] as bool? ?? repeatInAdvance;
    if (j['cardDisplay'] is String) cardDisplay = j['cardDisplay'] as String;
    final te = j['transferExpense'];
    if (te is List) transferExpense = [for (final x in te) x as String];
    final st = j['savedTags'];
    if (st is List) savedTags = [for (final x in st) x as String];
    appIcon = (j['appIcon'] as num?)?.toInt() ?? appIcon;
    autoRates = j['autoRates'] as bool? ?? autoRates;
    ratesUpdated = (j['ratesUpdated'] as num?)?.toInt() ?? ratesUpdated;
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

  /// Older MM imports wrote a foreign amount into the note ("Магазин (12.95
  /// UAH)"). Move it to the record's entered amount so notes stay clean.
  Future<void> _moveMmCurrencyNotes() async {
    final re = RegExp(r'^(.*?)\s*\((\d+(?:\.\d+)?) ([A-Z]{3})\)$');
    for (var i = 0; i < _txns.length; i++) {
      final t = _txns[i];
      final m = re.firstMatch(t.note);
      if (m == null || t.enteredCur != null) continue;
      final cur = m[3]!;
      if (cur == account(t.accountId)?.currency) continue;
      final v = double.parse(m[2]!);
      var k = 1;
      for (var d = 0; d < fmt.decimalsOf(cur); d++) {
        k *= 10;
      }
      final j = t.toJson()
        ..['note'] = m[1]!.trim()
        ..['enteredAmount'] = (v * k).round()
        ..['enteredCur'] = cur;
      _txns[i] = Txn.fromJson(j);
      await repo.put(_txns[i]);
    }
  }

  Future<void> load() async {
    _accounts = await repo.loadAccounts();
    _categories = await repo.loadCategories();
    _txns = await repo.loadTxns();
    await _moveMmCurrencyNotes();
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
    final fx = await repo.getSetting('fxDays');
    _fxDays = {
      if (fx is Map)
        for (final e in fx.entries) e.key as String: {for (final r in (e.value as Map).entries) r.key as String: (r.value as num).toDouble()},
    };
    await runRepeats();
    unlocked = prefs.pin == null;
    fmt.showDecimals = prefs.showDecimals;
    fmt.currencyFront = prefs.currencyFront;
    _sortTxns();
    notifyListeners();
    unawaited(fillDayRates());
    unawaited(refreshRates());
  }

  /// Today's rates for the extra currencies. With [force] false it runs only
  /// when «Оновлювати щодня» is on and the rates are older than today.
  /// Returns how many rates were updated, or null when offline.
  Future<int?> refreshRates({bool force = false, Iterable<String> extra = const []}) async {
    final now = DateTime.now();
    final last = DateTime.fromMillisecondsSinceEpoch(prefs.ratesUpdated);
    if (!force && (!prefs.autoRates || (last.year == now.year && last.month == now.month && last.day == now.day))) return 0;
    final codes = {...currenciesInUse, ...prefs.rates.keys, ...extra}.where((c) => c != baseCurrency);
    if (codes.isEmpty) return 0;
    final got = await fetchRatesNow(baseCurrency);
    if (got == null) return null;
    var n = 0;
    await updatePrefs((p) {
      final next = {...p.rates};
      for (final c in codes) {
        final r = got[c];
        if (r != null) {
          next[c] = r;
          n++;
        }
      }
      p.rates = next;
      p.ratesUpdated = now.millisecondsSinceEpoch;
    });
    return n;
  }

  /// Replaceable in tests.
  Future<Map<String, double>?> Function(String base) fetchRatesNow = fetchLatestRates;

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

  /// First day of the accounting month [year]/[month]: "month starts on day N"
  /// (clamped to the month's length), moved off a weekend if so chosen.
  DateTime periodStart(int year, int month) {
    final last = DateTime(year, month + 1, 0).day;
    final d = DateTime(year, month, math.min(prefs.monthStartDay, last));
    return switch ((prefs.monthStartShift, d.weekday)) {
      (1, DateTime.saturday) => DateTime(d.year, d.month, d.day - 1),
      (1, DateTime.sunday) => DateTime(d.year, d.month, d.day - 2),
      (2, DateTime.saturday) => DateTime(d.year, d.month, d.day + 2),
      (2, DateTime.sunday) => DateTime(d.year, d.month, d.day + 1),
      _ => d,
    };
  }

  /// The accounting month that contains [d] (respects "month starts on day N").
  DateTime periodOf(DateTime d) {
    var m = DateTime(d.year, d.month);
    if (d.isBefore(periodStart(m.year, m.month))) m = DateTime(m.year, m.month - 1);
    if (!d.isBefore(periodStart(m.year, m.month + 1))) m = DateTime(m.year, m.month + 1);
    return m;
  }

  DateTime get currentPeriod => periodOf(DateTime.now());

  /// First day of the week holding [d] («Початок тижня»).
  DateTime weekOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - prefs.weekStart) % 7);

  ({DateTime start, DateTime end}) weekRange(DateTime week) {
    final s = weekOf(week);
    return (start: s, end: DateTime(s.year, s.month, s.day + 7));
  }

  ({DateTime start, DateTime end}) periodRange(DateTime month) => (start: periodStart(month.year, month.month), end: periodStart(month.year, month.month + 1));

  /// The accounting year: from the start of its January to the next one's.
  ({DateTime start, DateTime end}) yearRange(int year) => (start: periodStart(year, 1), end: periodStart(year + 1, 1));

  // ---- Views -------------------------------------------------------------

  List<Account> get accounts => _accounts.where((a) => !a.deleted).toList()..sort((a, b) => a.sort.compareTo(b.sort));
  List<Account> get deletedAccounts => _accounts.where((a) => a.deleted).toList();
  List<Account> get activeAccounts => accounts.where((a) => !a.archived).toList();

  /// Top-level categories of a type.
  List<Category> categoriesOf(TxType type) =>
      _categories.where((c) => !c.deleted && c.type == type && c.parentId == null).toList()..sort((a, b) => a.sort.compareTo(b.sort));

  List<Category> subcategoriesOf(String parentId) =>
      _categories.where((c) => !c.deleted && c.parentId == parentId).toList()..sort((a, b) => a.sort.compareTo(b.sort));

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

  List<Txn> txnsOnDay(DateTime d) => txns.where((t) => t.date.year == d.year && t.date.month == d.month && t.date.day == d.day).toList();

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

  /// Value in the base currency at the rate of the record's day when known
  /// (stamped by [fillDayRates]), otherwise at the current manual rate.
  /// Converts between any two currencies at the current manual rates; null
  /// when a rate is missing.
  int? convertNow(int minor, String from, String to) {
    if (from == to) return minor;
    final rf = from == baseCurrency ? 1.0 : prefs.rates[from];
    final rt = to == baseCurrency ? 1.0 : prefs.rates[to];
    if (rf == null || rt == null || rt == 0) return null;
    return _convert(minor, from, to, rf / rt);
  }

  /// The amount as the user typed it (a foreign currency if so), for display.
  int shownAmount(Txn t) => t.enteredAmount ?? t.amount;
  String shownCurrency(Txn t) => t.enteredCur ?? currencyOf(t);

  /// A repeat template in the base currency, from the amount as entered
  /// (US\$ 2,99 stays US\$ 2,99 whatever the card's currency).
  int repeatBase(Txn t) => t.enteredAmount != null && t.enteredCur != null ? toBase(t.enteredAmount!, t.enteredCur!) : baseAmount(t);

  /// The repeat a record came from (MM shows its period on the record): same
  /// type, account, category and note (MM may add "(2,99 \$)" to the note).
  RepeatRule? repeatOf(Txn t) {
    for (final r in _repeats) {
      final x = r.template;
      if (x.type != t.type || x.accountId != t.accountId || x.categoryId != t.categoryId) continue;
      if (x.note.isEmpty ? t.note.isEmpty && x.amount == t.amount : t.note == x.note || t.note.startsWith('${x.note} (')) return r;
    }
    return null;
  }

  int baseAmount(Txn t) {
    final cur = currencyOf(t);
    if (cur == baseCurrency) return t.amount;
    if (t.atBase != null && t.atBaseCur == baseCurrency) return t.atBase!;
    return toBase(t.amount, cur);
  }

  // ---- Rates of the record's day ---------------------------------------------

  /// Daily rates per "BASE:YYYY-MM-DD": currency → value of 1 unit in base.
  /// An empty map means the day has no published rates.
  Map<String, Map<String, double>> _fxDays = {};

  /// Fetches one day's rates for [base] (1 unit of currency = rate × base).
  /// Replaceable in tests.
  Future<Map<String, double>?> Function(DateTime day, String base) fetchDayRates = fetchDailyRates;

  Future<void>? _fillRun;
  bool _fillAgain = false;

  static String _dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _needsRate(Txn t) => !t.deleted && currencyOf(t) != baseCurrency && (t.atBase == null || t.atBaseCur != baseCurrency);

  /// Stamps every foreign-currency record with its value in the base currency
  /// at the rate of its day. Days are fetched once and cached; future days
  /// wait until they come. Runs in the background.
  Future<void> fillDayRates({DateTime? now, int maxDays = 400}) {
    if (_fillRun != null) {
      _fillAgain = true; // records changed meanwhile: run once more
      return _fillRun!;
    }
    return _fillRun = () async {
      try {
        do {
          _fillAgain = false;
          await _fillOnce(now, maxDays);
        } while (_fillAgain);
      } finally {
        _fillRun = null;
      }
    }();
  }

  Future<void> _fillOnce(DateTime? now, int maxDays) async {
    {
      final today = now ?? DateTime.now();
      final base = baseCurrency;
      final byDay = <String, List<Txn>>{};
      for (final t in _txns) {
        if (!_needsRate(t) || t.date.isAfter(today)) continue;
        (byDay[_dayKey(t.date)] ??= []).add(t);
      }
      if (byDay.isEmpty) return;
      final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a)); // newest first
      var fetched = 0, changed = false;
      for (final day in days) {
        final key = '$base:$day';
        var rates = _fxDays[key];
        if (rates == null) {
          if (fetched >= maxDays) continue;
          fetched++;
          final r = await fetchDayRates(DateTime.parse(day), base);
          if (r == null) continue; // offline: try again next time
          rates = _fxDays[key] = r;
          if (fetched % 20 == 0) await repo.setSetting('fxDays', _fxDays);
        }
        for (final t in byDay[day]!) {
          final rate = rates[currencyOf(t)];
          if (rate == null) continue;
          final i = _txns.indexWhere((x) => x.id == t.id);
          if (i < 0 || !_needsRate(_txns[i])) continue;
          final v = _convert(t.amount, currencyOf(t), base, rate);
          final s = _txns[i].withBase(v, base);
          _txns[i] = s;
          await repo.put(s);
          changed = true;
        }
      }
      await repo.setSetting('fxDays', _fxDays);
      if (changed) notifyListeners();
    }
  }

  /// Value of 1 unit of [cur] in the base currency on [day]: from records of
  /// that day that already carry their day value (MM's own rate), else from
  /// the cached daily rates. Null when that day's rate isn't known yet.
  double? dayRate(DateTime day, String cur) {
    final base = baseCurrency;
    if (cur == base) return 1;
    final key = _dayKey(day);
    for (final t in _txns) {
      if (t.deleted || t.amount == 0 || t.atBase == null || t.atBaseCur != base) continue;
      if (currencyOf(t) != cur || _dayKey(t.date) != key) continue;
      return _major(t.atBase!, base) / _major(t.amount, cur);
    }
    return _fxDays['$base:$key']?[cur];
  }

  /// Loads [day]'s rates when they aren't cached (for [dayRate]).
  Future<void> loadDayRates(DateTime day) async {
    final key = '$baseCurrency:${_dayKey(day)}';
    if (_fxDays.containsKey(key) || day.isAfter(DateTime.now())) return;
    final r = await fetchDayRates(DateTime(day.year, day.month, day.day), baseCurrency);
    if (r == null) return;
    _fxDays[key] = r;
    await repo.setSetting('fxDays', _fxDays);
    notifyListeners();
  }

  /// [minor] of [cur] converted with a rate in major units.
  int convertAt(int minor, String cur, double rate) => _convert(minor, cur, baseCurrency, rate);

  static double _major(int minor, String cur) {
    var v = minor.toDouble();
    for (var i = 0; i < fmt.decimalsOf(cur); i++) {
      v /= 10;
    }
    return v;
  }

  int _convert(int minor, String from, String to, double rate) {
    final f = fmt.decimalsOf(from), d = fmt.decimalsOf(to);
    var v = minor * rate;
    for (var i = f; i < d; i++) {
      v *= 10;
    }
    for (var i = d; i < f; i++) {
      v /= 10;
    }
    return v.round();
  }

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

  /// Balance of [a] at the end of [day] (inclusive).
  int balanceAt(Account a, DateTime day) {
    final end = DateTime(day.year, day.month, day.day + 1);
    var b = a.initialBalance;
    for (final t in txns) {
      if (!t.date.isBefore(end)) continue;
      if (t.accountId == a.id) b += t.type == TxType.income ? t.amount : -t.amount;
      if (t.type == TxType.transfer && t.toAccountId == a.id) b += t.toAmount ?? t.amount;
    }
    return b;
  }

  /// Card cycle (MM "B. As balance"): what the last closed statement still
  /// owes (payable, due on the next pay day) and what the current, still open
  /// cycle has changed the balance (outstanding). Both are negative when owed/spent.
  ({int payable, int outstanding, DateTime settled, DateTime due})? cardCycle(Account a, {DateTime? now}) {
    final sd = a.settleDay;
    if (sd == null) return null;
    final today = now ?? DateTime.now();
    DateTime clampDay(int y, int m, int d) {
      final last = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, d > last ? last : d);
    }

    var settled = clampDay(today.year, today.month, sd);
    if (settled.isAfter(DateTime(today.year, today.month, today.day))) settled = clampDay(today.year, today.month - 1, sd);
    final pd = a.payDay ?? sd;
    var due = clampDay(settled.year, settled.month, pd);
    if (!due.isAfter(settled)) due = clampDay(settled.year, settled.month + 1, pd);
    final atSettle = balanceAt(a, settled);
    final now0 = balanceOf(a);
    return (payable: atSettle < 0 ? atSettle : 0, outstanding: now0 - atSettle, settled: settled, due: due);
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

  /// How a record counts in income/expense totals. Transfers count too when
  /// one side is a "transfer-expense" account (MM): money going into it is an
  /// expense, money coming back out of it is income.
  TxType? flowOf(Txn t) {
    if (t.type != TxType.transfer) return t.type;
    final te = prefs.transferExpense;
    final into = te.contains(t.toAccountId), outOf = te.contains(t.accountId);
    if (into && !outOf) return TxType.expense;
    if (outOf && !into) return TxType.income;
    return null;
  }

  /// Income / expense sums per currency.
  ({Map<String, int> income, Map<String, int> expense}) totals(Iterable<Txn> list) {
    final inc = <String, int>{}, exp = <String, int>{};
    for (final t in list) {
      final cur = currencyOf(t);
      final f = flowOf(t);
      if (f == TxType.income) inc[cur] = (inc[cur] ?? 0) + t.amount;
      if (f == TxType.expense) exp[cur] = (exp[cur] ?? 0) + t.amount;
    }
    return (income: inc, expense: exp);
  }

  /// Income / expense in base currency.
  ({int income, int expense}) totalsBase(Iterable<Txn> list) {
    var inc = 0, exp = 0;
    for (final t in list) {
      final f = flowOf(t);
      if (f == TxType.income) inc += baseAmount(t);
      if (f == TxType.expense) exp += baseAmount(t);
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

  Future<void> saveTxn(Txn t) async {
    final old = _txns.where((x) => x.id == t.id).firstOrNull;
    // A changed amount, day or account needs the rate again.
    if (t.atBase != null && old != null && (old.amount != t.amount || old.accountId != t.accountId || _dayKey(old.date) != _dayKey(t.date))) {
      t = t.withBase(null, null);
    }
    _replace(_txns, t);
    _sortTxns();
    await _save(t);
    if (_needsRate(t)) unawaited(fillDayRates());
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
    final today = now ?? DateTime.now();
    // "In advance": create the whole current period's records at once.
    final at = prefs.repeatInAdvance ? periodRange(periodOf(today)).end.subtract(const Duration(minutes: 1)) : today;
    var made = 0;
    for (var i = 0; i < _repeats.length; i++) {
      final r = _repeats[i];
      final due = r.dueUntil(at);
      if (due.isEmpty) continue;
      for (final d in due) {
        final t = r.template;
        final accCur = currencyOf(t);
        await saveTxn(
          Txn(
            type: t.type,
            amount: t.enteredAmount != null && t.enteredCur != null ? convertNow(t.enteredAmount!, t.enteredCur!, accCur) ?? t.amount : t.amount,
            accountId: t.accountId,
            toAccountId: t.toAccountId,
            toAmount: t.toAmount,
            categoryId: t.categoryId,
            date: d,
            note: t.note,
            memo: t.memo,
            enteredAmount: t.enteredAmount,
            enteredCur: t.enteredCur,
          ),
        );
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
      final f = flowOf(t);
      if (f == TxType.income) v += baseAmount(t);
      if (f == TxType.expense) v -= baseAmount(t);
    }
    return v;
  }

  /// Hashtags used in notes ("#відпустка"), most used first.
  List<({String tag, int count, int sum})> tags() {
    final m = <String, ({int count, int sum})>{};
    final re = RegExp(r'#([\p{L}\p{N}_-]+)', unicode: true);
    for (final t in txns) {
      for (final x in re.allMatches('${t.note} ${t.memo}')) {
        final k = x.group(1)!.toLowerCase();
        final o = m[k] ?? (count: 0, sum: 0);
        final signed = t.type == TxType.income ? baseAmount(t) : (t.type == TxType.expense ? -baseAmount(t) : 0);
        m[k] = (count: o.count + 1, sum: o.sum + signed);
      }
    }
    for (final t in prefs.savedTags) {
      m.putIfAbsent(t.toLowerCase(), () => (count: 0, sum: 0));
    }
    final out = [for (final e in m.entries) (tag: e.key, count: e.value.count, sum: e.value.sum)];
    out.sort((a, b) => b.count.compareTo(a.count));
    return out;
  }

  Future<void> updatePrefs(void Function(Prefs p) change) async {
    change(prefs);
    fmt.showDecimals = prefs.showDecimals;
    fmt.currencyFront = prefs.currencyFront;
    await repo.setSetting('prefs', prefs.toJson());
    notifyListeners();
    unawaited(fillDayRates()); // the base currency may have changed
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

  /// Replaces all data with the contents of a Money Manager backup (.mmbak).
  Future<Map<String, int>> importMoneyManagerBackup(Uint8List bytes) async {
    final current = await repo.exportAll();
    final res = importMoneyManager(bytes, Map<String, Object?>.from(current['settings'] as Map? ?? const {}));
    await repo.importAll(res.backup);
    await load();
    return res.stats;
  }

  /// MM "Reset contents only": drops records, repeats and budgets but keeps
  /// accounts, categories and settings.
  Future<void> resetContents() async {
    for (final t in txns) {
      await saveTxn(t.copyWith(deleted: true));
    }
    for (final b in budgets) {
      await saveBudget(b.copyWith(deleted: true));
    }
    _repeats = [];
    await _saveRepeats();
    notifyListeners();
  }

  Future<void> resetAll() async {
    await repo.wipe();
    _accounts = [];
    _categories = [];
    _txns = [];
    _budgets = [];
    final fresh = Prefs()
      ..themeId = prefs.themeId
      ..themeMode = prefs.themeMode;
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
