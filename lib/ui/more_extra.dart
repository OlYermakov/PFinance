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
    Future<void> pick<T>(String title, Map<T, String> options, T current, void Function(Prefs p, T v) set) async {
      final v = await _choose<T>(context, title, options, current);
      if (v != null) store.updatePrefs((p) => set(p, v));
    }

    const timeLabels = {0: 'Не вводити', 1: 'Лише введення', 2: 'Введення й показ'};
    const swipeLabels = {'period': 'Зміна періоду', 'delete': 'Видалення запису', 'off': 'Вимкнено'};
    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування записів')),
      body: ListView(children: [
        _Group(children: [
          _Item(null, 'Початок місяця', value: '${pr.monthStartDay}',
              onTap: () => pick<int>('Місяць починається', {for (var d = 1; d <= 28; d++) d: '$d-го числа'}, pr.monthStartDay, (p, v) => p.monthStartDay = v)),
          _Item(null, 'Початок тижня', value: pr.weekStartsMonday ? 'Понеділок' : 'Неділя',
              onTap: () => pick<bool>('Тиждень починається', {true: 'Понеділок', false: 'Неділя'}, pr.weekStartsMonday, (p, v) => p.weekStartsMonday = v)),
          _Item(null, 'Перенесення залишку', value: _onOff(pr.carryOver),
              onTap: () => pick<bool>('Перенесення залишку з минулих періодів', {true: 'Увімк.', false: 'Вимк.'}, pr.carryOver, (p, v) => p.carryOver = v)),
          _Item(null, 'Колір доходів і витрат', value: pr.incomeBlue ? 'Дохід синій' : 'Дохід зелений',
              onTap: () => pick<bool>('Колір доходів', {false: 'Дохід зелений, витрати червоні', true: 'Дохід синій, витрати червоні'}, pr.incomeBlue,
                  (p, v) => p.incomeBlue = v)),
          _Item(null, 'Автозаповнення', value: _onOff(pr.noteSuggestions),
              onTap: () => pick<bool>('Підказки нотаток під час введення', {true: 'Увімк.', false: 'Вимк.'}, pr.noteSuggestions, (p, v) => p.noteSuggestions = v)),
          _Item(null, 'Час', value: timeLabels[pr.timeMode], onTap: () => pick<int>('Час запису', timeLabels, pr.timeMode, (p, v) => p.timeMode = v)),
          _Item(null, 'Стартовий екран', value: startLabel(pr.startPage),
              onTap: () => pick<StartPage>('Стартовий екран', {for (final s in StartPage.values) s: startLabel(s)}, pr.startPage, (p, v) => p.startPage = v)),
          _Item(null, 'Свайп', value: swipeLabels[pr.swipe], onTap: () => pick<String>('Свайп у списку записів', swipeLabels, pr.swipe, (p, v) => p.swipe = v)),
          _Item(null, 'Показувати нотатку', value: _onOff(pr.showNote),
              onTap: () => pick<bool>('Нотатка в списку записів', {true: 'Увімк.', false: 'Вимк.'}, pr.showNote, (p, v) => p.showNote = v)),
          _Item(null, 'Порядок введення', value: pr.categoryFirst ? 'Спершу категорія' : 'Спершу рахунок',
              onTap: () => pick<bool>('Порядок введення', {false: 'Спершу рахунок', true: 'Спершу категорія'}, pr.categoryFirst, (p, v) => p.categoryFirst = v)),
          _Item(null, 'Кнопка нотаток', value: _onOff(pr.noteButton),
              onTap: () => pick<bool>('Кнопка попередніх нотаток', {true: 'Увімк.', false: 'Вимк.'}, pr.noteButton, (p, v) => p.noteButton = v)),
        ]),
      ]),
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
      body: ListView(children: [
        const SizedBox(height: 12),
        _Group(children: [
          _Item(null, 'Копіювання', value: _onOff(pr.copyPaste), onTap: () => store.updatePrefs((p) => p.copyPaste = !p.copyPaste)),
          if (pr.copyPaste)
            _Item(null, 'Дата копії', value: pr.copyToToday ? 'Сьогодні' : 'Як в оригіналі',
                onTap: () => store.updatePrefs((p) => p.copyToToday = !p.copyToToday)),
        ]),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Коли увімкнено, у відкритому записі є кнопка «Копіювати».', style: Theme.of(context).textTheme.bodySmall),
        ),
      ]),
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
      final total = list.fold<int>(0, (s, r) => s + store.baseAmount(r.template));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15))),
            if (type != TxType.transfer) Text(money(total, store.baseCurrency), style: TextStyle(color: color, fontSize: 16)),
          ]),
        ),
        Container(
          decoration: BoxDecoration(color: panelColor(context), border: Border(top: BorderSide(color: line))),
          child: Column(children: [
            for (final r in list) _row(context, store, r, now, color, line),
          ]),
        ),
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Повторювані записи'), actions: [
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
      ]),
      body: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        _Group(children: [
          _Item(null, 'Коли створювати записи', value: store.prefs.repeatInAdvance ? 'Наперед на період' : 'У день платежу', onTap: () async {
            final v = await _choose<bool>(context, 'Коли створювати записи', {false: 'У день платежу', true: 'Наперед на весь період'}, store.prefs.repeatInAdvance);
            if (v == null) return;
            await store.updatePrefs((p) => p.repeatInAdvance = v);
            await store.runRepeats();
          }),
        ]),
        if (rules.isEmpty)
          const EmptyState(icon: Icons.repeat_rounded, text: 'Повторюваних записів ще немає.\nДодай запис і натисни ⟳ «Повтор» біля дати.'),
        section(TxType.income, 'Доходи', incomeColor(context, store)),
        section(TxType.expense, 'Витрати', p.expense),
        section(TxType.transfer, 'Перекази', scheme.onSurface),
      ]),
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
    final cur = store.currencyOf(t);
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 13);
    return InkWell(
      onTap: () => _editRepeat(context, r),
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line))),
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
        child: Row(children: [
          if (_delete)
            IconButton(
              icon: Icon(Icons.remove_circle_rounded, color: scheme.error),
              onPressed: () async {
                if (await _confirm(context, 'Зупинити повтор?', 'Нові записи більше не створюватимуться. Уже створені залишаться.')) {
                  await store.deleteRepeat(r);
                }
              },
            ),
          SizedBox(
            width: 96,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(next == null ? 'завершено' : '${next.day}.${next.month}.', style: muted),
              Text(repeatLabel(r.every), maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.note.isNotEmpty ? t.note : txnTitle(store, t), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
              Text([catText, acc].where((s) => s.isNotEmpty).join('   '), maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
            ]),
          ),
          const SizedBox(width: 8),
          Text(money(t.amount, cur), style: TextStyle(color: color, fontSize: 16)),
        ]),
      ),
    );
  }

  Future<void> _editRepeat(BuildContext context, RepeatRule r) async {
    final store = StoreScope.read(context);
    var every = r.every;
    var end = r.end;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(r.template.note.isNotEmpty ? r.template.note : txnTitle(store, r.template), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${money(r.template.amount, store.currencyOf(r.template))} · з ${shortDate(r.start)}'),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in RepeatEvery.values) ChoiceChip(label: Text(repeatLabel(e)), selected: every == e, onSelected: (_) => setState(() => every = e)),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_busy_rounded),
              label: Text(end == null ? 'Без дати завершення' : 'До ${shortDate(end!)}'),
              onPressed: () async {
                final d = await showDatePicker(
                    context: context, initialDate: end ?? DateTime.now().add(const Duration(days: 365)), firstDate: r.start, lastDate: DateTime(2100));
                setState(() => end = d == null ? null : DateTime(d.year, d.month, d.day, 23, 59));
              },
            ),
            const SizedBox(height: 16),
            Row(children: [
              IconButton.outlined(
                tooltip: 'Зупинити повтор',
                icon: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.pop(context, 'delete'),
              ),
              const SizedBox(width: 8),
              Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Зберегти'))),
            ]),
          ]),
        ),
      ),
    );
    if (action == 'save') {
      await store.saveRepeat(r.copyWith(every: every, end: end, clearEnd: end == null));
    } else if (action == 'delete' && context.mounted) {
      if (await _confirm(context, 'Зупинити повтор?', 'Нові записи більше не створюватимуться. Уже створені залишаться.')) {
        await store.deleteRepeat(r);
      }
    }
  }
}

