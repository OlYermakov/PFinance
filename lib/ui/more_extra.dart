part of 'more_page.dart';

void _push(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => AuroraBackground(child: page)));

// ---- Налаштування записів (MM: Transaction Settings) -----------------------------

class _TxnSettingsPage extends StatelessWidget {
  const _TxnSettingsPage();

  static String startLabel(StartPage s) => switch (s) {
    StartPage.day => 'День',
    StartPage.calendar => 'Календар',
    StartPage.month => 'Місяць',
    StartPage.summary => 'Підсумок',
    StartPage.stats => 'Статистика',
    StartPage.accounts => 'Рахунки',
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

    const timeLabels = {
      0: 'Немає, спад.',
      1: 'Немає, зрост.',
      4: 'Показ у списку, спад.',
      5: 'Показ у списку, зрост.',
      2: 'Лише введення, спад.',
      3: 'Лише введення, зрост.',
    };
    const weekdays = {1: 'Понеділок', 2: 'Вівторок', 3: 'Середа', 4: 'Четвер', 5: 'Пʼятниця', 6: 'Субота', 7: 'Неділя'};
    const shiftLabels = {0: '', 1: ' · пт', 2: ' · пн'};
    const swipeLabels = {'tabs': 'Зміна вкладки', 'period': 'Зміна періоду', 'delete': 'Видалення запису', 'off': 'Вимкнено'};
    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування записів')),
      body: ListView(
        children: [
          _Group(
            children: [
              _Item(
                null,
                'Початок місяця',
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
                'Початок тижня',
                value: weekdays[pr.weekStart],
                onTap: () => pick<int>(
                  'Початок тижня',
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
                'Перенесення залишку',
                value: _onOff(pr.carryOver),
                onTap: () => pick<bool>(
                  'Перенесення залишку',
                  {false: 'Вимк.', true: 'Увімк.'},
                  pr.carryOver,
                  (p, v) => p.carryOver = v,
                  spot: _Spot.carry,
                  note: 'Перенесення додає залишок попередніх місяців до підсумку «Разом» поточного.',
                ),
              ),
              _Item(
                null,
                'Колір доходів і витрат',
                value: const {'green': 'Дохід зелений', 'blue': 'Дохід синій', 'accent': 'Дохід за акцентом'}[pr.incomeColor] ?? 'Дохід зелений',
                onTap: () => pick<String>(
                  'Колір доходів',
                  const {'green': 'Дохід зелений, витрати червоні', 'blue': 'Дохід синій, витрати червоні', 'accent': 'Дохід за акцентом, витрати червоні'},
                  pr.incomeColor,
                  (p, v) => p.incomeColor = v,
                  spot: _Spot.colors,
                ),
              ),
              _Item(
                null,
                'Автозаповнення',
                value: _onOff(pr.noteSuggestions),
                onTap: () => pick<bool>(
                  'Автозаповнення',
                  {false: 'Вимк.', true: 'Увімк.'},
                  pr.noteSuggestions,
                  (p, v) => p.noteSuggestions = v,
                  note: 'Під час введення нотатки показує схожі нотатки з попередніх записів. Вибір підказки заповнює категорію, рахунок і суму.',
                ),
              ),
              _Item(
                null,
                'Введення часу',
                value: timeLabels[_timeKey(pr)],
                onTap: () => pick<int>(
                  'Введення часу',
                  timeLabels,
                  _timeKey(pr),
                  (p, v) {
                    p.timeMode = v ~/ 2;
                    p.timeAsc = v.isOdd;
                  },
                  spot: _Spot.time,
                  note: '«Немає» — без часу; «Показ у списку» — час видно в записах; «Лише введення» — час лише в редакторі. Спад./зрост. — порядок записів у дні.',
                ),
              ),
              _Item(
                null,
                'Стартовий екран',
                value: startLabel(pr.startPage),
                onTap: () => pick<StartPage>(
                  'Стартовий екран',
                  {for (final s in StartPage.values) s: startLabel(s)},
                  pr.startPage,
                  (p, v) => p.startPage = v,
                  spot: _Spot.tabs,
                ),
              ),
              _Item(
                null,
                'Свайп',
                value: swipeLabels[pr.swipe],
                onTap: () => pick<String>('Свайп у списку записів', swipeLabels, pr.swipe, (p, v) => p.swipe = v),
              ),
              _Item(
                null,
                'Показувати нотатку',
                value: _onOff(pr.showNote),
                onTap: () => pick<bool>(
                  'Показувати нотатку',
                  {false: 'Вимк.', true: 'Увімк.'},
                  pr.showNote,
                  (p, v) => p.showNote = v,
                  spot: _Spot.note,
                  note: 'Нотатка запису показується в списку записів поруч із категорією.',
                ),
              ),
              _Item(
                null,
                'Порядок введення',
                value: pr.amountFirst ? 'Спершу сума' : 'Спершу рахунок',
                onTap: () => pick<bool>(
                  'Порядок введення',
                  {false: 'Спершу рахунок', true: 'Спершу сума'},
                  pr.amountFirst,
                  (p, v) => p.amountFirst = v,
                  note: 'З чого починається новий запис: з вибору рахунку чи з введення суми.',
                ),
              ),
              _Item(
                null,
                'Кнопка нотаток',
                value: _onOff(pr.noteButton),
                onTap: () => pick<bool>(
                  'Кнопка нотаток',
                  {false: 'Вимк.', true: 'Увімк.'},
                  pr.noteButton,
                  (p, v) => p.noteButton = v,
                  note: 'Показує в редакторі кнопку зі списком попередніх нотаток.',
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
            Text('Липень 2026', textAlign: TextAlign.center, style: st(13, scheme.onSurface, FontWeight.w600)),
            const SizedBox(height: 8),
            Center(
              child: mark(
                _Spot.tabs,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, t) in const ['День', 'Календар', 'Місяць', 'Підсумок'].indexed)
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
                mark(_Spot.colors, col('Дохід', '1 200,00 €', inc)),
                mark(_Spot.colors, col('Витрати', '25,00 €', red)),
                mark(_Spot.carry, col('Разом', '1 175,00 €', scheme.onSurface)),
              ],
            ),
            const SizedBox(height: 6),
            divider,
            const SizedBox(height: 6),
            Row(
              children: [
                Text('06', style: st(18, scheme.onSurface, FontWeight.w700)),
                const SizedBox(width: 6),
                Text('пн', style: st(11, muted)),
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
                      Text('Їжа', style: st(12, muted)),
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
                        child: mark(_Spot.note, Text('Обід', style: st(13, scheme.onSurface))),
                      ),
                      Text('Готівка', style: st(11, muted)),
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
            child: Text('Початок місяця', style: Theme.of(context).textTheme.titleMedium),
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
            child: Text('Якщо цей день — вихідний:', style: TextStyle(fontSize: 13, color: muted)),
          ),
          for (final (v, l) in const [(0, 'Без змін'), (1, 'Попередня пʼятниця'), (2, 'Наступний понеділок')])
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
              'Поточний місяць: ${DateFormat('d.M.yyyy').format(r.start)} – ${DateFormat('d.M.yyyy').format(last)}. '
              'Якщо в місяці немає обраного дня, він починається в останній день.',
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
      appBar: AppBar(title: const Text('Копіювання записів')),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          _Group(
            children: [
              _Item(null, 'Копіювання', value: _onOff(pr.copyPaste), onTap: () => store.updatePrefs((p) => p.copyPaste = !p.copyPaste)),
              if (pr.copyPaste)
                _Item(
                  null,
                  'Дата копії',
                  value: pr.copyToToday ? 'Сьогодні' : 'Як в оригіналі',
                  onTap: () => store.updatePrefs((p) => p.copyToToday = !p.copyToToday),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Коли увімкнено, у відкритому записі є кнопка «Копіювати».', style: Theme.of(context).textTheme.bodySmall),
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
        title: const Text('Повторювані записи'),
        actions: [
          IconButton(
            tooltip: 'Видалення',
            icon: Icon(_delete ? Icons.check_rounded : Icons.delete_outline_rounded),
            onPressed: () => setState(() => _delete = !_delete),
          ),
          IconButton(
            tooltip: 'Новий повторюваний запис',
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заповни запис і натисни ⟳ «Повтор» біля дати')));
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
                'Коли створювати записи',
                value: store.prefs.repeatInAdvance ? 'Наперед на період' : 'У день платежу',
                onTap: () async {
                  final v = await _choose<bool>(context, 'Коли створювати записи', {
                    false: 'У день платежу',
                    true: 'Наперед на весь період',
                  }, store.prefs.repeatInAdvance);
                  if (v == null) return;
                  await store.updatePrefs((p) => p.repeatInAdvance = v);
                  await store.runRepeats();
                },
              ),
            ],
          ),
          if (rules.isEmpty) const EmptyState(icon: Icons.repeat_rounded, text: 'Повторюваних записів ще немає.\nДодай запис і натисни ⟳ «Повтор» біля дати.'),
          section(TxType.income, 'Доходи', incomeColor(context, store)),
          section(TxType.expense, 'Витрати', p.expense),
          section(TxType.transfer, 'Перекази', scheme.onSurface),
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
                  if (await _confirm(context, 'Зупинити повтор?', 'Нові записи більше не створюватимуться. Уже створені залишаться.')) {
                    await store.deleteRepeat(r);
                  }
                },
              ),
            SizedBox(
              width: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(next == null ? 'завершено' : '${next.day}.${next.month}.', style: muted),
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
      appBar: AppBar(title: const Text('Рахунки')),
      body: ListView(
        children: [
          _Group(
            children: [
              _Item(null, 'Групи рахунків', onTap: () => _push(context, const _AccountGroupsPage())),
              _Item(null, 'Рахунки', onTap: () => _push(context, const EditAccountsPage())),
              _Item(null, 'Враховувати в підсумках', onTap: () => _push(context, const _AccountFlagsPage(transfer: false))),
              _Item(null, 'Налаштування Переказ-Витрата', onTap: () => _push(context, const _AccountFlagsPage(transfer: true))),
              _Item(
                null,
                'Видалені рахунки',
                value: store.deletedAccounts.isEmpty ? null : '${store.deletedAccounts.length}',
                onTap: () => _push(context, const _DeletedAccountsPage()),
              ),
              _Item(
                null,
                'Відображення витрат по карті',
                value: store.prefs.cardDisplay == 'balance' ? 'B. Як залишок' : 'A. На момент',
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
  final v = await showDialog<String>(
    context: context,
    builder: (context) {
      final cur = store.prefs.cardDisplay;
      Widget opt(String key, String label) => ListTile(
        title: Text(label, style: TextStyle(color: key == cur ? Theme.of(context).colorScheme.primary : null)),
        trailing: key == cur ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary) : null,
        onTap: () => Navigator.pop(context, key),
      );
      return AlertDialog(
        title: const Text('Відображення витрат по карті'),
        contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'Для карток із датою розрахунку. A: витрати видно лише в балансі на момент покупки. '
                'B: на картці окремо видно суму до сплати за закритий період і витрати поточного періоду.',
              ),
            ),
            opt('moment', 'A. На момент'),
            opt('balance', 'B. Як залишок'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати'))],
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
        title: const Text('Групи рахунків'),
        actions: [IconButton(tooltip: 'Новий рахунок', icon: const Icon(Icons.add_rounded), onPressed: () => editAccount(context))],
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
                    final v = await _askText(context, 'Назва групи', initial: e.key);
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
            child: Text('Торкнись групи, щоб перейменувати. Групу рахунку можна змінити й у самому рахунку.', style: Theme.of(context).textTheme.bodySmall),
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
      appBar: AppBar(title: Text(transfer ? 'Переказ-Витрата' : 'Враховувати в підсумках')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Container(
            color: panelColor(context),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Text(
              transfer
                  ? 'Сума, переказана зі звичайного рахунку на вибраний рахунок, показується як витрата на вкладках «Записи» та «Статистика». '
                        'Це зручно для рахунків, з яких гроші важко швидко повернути: заощадження, інвестиції, позики, страхування. '
                        'Для готівки, банківських рахунків і карток цього налаштування немає. '
                        'Сума, переказана з вибраного рахунку на звичайний, показується як дохід.'
                  : 'Позначені рахунки входять у загальні суми активів, пасивів і «Разом».',
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
      appBar: AppBar(title: const Text('Видалені рахунки')),
      body: ListView(
        children: [
          if (list.isEmpty)
            const EmptyState(icon: Icons.delete_outline_rounded, text: 'Видалених рахунків немає')
          else
            _Group(
              children: [
                for (final a in list) _Item(null, a.name, subtitle: groupOf(a), value: 'Відновити', onTap: () => store.saveAccount(a.copyWith(deleted: false))),
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
      appBar: AppBar(title: const Text('Налашт. бюджету'), centerTitle: true),
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
          Row(children: [tab(TxType.income, 'Дохід'), tab(TxType.expense, 'Витр.')]),
          Expanded(
            child: cats.isEmpty && groups.isEmpty
                ? const EmptyState(icon: Icons.track_changes_rounded, text: 'Спершу додай категорії')
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
                          row('${c.name} (Все)', at(c.id), indent: 28, bg: sub, onTap: () => open(c.id, c.name)),
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
                          row('${e.key} (Все)', at('grp:${e.key}'), indent: 28, bg: sub, onTap: () => open('grp:${e.key}', '${e.key} (Все)')),
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
    final v = await showDialog<String>(
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Зберегти')),
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
              tooltip: 'Видалити бюджет',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                if (await _confirm(context, 'Видалити бюджет «${widget.name}»?', 'Бюджет цієї категорії буде прибрано з усіх місяців.')) {
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
          const _InfoHeader(
            Icons.edit_note_rounded,
            'Бюджет можна налаштувати на кожен місяць. Зміна бюджету за замовчуванням діє з поточного місяця далі. '
            'Якщо бюджет основної категорії нульовий, показується сума бюджетів підкатегорій.',
          ),
          row(const Text('Бюджет за замовчуванням', style: TextStyle(fontSize: 16)), b?.amountAt(now) ?? 0, () async {
            final v = await _ask('Бюджет за замовчуванням', b?.amountAt(now) ?? 0);
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
        title: const Text('Теги'),
        actions: [
          IconButton(
            tooltip: 'Новий тег',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final v = await _askText(context, 'Новий тег', hint: 'наприклад, відпустка');
              final t = v?.replaceAll('#', '').trim().replaceAll(RegExp(r'\s+'), '_');
              if (t == null || t.isEmpty) return;
              store.updatePrefs((p) => p.savedTags = {...p.savedTags, t}.toList());
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          const _InfoHeader(
            Icons.sell_outlined,
            'Теги додають до запису додаткову інформацію. Наприклад, тег «відпустка» допоможе швидко знайти всі витрати на поїздку.',
          ),
          const SizedBox(height: 12),
          if (tags.isNotEmpty)
            _Group(
              children: [
                for (final t in tags)
                  _Item(
                    Icons.tag_rounded,
                    t.tag,
                    subtitle: '${t.count} ${t.count == 1 ? 'запис' : 'записів'}',
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
    final list = store.txns.where((t) => t.note.toLowerCase().contains('#$tag')).toList();
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

class _BackupPage extends StatelessWidget {
  const _BackupPage();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Резервна копія')),
      body: ListView(
        children: [
          const _Band('Експорт / імпорт'),
          _Group(
            children: [
              _Item(null, 'Поділитися копією', subtitle: 'iCloud Drive («Зберегти у Файли»), пошта, месенджери', onTap: () => _shareBackup(context)),
              _Item(null, 'Зберегти резервну копію на пристрій', onTap: () => _export(context)),
              _Item(null, 'Відновити з резервної копії', onTap: () => _import(context)),
              _Item(null, 'Імпорт з Money Manager', subtitle: 'Файл резервної копії .mmbak', onTap: () => _importMm(context)),
              _Item(null, 'Експорт даних в Excel', onTap: () => exportForPf(context)),
            ],
          ),
          const _Band('Інше'),
          _Group(
            children: [
              _Item(
                null,
                'Повне скидання',
                danger: true,
                onTap: () async {
                  if (await _confirm(
                    context,
                    'Видалити всі дані?',
                    'Усі записи, рахунки, категорії й налаштування буде видалено без можливості відновлення.',
                  )) {
                    await store.resetAll();
                  }
                },
              ),
              _Item(
                null,
                'Скинути лише записи (решта залишиться)',
                onTap: () async {
                  if (await _confirm(
                    context,
                    'Видалити всі записи?',
                    'Записи, повтори й бюджети буде видалено. Рахунки, категорії й налаштування залишаться.',
                  )) {
                    await store.resetContents();
                  }
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Дані зберігаються лише в цьому браузері. Роби резервну копію час від часу.', style: Theme.of(context).textTheme.bodySmall),
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
    appBar: AppBar(title: const Text('Нагадування')),
    body: ListView(
      children: [
        const _InfoHeader(Icons.notifications_none_rounded, 'PFinance нагадає в обраний час дня внести витрати й доходи.'),
        const SizedBox(height: 12),
        _Group(
          children: [
            _Item(
              null,
              'Нагадування',
              value: 'скоро',
              onTap: () => _info(
                context,
                'Нагадування',
                'Щоденне нагадування працюватиме у версії застосунку для телефона. Браузер не вміє надійно надсилати сповіщення, коли сторінку закрито.',
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
      appBar: AppBar(title: const Text('Стиль')),
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
          const _Band('Колір акценту'),
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

class _HelpPage extends StatelessWidget {
  const _HelpPage();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        'Додати запис',
        'Кнопка «+» внизу. Обери рахунок, категорію й суму. «Зберегти» закриває редактор, «Далі» зберігає й одразу відкриває наступний запис з тими самими датою й рахунком.',
      ),
      (
        'Сума в іншій валюті',
        'Під час введення суми над клавіатурою є рядок валют: обери потрібну. Запис збереже суму як ти її ввів, а рахунок рахуватиме у своїй валюті.',
      ),
      ('Змінити або видалити', 'Торкнись запису, щоб відкрити його. Кошик унизу редактора видаляє запис.'),
      (
        'Свайп',
        'Свайп ліворуч чи праворуч у «Записах» перемикає вкладки «День · Календар · Місяць · Підсумок». Інше можна обрати в «Налаштування записів → Свайп».',
      ),
      ('Копія запису', 'Відкрий запис і натисни кнопку копіювання. Увімкнути її можна в «Копіювання записів».'),
      ('Шаблони', 'Зірочка вгорі редактора: збережи запис як шаблон або заповни з шаблону.'),
      (
        'Повторювані записи',
        'Під час додавання натисни ⟳ «Повтор» біля дати й обери період. Усі повтори — у «Більше → Повторювані записи»; торкнись повтору, щоб змінити його. У записі, створеному з повтору, біля дати видно період.',
      ),
      ('Місяць від зарплати', '«Налаштування записів» → «Початок місяця»: день 1–31 і що робити, якщо він випадає на вихідний.'),
      ('Бюджет', '«Більше → Бюджет»: суму можна задати за замовчуванням або окремо на кожен місяць. Залишок видно у «Статистика → Бюджет» і в «Підсумку».'),
      ('Статистика', 'Пелюстки «троянди» — категорії, кольори в пелюстці — тижні місяця. Торкнись пелюстки або тижня в легенді, щоб виділити.'),
      ('Теги', 'Кнопка «+ Тег» у редакторі або #тег у нотатці. Підсумки — у «Більше → Теги».'),
      (
        'Перейти з Money Manager',
        '«Резервна копія» → «Імпорт з Money Manager»: файл .mmbak. Записи, рахунки, категорії, повтори й бюджети буде замінено даними з файлу.',
      ),
      ('Перенести в PF', '«Резервна копія» → «Експорт даних в Excel» (або кнопка в «Підсумку») створює файл, який імпортує дашборд PF.'),
      ('Резервна копія', '«Поділитися копією» зберігає файл у iCloud Drive, пошту чи месенджер; «Відновити» повертає дані з нього.'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Довідка')),
      body: ListView(
        children: [
          _Group(
            children: [
              for (final (t, d) in items)
                ListTile(
                  title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(d),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
