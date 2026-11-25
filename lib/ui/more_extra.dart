part of 'more_page.dart';

void _push(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => AuroraBackground(child: page)));

// ---- Налаштування записів (MM: Transaction Settings) -----------------------------

class _TxnSettingsPage extends StatelessWidget {
  const _TxnSettingsPage();

  static String startLabel(StartPage s) => switch (s) {
    StartPage.day => tr('День'),
    StartPage.calendar => tr('Календар'),
    StartPage.month => tr('Місяць'),
    StartPage.summary => tr('Підсумок'),
    StartPage.stats => tr('Статистика'),
    StartPage.accounts => tr('Рахунки'),
  };

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pr = store.prefs;
    Future<void> pick<T>(
      String title,
      Map<T, String> options,
      T current,
      void Function(Prefs p, T v) set, {
      String? note,
      Map<T, Color>? colors,
      _Spot? spot,
    }) async {
      final v = await _choose<T>(context, title, options, current, note: note, colors: colors, preview: spot == null ? null : _SettingPreview(spot));
      if (v != null) store.updatePrefs((p) => set(p, v));
    }

    final timeLabels = {
      0: tr('Немає, спад.'),
      1: tr('Немає, зрост.'),
      4: tr('Показ у списку, спад.'),
      5: tr('Показ у списку, зрост.'),
      2: tr('Лише введення, спад.'),
      3: tr('Лише введення, зрост.'),
    };
    final weekdays = {1: tr('Понеділок'), 2: tr('Вівторок'), 3: tr('Середа'), 4: tr('Четвер'), 5: tr('Пʼятниця'), 6: tr('Субота'), 7: tr('Неділя')};
    final shiftLabels = {0: '', 1: tr(' · пт'), 2: tr(' · пн')};
    final swipeLabels = {'tabs': tr('Зміна вкладки'), 'period': tr('Зміна періоду'), 'delete': tr('Видалення запису'), 'off': tr('Вимкнено')};
    return Scaffold(
      appBar: AppBar(title: Text(tr('Налаштування записів'))),
      body: ListView(
        children: [
          _Group(
            children: [
              _Item(
                null,
                tr('Початок місяця'),
                value: '${pr.monthStartDay}${shiftLabels[pr.monthStartShift]}',
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  constraints: const BoxConstraints(maxWidth: 520),
                  builder: (_) => const _MonthStartSheet(),
                ),
              ),
              _Item(
                null,
                tr('Початок тижня'),
                value: weekdays[pr.weekStart],
                onTap: () => pick<int>(
                  tr('Початок тижня'),
                  {
                    for (final d in [7, 1, 2, 3, 4, 5, 6]) d: weekdays[d]!,
                  },
                  pr.weekStart,
                  (p, v) => p.weekStart = v,
                  colors: {7: AppPalette.of(context).expense, 6: const Color(0xFF4F9DF0)},
                ),
              ),
              _Item(
                null,
                tr('Перенесення залишку'),
                value: _onOff(pr.carryOver),
                onTap: () => pick<bool>(
                  tr('Перенесення залишку'),
                  {false: tr('Вимк.'), true: tr('Увімк.')},
                  pr.carryOver,
                  (p, v) => p.carryOver = v,
                  spot: _Spot.carry,
                  note: tr('Перенесення додає залишок попередніх місяців до підсумку «Разом» поточного.'),
                ),
              ),
              _Item(
                null,
                tr('Налаштування періоду'),
                value: pr.weeklyPeriod ? tr('Тижні') : tr('Місяці'),
                onTap: () => pick<bool>(
                  tr('Налаштування періоду'),
                  {false: tr('Місяці'), true: tr('Тижні')},
                  pr.weeklyPeriod,
                  (p, v) => p.weeklyPeriod = v,
                  note: tr('«Тижні»: у записах (День, Підсумок) і в Статистиці стрілки перемикають тижні, і всі підсумки рахуються за тиждень. Тиждень починається з дня, вибраного в «Початку тижня». Календар і бюджет лишаються помісячними.'),
                ),
              ),
              _Item(
                null,
                tr('Колір доходів і витрат'),
                value: {'green': tr('Дохід зелений'), 'blue': tr('Дохід синій'), 'accent': tr('Дохід за акцентом')}[pr.incomeColor] ?? tr('Дохід зелений'),
                onTap: () => pick<String>(
                  tr('Колір доходів'),
                  {'green': tr('Дохід зелений, витрати червоні'), 'blue': tr('Дохід синій, витрати червоні'), 'accent': tr('Дохід за акцентом, витрати червоні')},
                  pr.incomeColor,
                  (p, v) => p.incomeColor = v,
                  spot: _Spot.colors,
                ),
              ),
              _Item(
                null,
                tr('Автозаповнення'),
                value: _onOff(pr.noteSuggestions),
                onTap: () => pick<bool>(
                  tr('Автозаповнення'),
                  {false: tr('Вимк.'), true: tr('Увімк.')},
                  pr.noteSuggestions,
                  (p, v) => p.noteSuggestions = v,
                  note: tr('Під час введення нотатки показує схожі нотатки з попередніх записів. Вибір підказки заповнює категорію, рахунок і суму.'),
                ),
              ),
              _Item(
                null,
                tr('Введення часу'),
                value: timeLabels[_timeKey(pr)],
                onTap: () => pick<int>(
                  tr('Введення часу'),
                  timeLabels,
                  _timeKey(pr),
                  (p, v) {
                    p.timeMode = v ~/ 2;
                    p.timeAsc = v.isOdd;
                  },
                  spot: _Spot.time,
                  note: tr('«Немає» — без часу; «Показ у списку» — час видно в записах; «Лише введення» — час лише в редакторі. Спад./зрост. — порядок записів у дні.'),
                ),
              ),
              _Item(
                null,
                tr('Стартовий екран'),
                value: startLabel(pr.startPage),
                onTap: () => pick<StartPage>(
                  tr('Стартовий екран'),
                  {for (final s in StartPage.values) s: startLabel(s)},
                  pr.startPage,
                  (p, v) => p.startPage = v,
                  spot: _Spot.tabs,
                ),
              ),
              _Item(
                null,
                tr('Свайп'),
                value: swipeLabels[pr.swipe],
                onTap: () => pick<String>(tr('Свайп у списку записів'), swipeLabels, pr.swipe, (p, v) => p.swipe = v),
              ),
              _Item(
                null,
                tr('Показати деталі'),
                value: _onOff(pr.showNote),
                onTap: () => pick<bool>(
                  tr('Показати деталі'),
                  {false: tr('Вимк.'), true: tr('Увімк.')},
                  pr.showNote,
                  (p, v) => p.showNote = v,
                  spot: _Spot.note,
                  note: tr('Опис запису (поле «Опис» у редакторі) показується в списку сірим одразу після нотатки.'),
                ),
              ),
              _Item(
                null,
                tr('Порядок введення'),
                value: pr.amountFirst ? tr('Спершу сума') : tr('Спершу рахунок'),
                onTap: () => pick<bool>(
                  tr('Порядок введення'),
                  {false: tr('Спершу рахунок'), true: tr('Спершу сума')},
                  pr.amountFirst,
                  (p, v) => p.amountFirst = v,
                  note: tr('З чого починається новий запис: з вибору рахунку чи з введення суми.'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Which part of the sample screen a setting changes.
enum _Spot { note, colors, time, carry, tabs }

/// MM-style picture in a setting sheet: a small sample of the records screen
/// with the part the setting changes outlined in red.
class _SettingPreview extends StatelessWidget {
  const _SettingPreview(this.spot);
  final _Spot spot;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final red = AppPalette.of(context).expense;
    final inc = incomeColor(context, store);
    Widget mark(_Spot s, Widget child) => spot != s
        ? child
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: red, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: child,
          );
    TextStyle st(double size, Color c, [FontWeight w = FontWeight.w500]) => TextStyle(fontSize: size, color: c, fontWeight: w);
    Widget col(String label, String v, Color c) => Column(
      children: [
        Text(label, style: st(11, muted)),
        const SizedBox(height: 2),
        Text(v, style: st(13, c, FontWeight.w600)),
      ],
    );
    final divider = Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4));
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Липень 2026'), textAlign: TextAlign.center, style: st(13, scheme.onSurface, FontWeight.w600)),
            const SizedBox(height: 8),
            Center(
              child: mark(
                _Spot.tabs,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, t) in [tr('День'), tr('Календар'), tr('Місяць'), tr('Підсумок')].indexed)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: i == 0 ? scheme.primary : null, borderRadius: BorderRadius.circular(20)),
                        child: Text(t, style: st(11, i == 0 ? scheme.onPrimary : muted)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            divider,
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                mark(_Spot.colors, col(tr('Дохід'), '1 200,00 €', inc)),
                mark(_Spot.colors, col(tr('Витрати'), '25,00 €', red)),
                mark(_Spot.carry, col(tr('Разом'), '1 175,00 €', scheme.onSurface)),
              ],
            ),
            const SizedBox(height: 6),
            divider,
            const SizedBox(height: 6),
            Row(
              children: [
                Text('06', style: st(18, scheme.onSurface, FontWeight.w700)),
                const SizedBox(width: 6),
                Text(tr('пн'), style: st(11, muted)),
                const Spacer(),
                Text('25,00 €', style: st(12, red)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Їжа'), style: st(12, muted)),
                      if (spot == _Spot.time) mark(_Spot.time, Text('12:30', style: st(11, muted))),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(tr('Обід '), style: st(13, scheme.onSurface)),
                            mark(_Spot.note, Text(tr('бізнес-ланч'), style: st(13, muted, FontWeight.w400))),
                          ],
                        ),
                      ),
                      Text(tr('Готівка'), style: st(11, muted)),
                    ],
                  ),
                ),
                Text('25,00 €', style: st(13, red)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// MM «Введ. часу» as one key: none 0/1, input only 2/3, shown in lists 4/5; odd = ascending.
int _timeKey(Prefs p) => (p.timeMode == 0 ? 0 : (p.timeMode == 1 ? 2 : 4)) + (p.timeAsc ? 1 : 0);

/// MM «Дата поч. місяця»: a grid of days 1–31 and what to do when that day is a weekend.
class _MonthStartSheet extends StatelessWidget {
  const _MonthStartSheet();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pr = store.prefs;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final r = store.periodRange(store.currentPeriod);
    final last = r.end.subtract(const Duration(days: 1));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(tr('Початок місяця'), style: Theme.of(context).textTheme.titleMedium),
          ),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.25,
            children: [
              for (var d = 1; d <= 31; d++)
                Material(
                  color: d == pr.monthStartDay ? scheme.primary : panelColor(context),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => store.updatePrefs((p) => p.monthStartDay = d),
                    child: Center(
                      child: Text(
                        '$d',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: d == pr.monthStartDay ? FontWeight.w700 : FontWeight.w500,
                          color: d == pr.monthStartDay ? scheme.onPrimary : scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text(tr('Якщо цей день — вихідний:'), style: TextStyle(fontSize: 13, color: muted)),
          ),
          for (final (v, l) in [(0, tr('Без змін')), (1, tr('Попередня пʼятниця')), (2, tr('Наступний понеділок'))])
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              dense: true,
              title: Text(l, style: const TextStyle(fontSize: 15)),
              trailing: pr.monthStartShift == v ? Icon(Icons.check_rounded, color: scheme.primary) : null,
              onTap: () => store.updatePrefs((p) => p.monthStartShift = v),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              tr('Поточний місяць: {0} – {1}. ', [DateFormat('d.M.yyyy').format(r.start), DateFormat('d.M.yyyy').format(last)]) +
              tr('Якщо в місяці немає обраного дня, він починається в останній день.'),
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Копіювання записів (MM: Copy-Paste Settings) -------------------------------------

class _CopyPastePage extends StatelessWidget {
  const _CopyPastePage();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pr = store.prefs;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Копіювання записів'))),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          _Group(
            children: [
              _Item(null, tr('Копіювання'), value: _onOff(pr.copyPaste), onTap: () => store.updatePrefs((p) => p.copyPaste = !p.copyPaste)),
              if (pr.copyPaste)
                _Item(
                  null,
                  tr('Дата копії'),
                  value: pr.copyToToday ? tr('Сьогодні') : tr('Як в оригіналі'),
                  onTap: () => store.updatePrefs((p) => p.copyToToday = !p.copyToToday),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(tr('Коли увімкнено, у відкритому записі є кнопка «Копіювати».'), style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

// ---- Повторювані записи (MM: Repeat Setting) ----------------------------------------

class RepeatsPage extends StatefulWidget {
  const RepeatsPage({super.key});

  @override
  State<RepeatsPage> createState() => _RepeatsPageState();
}

class _RepeatsPageState extends State<RepeatsPage> {
  bool _delete = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final p = AppPalette.of(context);
    final now = DateTime.now();
    final line = scheme.onSurface.withValues(alpha: 0.08);
    final rules = [...store.repeats]..sort((a, b) => (a.nextAfter(now) ?? DateTime(9999)).compareTo(b.nextAfter(now) ?? DateTime(9999)));
    Widget section(TxType type, String label, Color color) {
      final list = rules.where((r) => r.template.type == type).toList();
      if (list.isEmpty) return const SizedBox.shrink();
      // Like MM: what falls due in the coming month (today up to the same day next month).
      final from = DateTime(now.year, now.month, now.day), to = DateTime(now.year, now.month + 1, now.day);
      var total = 0;
      for (final r in list) {
        for (final d in r.occurrences) {
          if (!d.isBefore(to) || (r.end != null && d.isAfter(r.end!))) break;
          if (!d.isBefore(from)) total += store.repeatBase(r.template);
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15)),
                ),
                if (type != TxType.transfer) Text(money(total, store.baseCurrency), style: TextStyle(color: color, fontSize: 16)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: panelColor(context),
              border: Border(top: BorderSide(color: line)),
            ),
            child: Column(children: [for (final r in list) _row(context, store, r, now, color, line)]),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Повторювані записи')),
        actions: [
          IconButton(
            tooltip: tr('Видалення'),
            icon: Icon(_delete ? Icons.check_rounded : Icons.delete_outline_rounded),
            onPressed: () => setState(() => _delete = !_delete),
          ),
          IconButton(
            tooltip: tr('Новий повторюваний запис'),
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Заповни запис і натисни ⟳ «Повтор» біля дати'))));
              openTxnEditor(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _Group(
            children: [
              _Item(
                null,
                tr('Коли створювати записи'),
                value: store.prefs.repeatInAdvance ? tr('Наперед на період') : tr('У день платежу'),
                onTap: () async {
                  final v = await _choose<bool>(context, tr('Коли створювати записи'), {
                    false: tr('У день платежу'),
                    true: tr('Наперед на весь період'),
                  }, store.prefs.repeatInAdvance);
                  if (v == null) return;
                  await store.updatePrefs((p) => p.repeatInAdvance = v);
                  await store.runRepeats();
                },
              ),
            ],
          ),
          if (rules.isEmpty) EmptyState(icon: Icons.repeat_rounded, text: tr('Повторюваних записів ще немає.\nДодай запис і натисни ⟳ «Повтор» біля дати.')),
          section(TxType.income, tr('Доходи'), incomeColor(context, store)),
          section(TxType.expense, tr('Витрати'), p.expense),
          section(TxType.transfer, tr('Перекази'), scheme.onSurface),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AppStore store, RepeatRule r, DateTime now, Color color, Color line) {
    final scheme = Theme.of(context).colorScheme;
    final t = r.template;
    final next = r.nextAfter(now);
    final top = store.topCategory(t.categoryId);
    final cat = store.category(t.categoryId);
    final catText = t.type == TxType.transfer
        ? '${store.account(t.accountId)?.name ?? ''} → ${store.account(t.toAccountId)?.name ?? ''}'
        : [top?.name, if (cat != null && top != null && cat.id != top.id) cat.name].whereType<String>().join('/');
    final acc = t.type == TxType.transfer ? '' : store.account(t.accountId)?.name ?? '';
    final cur = store.shownCurrency(t);
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 13);
    return InkWell(
      onTap: () => openTxnEditor(context, repeat: r),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: line)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
        child: Row(
          children: [
            if (_delete)
              IconButton(
                icon: const MinusBadge(),
                onPressed: () async {
                  if (await _confirm(context, tr('Зупинити повтор?'), tr('Нові записи більше не створюватимуться. Уже створені залишаться.'))) {
                    await store.deleteRepeat(r);
                  }
                },
              ),
            SizedBox(
              width: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(next == null ? tr('завершено') : '${next.day}.${next.month}.', style: muted),
                  Text(repeatLabel(r.every), maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.note.isNotEmpty ? t.note : txnTitle(store, t), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
                  Text([catText, acc].where((s) => s.isNotEmpty).join('   '), maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(money(store.shownAmount(t), cur), style: TextStyle(color: color, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ---- Рахунки (MM: Accounts) -----------------------------------------------------------

/// Account settings (MM: the pencil on the account picker).
Widget accountsSettingsPage() => const _AccountsMenu();

class _AccountsMenu extends StatelessWidget {
  const _AccountsMenu();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Рахунки'))),
      body: ListView(
        children: [
          _Group(
            children: [
              _Item(null, tr('Групи рахунків'), onTap: () => _push(context, const _AccountGroupsPage())),
              _Item(null, tr('Рахунки'), onTap: () => _push(context, const EditAccountsPage())),
              _Item(null, tr('Враховувати в підсумках'), onTap: () => _push(context, const _AccountFlagsPage(transfer: false))),
              _Item(null, tr('Налаштування Переказ-Витрата'), onTap: () => _push(context, const _AccountFlagsPage(transfer: true))),
              _Item(
                null,
                tr('Видалені рахунки'),
                value: store.deletedAccounts.isEmpty ? null : '${store.deletedAccounts.length}',
                onTap: () => _push(context, const _DeletedAccountsPage()),
              ),
              _Item(
                null,
                tr('Відображення витрат по карті'),
                value: store.prefs.cardDisplay == 'balance' ? tr('B. Як залишок') : tr('A. На момент'),
                onTap: () => _cardDisplay(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _cardDisplay(BuildContext context) async {
  final store = StoreScope.read(context);
  final v = await showSheetDialog<String>(
    context: context,
    builder: (context) {
      final cur = store.prefs.cardDisplay;
      Widget opt(String key, String label) => ListTile(
        title: Text(label, style: TextStyle(color: key == cur ? Theme.of(context).colorScheme.primary : null)),
        trailing: key == cur ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary) : null,
        onTap: () => Navigator.pop(context, key),
      );
      return AlertDialog(
        title: Text(tr('Відображення витрат по карті')),
        contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                tr('Для карток із датою розрахунку. A: витрати видно лише в балансі на момент покупки. ') +
                tr('B: на картці окремо видно суму до сплати за закритий період і витрати поточного періоду.'),
              ),
            ),
            opt('moment', tr('A. На момент')),
            opt('balance', tr('B. Як залишок')),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Скасувати')))],
      );
    },
  );
  if (v != null) await store.updatePrefs((p) => p.cardDisplay = v);
}

class _AccountGroupsPage extends StatelessWidget {
  const _AccountGroupsPage();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final groups = <String, List<Account>>{};
    for (final a in store.accounts) {
      groups.putIfAbsent(groupOf(a), () => []).add(a);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Групи рахунків')),
        actions: [IconButton(tooltip: tr('Новий рахунок'), icon: const Icon(Icons.add_rounded), onPressed: () => editAccount(context))],
      ),
      body: ListView(
        children: [
          _Group(
            children: [
              for (final e in groups.entries)
                _Item(
                  null,
                  e.key,
                  subtitle: e.value.map((a) => a.name).join(', '),
                  value: '${e.value.length}',
                  onTap: () async {
                    final v = await _askText(context, tr('Назва групи'), initial: e.key);
                    if (v == null || v.isEmpty || v == e.key) return;
                    for (final a in e.value) {
                      await store.saveAccount(a.copyWith(group: v));
                    }
                  },
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(tr('Торкнись групи, щоб перейменувати. Групу рахунку можна змінити й у самому рахунку.'), style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Switch list per account: include in totals, or count transfers into it as expenses.
class _AccountFlagsPage extends StatelessWidget {
  const _AccountFlagsPage({required this.transfer});
  final bool transfer;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    // MM: transfer-expense is not offered for cash, bank and card accounts.
    final list = transfer ? store.accounts.where((a) => a.kind != AccountKind.bank && a.kind != AccountKind.card && !a.isCard).toList() : store.accounts;
    final groups = <String, List<Account>>{};
    for (final a in list) {
      groups.putIfAbsent(groupOf(a), () => []).add(a);
    }
    bool checked(Account a) => transfer ? store.prefs.transferExpense.contains(a.id) : a.includeInTotal;
    void toggle(Account a) {
      final v = !checked(a);
      transfer
          ? store.updatePrefs((p) => p.transferExpense = v ? [...p.transferExpense, a.id] : ([...p.transferExpense]..remove(a.id)))
          : store.saveAccount(a.copyWith(includeInTotal: v));
    }

    return Scaffold(
      appBar: AppBar(title: Text(transfer ? tr('Переказ-Витрата') : tr('Враховувати в підсумках'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Container(
            color: panelColor(context),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Text(
              transfer
                  ? tr('Сума, переказана зі звичайного рахунку на вибраний рахунок, показується як витрата на вкладках «Записи» та «Статистика». ') +
                        tr('Це зручно для рахунків, з яких гроші важко швидко повернути: заощадження, інвестиції, позики, страхування. ') +
                        tr('Для готівки, банківських рахунків і карток цього налаштування немає. ') +
                        tr('Сума, переказана з вибраного рахунку на звичайний, показується як дохід.')
                  : tr('Позначені рахунки входять у загальні суми активів, пасивів і «Разом».'),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14, height: 1.35),
            ),
          ),
          for (final e in groups.entries) ...[
            _Band(e.key),
            _Group(
              children: [
                for (final a in e.value)
                  InkWell(
                    onTap: () => toggle(a),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: checked(a) ? scheme.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: checked(a) ? scheme.primary : scheme.outline, width: 1.5),
                            ),
                            child: checked(a) ? Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary) : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Text(a.name, style: const TextStyle(fontSize: 16))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DeletedAccountsPage extends StatelessWidget {
  const _DeletedAccountsPage();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.deletedAccounts;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Видалені рахунки'))),
      body: ListView(
        children: [
          if (list.isEmpty)
            EmptyState(icon: Icons.delete_outline_rounded, text: tr('Видалених рахунків немає'))
          else
            _Group(
              children: [
                for (final a in list) _Item(null, a.name, subtitle: groupOf(a), value: tr('Відновити'), onTap: () => store.saveAccount(a.copyWith(deleted: false))),
              ],
            ),
        ],
      ),
    );
  }
}

// ---- Бюджет (MM: Budget Setting) -------------------------------------------------------

/// Budget settings (MM "Налашт. бюджету"), opened from Stats → Бюджет too.
Widget budgetSettingsPage([TxType type = TxType.expense]) => _BudgetPage(type: type);

class _BudgetPage extends StatefulWidget {
  const _BudgetPage({this.type = TxType.expense});
  final TxType type;

  @override
  State<_BudgetPage> createState() => _BudgetPageState();
}

/// Budget key → the budget in the base currency, if any.
Budget? _budgetOf(AppStore store, String? key) => store.budgets.where((b) => b.categoryId == key && b.currency == store.baseCurrency).firstOrNull;

class _BudgetPageState extends State<_BudgetPage> {
  late TxType _type = widget.type;
  final _open = <String>{};
  late DateTime _month = StoreScope.read(context).currentPeriod;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final p = AppPalette.of(context);
    final cur = store.baseCurrency;
    final cats = store.categoriesOf(_type);
    final muted = scheme.onSurfaceVariant;
    int at(String? key) => _budgetOf(store, key)?.amountAt(_month) ?? 0;
    // MM: transfer-expense accounts count as expense under their group; the
    // group row opens to «<group> (Все)» and one row per account.
    final groups = <String, List<Account>>{};
    if (_type == TxType.expense) {
      for (final a in store.accounts) {
        if (store.prefs.transferExpense.contains(a.id)) groups.putIfAbsent(groupOf(a), () => []).add(a);
      }
    }
    final line = scheme.onSurface.withValues(alpha: 0.08);
    final accent = _type == TxType.expense ? p.expense : incomeColor(context, store);

    Widget tab(TxType t, String label) => Expanded(
      child: InkWell(
        onTap: () => setState(() => _type = t),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _type == t ? accent : line, width: _type == t ? 3 : 1),
            ),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 16, color: _type == t ? scheme.onSurface : muted)),
        ),
      ),
    );

    Widget row(String title, int amount, {String? subtitle, double indent = 16, Color? bg, VoidCallback? onTap}) => Material(
      color: bg ?? panelColor(context),
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: EdgeInsets.fromLTRB(indent, 7, 16, 7),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16)),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                  ],
                ),
              ),
              if (amount != 0) Text(money(amount, cur), style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );

    void open(String key, String name) => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AuroraBackground(
          child: _BudgetCategoryPage(budgetKey: key, name: name),
        ),
      ),
    );
    void toggle(String k) => setState(() => _open.contains(k) ? _open.remove(k) : _open.add(k));
    final sub = Color.lerp(panelColor(context), Colors.black, 0.18);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Налашт. бюджету')), centerTitle: true),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
                Expanded(
                  child: Text(
                    monthTitle(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
              ],
            ),
          ),
          Row(children: [tab(TxType.income, tr('Дохід')), tab(TxType.expense, tr('Витр.'))]),
          Expanded(
            child: cats.isEmpty && groups.isEmpty
                ? EmptyState(icon: Icons.track_changes_rounded, text: tr('Спершу додай категорії'))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 40),
                    children: [
                      for (final c in cats) ...[
                        () {
                          final subs = store.subcategoriesOf(c.id);
                          // MM: a main category with no budget shows the sum of its subcategories'.
                          final own = at(c.id);
                          final total = own != 0 ? own : subs.fold<int>(0, (s, x) => s + at(x.id));
                          return row(
                            c.name,
                            total,
                            subtitle: subs.map((s) => s.name).join('  '),
                            onTap: subs.isEmpty ? () => open(c.id, c.name) : () => toggle(c.id),
                          );
                        }(),
                        if (_open.contains(c.id)) ...[
                          row(tr('{0} (Все)', [c.name]), at(c.id), indent: 28, bg: sub, onTap: () => open(c.id, c.name)),
                          for (final x in store.subcategoriesOf(c.id)) row(x.name, at(x.id), indent: 28, bg: sub, onTap: () => open(x.id, x.name)),
                        ],
                      ],
                      for (final e in groups.entries) ...[
                        row(
                          e.key,
                          at('grp:${e.key}') + e.value.fold<int>(0, (s, a) => s + at('acc:${a.id}')),
                          subtitle: e.value.map((a) => a.name).join('  '),
                          onTap: () => toggle('grp:${e.key}'),
                        ),
                        if (_open.contains('grp:${e.key}')) ...[
                          row(tr('{0} (Все)', [e.key]), at('grp:${e.key}'), indent: 28, bg: sub, onTap: () => open('grp:${e.key}', tr('{0} (Все)', [e.key]))),
                          for (final a in e.value) row(a.name, at('acc:${a.id}'), indent: 28, bg: sub, onTap: () => open('acc:${a.id}', a.name)),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// MM: one category's budget — the default and each month of a year.
class _BudgetCategoryPage extends StatefulWidget {
  const _BudgetCategoryPage({required this.budgetKey, required this.name});
  final String budgetKey;
  final String name;

  @override
  State<_BudgetCategoryPage> createState() => _BudgetCategoryPageState();
}

class _BudgetCategoryPageState extends State<_BudgetCategoryPage> {
  late int _year = StoreScope.read(context).currentPeriod.year;

  Future<int?> _ask(String title, int initial) async {
    final cur = StoreScope.read(context).baseCurrency;
    final ctrl = TextEditingController(text: initial == 0 ? '' : minorToInput(initial, cur));
    ctrl.selection = TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
    final v = await showSheetDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: cur, hintText: '0'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Скасувати'))),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: Text(tr('Зберегти'))),
        ],
      ),
    );
    return v == null ? null : parseMoney(v, cur) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final red = AppPalette.of(context).expense;
    final cur = store.baseCurrency;
    final now = store.currentPeriod;
    final b = _budgetOf(store, widget.budgetKey);
    final line = scheme.onSurface.withValues(alpha: 0.08);
    Budget base() => b ?? Budget(categoryId: widget.budgetKey, amount: 0, currency: cur);
    final monthName = DateFormat('LLL', 'uk');

    Widget row(Widget lead, int amount, VoidCallback onTap) => Material(
      color: panelColor(context),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: line)),
          ),
          child: Row(
            children: [
              Expanded(child: lead),
              Text(money(amount, cur), style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        centerTitle: true,
        actions: [
          if (b != null)
            IconButton(
              tooltip: tr('Видалити бюджет'),
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                if (await _confirm(context, tr('Видалити бюджет «{0}»?', [widget.name]), tr('Бюджет цієї категорії буде прибрано з усіх місяців.'))) {
                  await store.saveBudget(b.copyWith(deleted: true));
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => setState(() => _year--)),
                Expanded(
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => setState(() => _year++)),
              ],
            ),
          ),
          _InfoHeader(
            Icons.edit_note_rounded,
            tr('Бюджет можна налаштувати на кожен місяць. Зміна бюджету за замовчуванням діє з поточного місяця далі. ') +
            tr('Якщо бюджет основної категорії нульовий, показується сума бюджетів підкатегорій.'),
          ),
          row(Text(tr('Бюджет за замовчуванням'), style: TextStyle(fontSize: 16)), b?.amountAt(now) ?? 0, () async {
            final v = await _ask(tr('Бюджет за замовчуванням'), b?.amountAt(now) ?? 0);
            if (v != null) await store.saveBudget(base().withDefault(v, now));
          }),
          for (var m = 12; m >= 1; m--)
            () {
              final month = DateTime(_year, m);
              final isNow = month == now;
              return row(
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: isNow ? red : scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      monthName.format(month),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: isNow ? red : scheme.onSurfaceVariant),
                    ),
                  ),
                ),
                b?.amountAt(month) ?? 0,
                () async {
                  final v = await _ask(monthTitle(month), b?.amountAt(month) ?? 0);
                  if (v != null) await store.saveBudget(base().withMonth(month, v));
                },
              );
            }(),
        ],
      ),
    );
  }
}

// ---- Теги (MM: Tag Settings) -------------------------------------------------------------

class _TagsPage extends StatelessWidget {
  const _TagsPage();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final tags = store.tags();
    final cur = store.baseCurrency;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Теги')),
        actions: [
          IconButton(
            tooltip: tr('Новий тег'),
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final v = await _askText(context, tr('Новий тег'), hint: tr('наприклад, відпустка'));
              final t = v?.replaceAll('#', '').trim().replaceAll(RegExp(r'\s+'), '_');
              if (t == null || t.isEmpty) return;
              store.updatePrefs((p) => p.savedTags = {...p.savedTags, t}.toList());
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          _InfoHeader(
            Icons.sell_outlined,
            tr('Теги додають до запису додаткову інформацію. Наприклад, тег «відпустка» допоможе швидко знайти всі витрати на поїздку.'),
          ),
          const SizedBox(height: 12),
          if (tags.isNotEmpty)
            _Group(
              children: [
                for (final t in tags)
                  _Item(
                    Icons.tag_rounded,
                    t.tag,
                    subtitle: '${t.count} ${t.count == 1 ? tr('запис') : tr('записів')}',
                    value: t.count == 0 ? null : money(t.sum, cur, sign: true),
                    trailing: t.count == 0 && store.prefs.savedTags.contains(t.tag)
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => store.updatePrefs((p) => p.savedTags = [...p.savedTags]..remove(t.tag)),
                          )
                        : null,
                    onTap: t.count == 0 ? null : () => _showTag(context, t.tag),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _showTag(BuildContext context, String tag) {
    final store = StoreScope.read(context);
    final list = store.txns.where((t) => '${t.note} ${t.memo}'.toLowerCase().contains('#$tag')).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text('#$tag', style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final t in list) TxnTile(txn: t),
          ],
        ),
      ),
    );
  }
}

// ---- Резервна копія (MM: Backup) --------------------------------------------------

class _BackupPage extends StatefulWidget {
  const _BackupPage();

  @override
  State<_BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<_BackupPage> {
  final _persisted = persistStorage();

  static Map<int, String> get _remind => {1: tr('Щодня'), 7: tr('Щотижня'), 30: tr('Щомісяця'), 0: tr('Ніколи')};

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = store.prefs;
    final last = p.lastBackup == 0 ? tr('Ще не було') : DateFormat('d MMM y, HH:mm', 'uk').format(DateTime.fromMillisecondsSinceEpoch(p.lastBackup));
    return Scaffold(
      appBar: AppBar(title: Text(tr('Резервна копія'))),
      body: ListView(
        children: [
          _Band(tr('Захист даних')),
          _Group(
            children: [
              _Item(null, tr('Остання копія'), value: last),
              _Item(
                null,
                tr('Нагадувати про копію'),
                value: _remind[p.backupRemindDays] ?? tr('{0} дн.', [p.backupRemindDays]),
                onTap: () async {
                  final v = await _choose<int>(
                    context,
                    tr('Нагадувати про копію'),
                    _remind,
                    p.backupRemindDays,
                    note: tr('На вкладці «Записи» зʼявиться нагадування, якщо з останньої копії минуло більше часу і є нові зміни.'),
                  );
                  if (v != null) await store.updatePrefs((p) => p.backupRemindDays = v);
                },
              ),
              FutureBuilder<bool?>(
                future: _persisted,
                builder: (context, s) => _Item(
                  null,
                  tr('Сховище браузера'),
                  subtitle: s.data == true ? tr('Браузер не стиратиме дані') : tr('Може стерти дані, якщо бракує місця'),
                  value: switch (s.data) {
                    true => tr('Захищене'),
                    false => tr('Не захищене'),
                    null => s.connectionState == ConnectionState.done ? tr('Невідомо') : '…',
                  },
                ),
              ),
              if (!isStandalone)
                _Item(null, tr('Додати на головний екран'), subtitle: tr('Як застосунок: надійніше й без інтернету'), onTap: () => showInstallHelp(context)),
            ],
          ),
          _Band(tr('Експорт / імпорт')),
          _Group(
            children: [
              _Item(null, tr('Поділитися копією'), subtitle: tr('iCloud Drive («Зберегти у Файли»), пошта, месенджери'), onTap: () => shareBackup(context)),
              _Item(null, tr('Зберегти резервну копію на пристрій'), onTap: () => _export(context)),
              _Item(null, tr('Відновити з резервної копії'), onTap: () => _import(context)),
              _Item(null, tr('Імпорт з Money Manager'), subtitle: tr('Файл резервної копії .mmbak'), onTap: () => _importMm(context)),
              _Item(null, tr('Експорт даних в Excel'), onTap: () => exportForPf(context)),
            ],
          ),
          _Band(tr('Інше')),
          _Group(
            children: [
              _Item(
                null,
                tr('Повне скидання'),
                danger: true,
                onTap: () async {
                  if (await _confirm(
                    context,
                    tr('Видалити всі дані?'),
                    tr('Усі записи, рахунки, категорії й налаштування буде видалено без можливості відновлення.'),
                  )) {
                    await store.resetAll();
                  }
                },
              ),
              _Item(
                null,
                tr('Скинути лише записи (решта залишиться)'),
                onTap: () async {
                  if (await _confirm(
                    context,
                    tr('Видалити всі записи?'),
                    tr('Записи, повтори й бюджети буде видалено. Рахунки, категорії й налаштування залишаться.'),
                  )) {
                    await store.resetContents();
                  }
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(tr('Дані зберігаються лише в цьому браузері. Роби резервну копію час від часу.'), style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

// ---- Нагадування (MM: Alarm Setting) -------------------------------------------------------

class _AlarmPage extends StatelessWidget {
  const _AlarmPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Нагадування'))),
    body: ListView(
      children: [
        _InfoHeader(Icons.notifications_none_rounded, tr('PFinance нагадає в обраний час дня внести витрати й доходи.')),
        const SizedBox(height: 12),
        _Group(
          children: [
            _Item(
              null,
              tr('Нагадування'),
              value: tr('скоро'),
              onTap: () => _info(
                context,
                tr('Нагадування'),
                tr('Щоденне нагадування працюватиме у версії застосунку для телефона. Браузер не вміє надійно надсилати сповіщення, коли сторінку закрито.'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ---- Стиль (MM: Style) ---------------------------------------------------------------

class _ThemePage extends StatelessWidget {
  const _ThemePage();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget radio(bool on) =>
        Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: on ? scheme.primary : scheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Стиль'))),
      body: ListView(
        children: [
          _Group(
            children: [
              for (final (m, icon) in const [
                (ThemeMode.system, Icons.sync_rounded),
                (ThemeMode.dark, Icons.dark_mode_outlined),
                (ThemeMode.light, Icons.light_mode_outlined),
              ])
                _Item(icon, _modeLabel(m), trailing: radio(store.themeMode == m), onTap: () => store.setThemeMode(m)),
            ],
          ),
          _Band(tr('Статистика')),
          _Group(
            children: [
              _Item(
                null,
                tr('Головний графік'),
                value: statsChartLabels[statsChartOf(store.prefs.statsChart)],
                onTap: () async {
                  final v = await _choose<StatsChart>(
                    context,
                    tr('Головний графік'),
                    statsChartLabels,
                    statsChartOf(store.prefs.statsChart),
                    note: tr('Графік над списком категорій у «Статистиці». Список і відсотки під ним однакові для всіх.'),
                  );
                  if (v != null) await store.updatePrefs((p) => p.statsChart = v.name);
                },
              ),
            ],
          ),
          _Band(tr('Колір акценту')),
          _Group(
            children: [
              for (final t in appThemes)
                _Item(
                  null,
                  t.name,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 14),
                      radio(store.themeId == t.id),
                    ],
                  ),
                  onTap: () => store.setTheme(t.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- Довідка --------------------------------------------------------------------

/// Help: sections of expandable topics with a search field on top.
List<(String, List<(String, String)>)> _helpSections() => [
  (tr('Початок'), [
    (
      tr('Як влаштований PFinance'),
      tr('Унизу чотири вкладки:\n• «Записи» — усі доходи, витрати й перекази по днях.\n• «Статистика» — на що йдуть гроші, бюджет і нотатки.\n• «Рахунки» — залишки на всіх рахунках.\n• «Більше» — налаштування, резервна копія й ця довідка.\nКругла кнопка «+» посередині додає новий запис з будь-якої вкладки.'),
    ),
    (
      tr('Перші кроки'),
      tr('1. «Більше → Основна валюта»: обери валюту, в якій рахуються всі підсумки.\n2. Вкладка «Рахунки» → «+»: додай рахунки (готівка, картки, заощадження) з їхніми поточними залишками.\n3. «Більше → Категорії витрат» і «Категорії доходів»: створи свої категорії. Готових категорій немає, щоб список був саме твоїм.\n4. Додай PFinance на головний екран телефона (див. «Дані й копії»).\n5. Вноси записи кнопкою «+».'),
    ),
  ]),
  (tr('Записи'), [
    (
      tr('Додати витрату або дохід'),
      tr('1. Натисни «+».\n2. Угорі обери тип: «Витрата», «Дохід» або «Переказ».\n3. У панелі знизу обери рахунок і категорію, введи суму на клавіатурі й натисни «ОК».\n4. За бажанням допиши «Нотатку» (наприклад, назву магазину) та «Опис» (подробиці).\n5. «Зберегти» закриває редактор. «Далі» зберігає запис і одразу відкриває новий з тими самими датою й рахунком.\nЩо вводиться першим, сума чи рахунок, задається в «Налаштування записів → Порядок введення».'),
    ),
    (
      tr('Дата й час'),
      tr('Торкнись дати вгорі редактора, щоб обрати інший день. «Сьогодні» повертає поточну дату. Час запису можна вводити, якщо його увімкнено в «Налаштування записів → Введення часу».'),
    ),
    (
      tr('Переказ між рахунками'),
      tr('Обери тип «Переказ», вкажи рахунки «Звідки» і «Куди» та суму. Кнопка зі стрілками міняє рахунки місцями. Якщо банк бере комісію, впиши її в поле «Комісія»: вона піде у витрати. Якщо рахунки в різних валютах, у полі «Зараховано» вкажи, скільки надійшло на другий рахунок.'),
    ),
    (
      tr('Сума в іншій валюті'),
      tr('Під час введення суми торкнись значка глобуса над клавіатурою й обери валюту. Запис зберігає суму так, як ти її ввів, а рахунок рахує її у своїй валюті. Курс береться на дату запису, тому старі записи не змінюються, коли курс змінюється. Потрібну валюту спершу додай у «Більше → Додаткові валюти».'),
    ),
    (
      tr('Змінити або видалити запис'),
      tr('Торкнись запису в списку, зміни потрібне й натисни «Зберегти». Значок кошика внизу редактора видаляє запис, застосунок перепитає. Якщо в «Налаштування записів → Свайп» обрано «Видалення запису», запис можна видалити свайпом, а «Повернути» на панелі знизу скасовує видалення.'),
    ),
    (
      tr('Копія запису'),
      tr('Увімкни «Більше → Копіювання записів». Тоді у відкритому записі буде кнопка «Копіювати»: вона створює такий самий запис на сьогодні або на дату оригіналу, як обрано в тих самих налаштуваннях.'),
    ),
    (
      tr('Шаблони'),
      tr('Зірочка вгорі редактора відкриває шаблони. «Зберегти поточний запис як шаблон» запамʼятовує тип, рахунок, категорію, суму й нотатку. Торкнись шаблону, щоб заповнити ним новий запис. Зручно для частих записів: оренда, кава, проїзд.'),
    ),
    (
      tr('Підказки нотаток'),
      tr('Коли пишеш нотатку, зʼявляються схожі нотатки з попередніх записів. Вибір підказки заповнює категорію, рахунок і суму. Вимикається в «Налаштування записів → Автозаповнення».'),
    ),
    (
      tr('Теги'),
      tr('Кнопка «Тег» у редакторі додає тег до запису. Можна й просто написати в нотатці, наприклад, #відпустка. Підсумки за кожним тегом — у «Більше → Теги».'),
    ),
    (tr('Пошук'), tr('Лупа вгорі вкладки «Записи» шукає записи за нотаткою, категорією або рахунком.')),
  ]),
  (tr('Вкладка «Записи»'), [
    (
      tr('День, Календар, Місяць, Підсумок'),
      tr('• «День» — записи по днях із сумами за кожен день.\n• «Календар» — місяць сіткою. Торкнись дня, щоб побачити його записи або «Додати на цей день».\n• «Місяць» — підсумки за місяцями року й за тижнями місяця.\n• «Підсумок» — витрати за рахунками, бюджет, найближчі повтори й експорт в Excel.\nСтрілки біля назви періоду гортають місяці, а на «Місяці» — роки.'),
    ),
    (
      tr('Рядок підсумків'),
      tr('Під вкладками видно «Дохід», «Витрати» й «Разом» за період. Якщо увімкнено «Налаштування записів → Перенесення залишку», «Разом» включає залишок попередніх місяців.'),
    ),
    (
      tr('Свайп'),
      tr('Свайп ліворуч чи праворуч перемикає вкладки «День · Календар · Місяць · Підсумок». У «Налаштування записів → Свайп» можна обрати зміну періоду, видалення запису або вимкнути свайп.'),
    ),
  ]),
  (tr('Повторювані записи'), [
    (
      tr('Створити повтор'),
      tr('1. Заповни запис як звичайно.\n2. Торкнись «Повтор» біля дати й обери, як часто: щодня, у будні, щотижня, щомісяця, в кінці місяця, раз на рік тощо.\n3. Збережи запис. Далі такі записи створюватимуться самі.\nУ записі, створеному з повтору, біля рахунку видно період.'),
    ),
    (
      tr('Змінити або зупинити повтор'),
      tr('«Більше → Повторювані записи» показує всі повтори. Торкнись повтору, щоб змінити суму, категорію чи період, або зупини його: нові записи більше не створюватимуться, а вже створені залишаться. «Коли створювати записи»: у день платежу або наперед на весь період. Найближчі повтори видно у «Записи → Підсумок».'),
    ),
  ]),
  (tr('Статистика'), [
    (
      tr('Що є на вкладці'),
      tr('Угорі три вкладки: «Статистика», «Бюджет» і «Нотатки». Кнопка праворуч обирає період: тиждень, місяць, рік, довільний «Період», «Список» (категорії разом із їхніми записами) або «Тренд» (доходи й витрати за 6 місяців). Під назвою періоду перемикай «Доходи» і «Витрати».'),
    ),
    (
      tr('Графік і список категорій'),
      tr('Графік показує частки категорій, а список під ним — суми й відсотки від більшої до меншої. Торкнись категорії, щоб відкрити її записи й підкатегорії. Вигляд графіка змінюється в «Більше → Стиль → Головний графік».'),
    ),
    (
      tr('Як читати «троянду»'),
      tr('Кожна пелюстка — категорія: що довша пелюстка, то більше витрачено. Кольорові смуги в пелюстці — тижні місяця (у режимі «Рік» — квартали). Торкнись пелюстки або тижня в легенді, щоб виділити його.'),
    ),
    (
      tr('Нотатки'),
      tr('Записи згруповано за нотаткою: скільки разів і на яку суму. Торкнись «К-сть» або «Сума», щоб змінити сортування, і рядка, щоб побачити його записи.'),
    ),
  ]),
  (tr('Бюджет'), [
    (
      tr('Задати бюджет'),
      tr('«Статистика → Бюджет → Налашт. бюджету» або «Більше → Бюджет». Задай загальний бюджет і, за бажанням, ліміти для окремих категорій. Бюджет за замовчуванням діє з поточного місяця далі, а суму на окремий місяць можна змінити. Якщо бюджет основної категорії нульовий, показується сума бюджетів її підкатегорій.'),
    ),
    (
      tr('Як читати смугу бюджету'),
      tr('Смуга показує, яку частину ліміту вже витрачено: синя — у межах, червона — перевищено. Позначка «Сьогодні» показує, скільки мало б бути витрачено на цей день, щоб рівномірно вкластися в місяць. Під смугою — витрачена сума й залишок.'),
    ),
  ]),
  (tr('Рахунки'), [
    (
      tr('Вкладка «Рахунки»'),
      tr('Угорі «Активи», «Пасиви» й «Разом». Нижче рахунки за групами з поточними залишками. Сірим показано рахунки, що не входять у загальні підсумки.'),
    ),
    (
      tr('Додати чи змінити рахунок'),
      tr('«+» угорі додає рахунок: група, назва, валюта й початковий залишок. Довге натискання на рахунок відкриває його налаштування. Олівець угорі вмикає редагування списку: перетягни рахунок, щоб змінити порядок; значок ока приховує рахунок; кошик видаляє рахунок разом з його записами.'),
    ),
    (
      tr('Сторінка рахунку'),
      tr('Торкнись рахунку, щоб побачити його записи по днях, місяцях або роках: надходження, списання й баланс після кожного запису. «Графік» показує, як змінювався баланс.'),
    ),
    (
      tr('Кредитна картка'),
      tr('У налаштуваннях рахунку увімкни «Картка з датою розрахунку» й задай дату розрахунку, дату платежу та рахунок, з якого сплачується картка. Тоді на картці видно суму «До сплати» й поточний цикл. Як показувати витрати по картці — у «Більше → Рахунки → Відображення витрат по карті».'),
    ),
    (
      tr('Переказ-Витрата'),
      tr('«Більше → Рахунки → Налаштування Переказ-Витрата». Перекази на позначені рахунки (заощадження, інвестиції, позики) рахуються як витрати, а перекази з них — як доходи.'),
    ),
    (tr('Видалені рахунки'), tr('«Більше → Рахунки → Видалені рахунки»: тут видалений рахунок можна відновити.')),
  ]),
  (tr('Налаштування'), [
    (
      tr('Місяць від зарплати'),
      tr('«Налаштування записів → Початок місяця»: день 1–31, з якого починається місяць, і що робити, якщо він випадає на вихідний: без змін, попередня пʼятниця чи наступний понеділок.'),
    ),
    (
      tr('Тижні замість місяців'),
      tr('«Налаштування записів → Налаштування періоду → Тижні»: у «Записах» і «Статистиці» стрілки гортають тижні, а підсумки рахуються за тиждень. Календар і бюджет лишаються помісячними. Перший день тижня задається в «Початку тижня».'),
    ),
    (
      tr('Категорії'),
      tr('«Більше → Категорії витрат» або «Категорії доходів»: додай, перейменуй чи видали категорію, перетягни, щоб змінити порядок. Торкнись категорії, щоб додати підкатегорії. Значок-емодзі необовʼязковий. Записи видаленої категорії залишаються, але без категорії.'),
    ),
    (
      tr('Валюти й курси'),
      tr('«Основна валюта» — у ній рахуються всі підсумки. «Додаткові валюти» — інші валюти та їхні курси: введи курс вручну або натисни «Оновити курси», а «Оновлювати курси щодня» робить це автоматично. Там само налаштовуються символ спереду чи позаду суми й десяткові.'),
    ),
    (
      tr('Вигляд і мова'),
      tr('«Більше → Стиль»: світла чи темна тема, колір акценту й головний графік статистики. «Налаштування записів → Колір доходів і витрат»: зелені чи сині доходи. «Іконка застосунку» змінює значок на головному екрані, «Мова» — мову інтерфейсу.'),
    ),
    (
      tr('PIN-код'),
      tr('«Більше → PIN-код»: 4 цифри, які застосунок питатиме під час відкриття. Там само PIN-код можна змінити або вимкнути.'),
    ),
  ]),
  (tr('Дані й копії'), [
    (
      tr('Де зберігаються дані'),
      tr('Лише на цьому пристрої, у браузері. На сервер нічого не надсилається. Якщо очистити дані сайту в браузері або змінити телефон, записи зникнуть, тому регулярно роби резервну копію.'),
    ),
    (
      tr('Додати на головний екран'),
      tr('iPhone: відкрий PFinance у Safari → «Поділитися» → «На початковий екран» → «Додати». Android і комп’ютер: меню браузера → «Установити застосунок». Так PFinance відкривається на весь екран, працює без інтернету, а браузер не стирає дані.'),
    ),
    (
      tr('Резервна копія'),
      tr('«Більше → Резервна копія → Поділитися копією» зберігає файл в iCloud Drive («Зберегти у Файли»), пошту чи месенджер. «Відновити з резервної копії» повертає всі дані з такого файлу, поточні дані буде замінено. Якщо з останньої копії минуло більше днів, ніж задано в «Нагадувати про копію», і були зміни, на вкладці «Записи» зʼявиться нагадування.'),
    ),
    (
      tr('Перейти з Money Manager'),
      tr('«Резервна копія → Імпорт з Money Manager» і обери файл .mmbak. Рахунки, категорії, записи, повтори й бюджети буде замінено даними з файлу, налаштування вигляду залишаться.'),
    ),
    (
      tr('Експорт в Excel'),
      tr('«Резервна копія → Експорт даних в Excel» або кнопка внизу «Підсумку» створює таблицю з усіма записами. Цю таблицю імпортує дашборд PF.'),
    ),
    (
      tr('Скидання даних'),
      tr('«Скинути лише записи» видаляє записи, повтори й бюджети, а рахунки, категорії й налаштування залишає. «Повне скидання» видаляє все без можливості відновлення.'),
    ),
  ]),
];

class _HelpPage extends StatefulWidget {
  const _HelpPage();

  @override
  State<_HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<_HelpPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _query.trim().toLowerCase();
    final sections = [
      for (final (name, topics) in _helpSections())
        (name, [for (final t in topics) if (q.isEmpty || '${t.$1}\n${t.$2}'.toLowerCase().contains(q)) t]),
    ].where((s) => s.$2.isNotEmpty).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Довідка'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: tr('Пошук у довідці'),
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: hairline(context, 0.2))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: hairline(context, 0.2))),
              ),
            ),
          ),
          if (sections.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(tr('Нічого не знайдено'), textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          for (final (name, topics) in sections) ...[
            _Band(name),
            _Group(
              children: [
                for (final (t, d) in topics)
                  ExpansionTile(
                    key: PageStorageKey('$name/$t/${q.isNotEmpty}'),
                    initiallyExpanded: q.isNotEmpty,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    expandedAlignment: Alignment.centerLeft,
                    title: Text(t, style: const TextStyle(fontSize: 15)),
                    children: [Text(d, style: TextStyle(fontSize: 14, height: 1.45, color: scheme.onSurfaceVariant))],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