// ---- Рахунки (MM: Accounts) -----------------------------------------------------------

class _AccountsMenu extends StatelessWidget {
  const _AccountsMenu();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Рахунки')),
      body: ListView(children: [
        _Group(children: [
          _Item(null, 'Групи рахунків', onTap: () => _push(context, const _AccountGroupsPage())),
          _Item(null, 'Рахунки', onTap: () => _push(context, const EditAccountsPage())),
          _Item(null, 'Враховувати в підсумках', onTap: () => _push(context, const _AccountFlagsPage(transfer: false))),
          _Item(null, 'Переказ-витрата', onTap: () => _push(context, const _AccountFlagsPage(transfer: true))),
          _Item(null, 'Видалені рахунки', value: store.deletedAccounts.isEmpty ? null : '${store.deletedAccounts.length}',
              onTap: () => _push(context, const _DeletedAccountsPage())),
        ]),
      ]),
    );
  }
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
      appBar: AppBar(title: const Text('Групи рахунків'), actions: [
        IconButton(tooltip: 'Новий рахунок', icon: const Icon(Icons.add_rounded), onPressed: () => editAccount(context)),
      ]),
      body: ListView(children: [
        _Group(children: [
          for (final e in groups.entries)
            _Item(null, e.key, subtitle: e.value.map((a) => a.name).join(', '), value: '${e.value.length}', onTap: () async {
              final v = await _askText(context, 'Назва групи', initial: e.key);
              if (v == null || v.isEmpty || v == e.key) return;
              for (final a in e.value) {
                await store.saveAccount(a.copyWith(group: v));
              }
            }),
        ]),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Торкнись групи, щоб перейменувати. Групу рахунку можна змінити й у самому рахунку.', style: Theme.of(context).textTheme.bodySmall),
        ),
      ]),
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
    return Scaffold(
      appBar: AppBar(title: Text(transfer ? 'Переказ-витрата' : 'Враховувати в підсумках')),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            transfer
                ? 'Перекази на позначені рахунки показуються в «Підсумку» як витрата, наприклад поповнення інвестицій чи кишенькові дитині.'
                : 'Позначені рахунки входять у загальні суми активів, пасивів і «Разом».',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        _Group(children: [
          for (final a in store.accounts)
            SwitchListTile(
              title: Text(a.name),
              subtitle: Text(groupOf(a)),
              value: transfer ? store.prefs.transferExpense.contains(a.id) : a.includeInTotal,
              onChanged: (v) => transfer
                  ? store.updatePrefs((p) => p.transferExpense = v ? [...p.transferExpense, a.id] : [...p.transferExpense]..remove(a.id))
                  : store.saveAccount(a.copyWith(includeInTotal: v)),
            ),
        ]),
      ]),
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
      body: ListView(children: [
        if (list.isEmpty)
          const EmptyState(icon: Icons.delete_outline_rounded, text: 'Видалених рахунків немає')
        else
          _Group(children: [
            for (final a in list)
              _Item(null, a.name, subtitle: groupOf(a), value: 'Відновити', onTap: () => store.saveAccount(a.copyWith(deleted: false))),
          ]),
      ]),
    );
  }
}

