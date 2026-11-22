part of 'more_page.dart';

// ---- Налаштування записів (MM: Transaction Settings) -----------------------------

class _TxnSettingsPage extends StatelessWidget {
  const _TxnSettingsPage({required this.startLabel});
  final String Function(StartPage) startLabel;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pr = store.prefs;
    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування записів')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        SectionTitle('Місяць'),
        _Group(children: [
          _Item(Icons.event_repeat_rounded, 'Початок місяця',
              subtitle: 'Наприклад, день зарплати', value: '${pr.monthStartDay}-го числа', onTap: () => _pickMonthStart(context)),
          _Switch(Icons.redo_rounded, 'Перенесення залишку', pr.carryOver, (v) => store.updatePrefs((p) => p.carryOver = v)),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Text('Перенесення додає до «Разом» різницю доходів і витрат усіх попередніх періодів.',
              style: Theme.of(context).textTheme.bodySmall),
        ),
        SectionTitle('Період'),
        _Group(children: [
          _Item(Icons.view_week_outlined, 'Початок тижня', value: pr.weekStartsMonday ? 'Понеділок' : 'Неділя',
              onTap: () => store.updatePrefs((p) => p.weekStartsMonday = !p.weekStartsMonday)),
          _Item(Icons.home_outlined, 'Стартовий екран', value: startLabel(pr.startPage), onTap: () async {
            final v = await _choose<StartPage>(context, 'Стартовий екран', {for (final s in StartPage.values) s: startLabel(s)}, pr.startPage);
            if (v != null) store.updatePrefs((p) => p.startPage = v);
          }),
        ]),
        SectionTitle('Інше'),
        _Group(children: [
          _Item(Icons.contrast_rounded, 'Колір доходу', value: pr.incomeBlue ? 'Синій' : 'Зелений',
              onTap: () => store.updatePrefs((p) => p.incomeBlue = !p.incomeBlue)),
          _Switch(Icons.account_tree_outlined, 'Підкатегорії', pr.subcategories, (v) => store.updatePrefs((p) => p.subcategories = v)),
          _Switch(Icons.auto_awesome_outlined, 'Підказки нотаток', pr.noteSuggestions, (v) => store.updatePrefs((p) => p.noteSuggestions = v)),
          _Switch(Icons.pin_outlined, 'Показувати копійки', pr.showDecimals, (v) => store.updatePrefs((p) => p.showDecimals = v)),
        ]),
      ]),
    );
  }
}

// ---- Повторювані записи (MM: Repeat Setting) ----------------------------------------

class RepeatsPage extends StatelessWidget {
  const RepeatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Повторювані записи')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (store.repeats.isEmpty)
          const EmptyState(
            icon: Icons.repeat_rounded,
            text: 'Повторюваних записів ще немає.\nДодай запис і натисни ⟳ поруч із датою: оренда, підписки, зарплата.',
          )
        else
          GlassCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final r in store.repeats)
                ListTile(
                  leading: EmojiAvatar(
                    emoji: r.template.type == TxType.transfer ? '🔁' : (store.category(r.template.categoryId)?.emoji ?? '•'),
                    color: Color(store.category(r.template.categoryId)?.color ?? 0xFF8E8E93),
                  ),
                  title: Text(txnTitle(store, r.template), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text([
                    repeatLabel(r.every),
                    if (r.nextAfter(now) case final n?) 'далі ${shortDate(n)}' else 'завершено',
                    if (r.template.note.isNotEmpty) r.template.note,
                  ].join(' · ')),
                  trailing: Text(money(r.template.amount, store.currencyOf(r.template)), style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () => _editRepeat(context, r),
                ),
            ]),
          ),
        const SizedBox(height: 12),
        Text('Записи з\'являються автоматично в день платежу, коли відкриваєш застосунок. Пропущені дні додаються заднім числом.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
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
            Text(txnTitle(store, r.template), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${money(r.template.amount, store.currencyOf(r.template))} · з ${shortDate(r.start)}'),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in RepeatEvery.values)
                ChoiceChip(label: Text(repeatLabel(e)), selected: every == e, onSelected: (_) => setState(() => every = e)),
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

// ---- Теги ----------------------------------------------------------------------

class _TagsPage extends StatelessWidget {
  const _TagsPage();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final tags = store.tags();
    final cur = store.baseCurrency;
    return Scaffold(
      appBar: AppBar(title: const Text('Теги')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (tags.isEmpty)
          const EmptyState(icon: Icons.sell_outlined, text: 'Тегів ще немає.\nДодай у нотатку слово з #, наприклад #відпустка або #ремонт.')
        else
          GlassCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final t in tags)
                ListTile(
                  leading: const Icon(Icons.tag_rounded),
                  title: Text(t.tag),
                  subtitle: Text('${t.count} ${t.count == 1 ? 'запис' : 'записів'}'),
                  trailing: Text(money(t.sum, cur, sign: true), style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () => _showTag(context, t.tag),
                ),
            ]),
          ),
        const SizedBox(height: 12),
        Text('Теги беруться з нотаток. Так зручно рахувати поїздку чи ремонт, що зачіпає різні категорії.',
            style: Theme.of(context).textTheme.bodySmall),
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Резервна копія')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
          SectionTitle('Експорт'),
          _Group(children: [
            _Item(Icons.table_view_rounded, 'Excel для PF', subtitle: 'Файл, який імпортує дашборд PF', onTap: () => exportForPf(context)),
            _Item(Icons.download_rounded, 'Резервна копія (JSON)', subtitle: 'Усі записи, рахунки й налаштування', onTap: () => _export(context)),
          ]),
          SectionTitle('Імпорт'),
          _Group(children: [
            _Item(Icons.upload_rounded, 'Відновити з копії', subtitle: 'Поточні дані буде замінено', onTap: () => _import(context)),
          ]),
          SectionTitle('Скидання'),
          _Group(children: [
            _Item(Icons.delete_forever_outlined, 'Повне скидання', danger: true, onTap: () => _reset(context)),
          ]),
          const SizedBox(height: 12),
          Text('Дані зберігаються лише в цьому браузері. Роби резервну копію час від часу.', style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

// ---- Довідка --------------------------------------------------------------------

class _HelpPage extends StatelessWidget {
  const _HelpPage();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Додати запис', 'Кнопка «+» внизу. «Продовжити» зберігає й одразу відкриває наступний запис з тією ж датою.'),
      ('Змінити або видалити', 'Торкнись запису, щоб змінити. Свайп ліворуч видаляє, а в повідомленні можна скасувати.'),
      ('Копія запису', 'Відкрий запис і натисни кнопку копіювання. Дату копії задає «Копіювання записів».'),
      ('Повторювані записи', 'Під час додавання натисни ⟳ поруч із датою й обери, як часто повторювати.'),
      ('Місяць від зарплати', '«Налаштування записів» → «Початок місяця».'),
      ('Теги', 'Пиши в нотатці #тег, і він з\'явиться в розділі «Теги» з підсумком.'),
      ('Перенести в PF', '«Резервна копія» → «Excel для PF» створює файл, який імпортує дашборд PF.'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Довідка')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GlassCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (final (t, d) in items) ListTile(title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(d)),
          ]),
        ),
      ]),
    );
  }
}