// ---- Бюджет (MM: Budget Setting) -------------------------------------------------------

class _BudgetPage extends StatefulWidget {
  const _BudgetPage();

  @override
  State<_BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<_BudgetPage> {
  TxType _type = TxType.expense;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final cur = store.baseCurrency;
    final cats = store.categoriesOf(_type);
    Budget? budgetOf(String? id) => store.budgets.where((b) => b.categoryId == id && b.currency == cur).firstOrNull;
    final sum = cats.fold<int>(0, (s, c) => s + (budgetOf(c.id)?.amount ?? 0));
    Widget tab(TxType t, String label) => Expanded(
          child: InkWell(
            onTap: () => setState(() => _type = t),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _type == t ? scheme.primary : Colors.transparent, width: 3))),
              alignment: Alignment.center,
              child: Text(label, style: TextStyle(fontSize: 16, color: _type == t ? scheme.onSurface : scheme.onSurfaceVariant)),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Бюджет')),
      body: Column(children: [
        Row(children: [tab(TxType.income, 'Доходи'), tab(TxType.expense, 'Витрати')]),
        Expanded(
          child: ListView(children: [
            if (cats.isEmpty)
              const EmptyState(icon: Icons.track_changes_rounded, text: 'Спершу додай категорії')
            else ...[
              _Group(children: [
                for (final c in cats)
                  _Item(
                    null,
                    c.name,
                    subtitle: store.subcategoriesOf(c.id).isEmpty ? null : store.subcategoriesOf(c.id).map((s) => s.name).join('  '),
                    trailing: Text(budgetOf(c.id) == null ? '—' : money(budgetOf(c.id)!.amount, cur),
                        style: TextStyle(fontSize: 16, color: budgetOf(c.id) == null ? scheme.onSurfaceVariant : null)),
                    onTap: () => _edit(store, c, budgetOf(c.id)),
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  Expanded(child: Text('Разом на місяць', style: TextStyle(color: scheme.onSurfaceVariant))),
                  Text(money(sum, cur), style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Future<void> _edit(AppStore store, Category c, Budget? b) async {
    final cur = store.baseCurrency;
    final ctrl = TextEditingController(text: b == null ? '' : minorToInput(b.amount, cur));
    final v = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Бюджет «${c.name}»'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: '$cur / місяць', hintText: '0 — без бюджету'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Зберегти')),
        ],
      ),
    );
    if (v == null) return;
    final amount = parseMoney(v, cur) ?? 0;
    if (amount == 0) {
      if (b != null) await store.saveBudget(b.copyWith(deleted: true));
    } else if (b != null) {
      await store.saveBudget(b.copyWith(amount: amount));
    } else {
      await store.saveBudget(Budget(categoryId: c.id, amount: amount, currency: cur));
    }
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
      appBar: AppBar(title: const Text('Теги'), actions: [
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
      ]),
      body: ListView(children: [
        const _InfoHeader(Icons.sell_outlined,
            'Теги додають до запису додаткову інформацію. Наприклад, тег «відпустка» допоможе швидко знайти всі витрати на поїздку.'),
        const SizedBox(height: 12),
        if (tags.isNotEmpty)
          _Group(children: [
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
          ]),
      ]),
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
        builder: (context, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
          Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: Text('#$tag', style: Theme.of(context).textTheme.titleLarge)),
          for (final t in list) TxnTile(txn: t),
        ]),
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
      body: ListView(children: [
        const _Band('Експорт / імпорт'),
        _Group(children: [
          _Item(null, 'Поділитися копією', subtitle: 'iCloud Drive («Зберегти у Файли»), пошта, месенджери', onTap: () => _shareBackup(context)),
          _Item(null, 'Зберегти резервну копію на пристрій', onTap: () => _export(context)),
          _Item(null, 'Відновити з резервної копії', onTap: () => _import(context)),
          _Item(null, 'Імпорт з Money Manager', subtitle: 'Файл резервної копії .mmbak', onTap: () => _importMm(context)),
          _Item(null, 'Експорт даних в Excel', onTap: () => exportForPf(context)),
        ]),
        const _Band('Інше'),
        _Group(children: [
          _Item(null, 'Повне скидання', danger: true, onTap: () async {
            if (await _confirm(context, 'Видалити всі дані?', 'Усі записи, рахунки, категорії й налаштування буде видалено без можливості відновлення.')) {
              await store.resetAll();
            }
          }),
          _Item(null, 'Скинути лише записи (решта залишиться)', onTap: () async {
            if (await _confirm(context, 'Видалити всі записи?', 'Записи, повтори й бюджети буде видалено. Рахунки, категорії й налаштування залишаться.')) {
              await store.resetContents();
            }
          }),
        ]),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Дані зберігаються лише в цьому браузері. Роби резервну копію час від часу.', style: Theme.of(context).textTheme.bodySmall),
        ),
      ]),
    );
  }
}

// ---- Нагадування (MM: Alarm Setting) -------------------------------------------------------

class _AlarmPage extends StatelessWidget {
  const _AlarmPage();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Нагадування')),
        body: ListView(children: [
          const _InfoHeader(Icons.notifications_none_rounded,
              'PFinance нагадає в обраний час дня внести витрати й доходи.'),
          const SizedBox(height: 12),
          _Group(children: [
            _Item(null, 'Нагадування', value: 'скоро', onTap: () => _info(context, 'Нагадування',
                'Щоденне нагадування працюватиме у версії застосунку для телефона. Браузер не вміє надійно надсилати сповіщення, коли сторінку закрито.')),
          ]),
        ]),
      );
}

// ---- Стиль (MM: Style) ---------------------------------------------------------------

class _ThemePage extends StatelessWidget {
  const _ThemePage();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget radio(bool on) => Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: on ? scheme.primary : scheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: const Text('Стиль')),
      body: ListView(children: [
        _Group(children: [
          for (final (m, icon) in const [
            (ThemeMode.system, Icons.sync_rounded),
            (ThemeMode.dark, Icons.dark_mode_outlined),
            (ThemeMode.light, Icons.light_mode_outlined),
          ])
            _Item(icon, _modeLabel(m), trailing: radio(store.themeMode == m), onTap: () => store.setThemeMode(m)),
        ]),
        const _Band('Колір акценту'),
        _Group(children: [
          for (final t in appThemes)
            _Item(null, t.name,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 18, height: 18, decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle)),
                  const SizedBox(width: 14),
                  radio(store.themeId == t.id),
                ]),
                onTap: () => store.setTheme(t.id)),
        ]),
      ]),
    );
  }
}

// ---- Довідка --------------------------------------------------------------------

class _HelpPage extends StatelessWidget {
  const _HelpPage();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Додати запис', 'Кнопка «+» внизу. «Продовжити» зберігає й одразу відкриває наступний запис з тією ж датою.'),
      ('Змінити або видалити', 'Торкнись запису, щоб змінити. Свайп ліворуч видаляє (якщо так обрано в «Налаштування записів → Свайп»).'),
      ('Копія запису', 'Відкрий запис і натисни кнопку копіювання. Увімкнути її можна в «Копіювання записів».'),
      ('Повторювані записи', 'Під час додавання натисни ⟳ поруч із датою й обери, як часто повторювати.'),
      ('Місяць від зарплати', '«Налаштування записів» → «Початок місяця».'),
      ('Теги', 'Пиши в нотатці #тег, і він з\'явиться в розділі «Теги» з підсумком.'),
      ('Перенести в PF', '«Резервна копія» → «Експорт даних в Excel» створює файл, який імпортує дашборд PF.'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Довідка')),
      body: ListView(children: [
        _Group(children: [
          for (final (t, d) in items) ListTile(title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(d)),
        ]),
      ]),
    );
  }
}
