import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../state/app_store.dart';
import 'accounts_page.dart' show editAccount, kindLabels;
import 'export_pf.dart';
import 'format.dart';
import 'edit_transaction.dart' show repeatLabel;
import 'stats_page.dart' show editBudget;
import 'transactions_page.dart' show TxnTile;
import 'theme.dart';
import 'widgets.dart';

part 'more_extra.dart';

/// "Більше": all settings, grouped the way Money Manager's More tab is,
/// but split into three sections.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pr = store.prefs;
    void push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => _Sub(child: page)));
    String startLabel(StartPage s) => switch (s) {
          StartPage.day => 'Записи · День',
          StartPage.calendar => 'Записи · Календар',
          StartPage.month => 'Записи · Місяць',
          StartPage.summary => 'Записи · Підсумок',
          StartPage.stats => 'Статистика',
          StartPage.accounts => 'Рахунки',
        };

    final subs = store.prefs.rates.keys.where((c) => c != pr.baseCurrency).toList()..sort();
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(children: [
              const PfLogo(size: 40),
              const Spacer(),
              Text('PFinance · v0.7', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(height: 16),
          _Group(children: [
            _Item(Icons.help_outline_rounded, 'Довідка', onTap: () => push(const _HelpPage())),
          ]),
          SectionTitle('Записи'),
          _Group(children: [
            _Item(Icons.receipt_long_outlined, 'Налаштування записів',
                subtitle: 'Початок місяця, перенесення залишку, період, інше', onTap: () => push(_TxnSettingsPage(startLabel: startLabel))),
            _Item(Icons.repeat_rounded, 'Повторювані записи', value: store.repeats.isEmpty ? null : '${store.repeats.length}', onTap: () => push(const _RepeatsPage())),
            _Item(Icons.content_copy_rounded, 'Копіювання записів', value: pr.copyToToday ? 'Сьогоднішня дата' : 'Дата оригіналу', onTap: () async {
              final v = await _choose<bool>(context, 'Дата копії запису', {true: 'Сьогоднішня дата', false: 'Дата оригіналу'}, pr.copyToToday);
              if (v != null) store.updatePrefs((p) => p.copyToToday = v);
            }),
          ]),
          SectionTitle('Категорії й рахунки'),
          _Group(children: [
            _Item(Icons.south_west_rounded, 'Категорії доходів', onTap: () => push(const CategoriesPage(type: TxType.income))),
            _Item(Icons.north_east_rounded, 'Категорії витрат', onTap: () => push(const CategoriesPage(type: TxType.expense))),
            _Item(Icons.account_balance_wallet_outlined, 'Рахунки',
                subtitle: 'Групи, рахунки, враховувати в підсумках, приховати', onTap: () => push(const _AccountsSettings())),
            _Item(Icons.track_changes_rounded, 'Бюджет', onTap: () => push(const _BudgetsSettings())),
            _Item(Icons.sell_outlined, 'Теги', onTap: () => push(const _TagsPage())),
          ]),
          SectionTitle('Налаштування'),
          _Group(children: [
            _Item(Icons.settings_backup_restore_rounded, 'Резервна копія', subtitle: 'Експорт, імпорт, повне скидання', onTap: () => push(const _BackupPage())),
            _Item(Icons.lock_outline_rounded, 'PIN-код', value: pr.pin == null ? 'Вимкнено' : 'Увімкнено', onTap: () => _setPin(context)),
            _Item(Icons.payments_outlined, 'Основна валюта', value: pr.baseCurrency, onTap: () => changeBaseCurrency(context)),
            _Item(Icons.currency_exchange_rounded, 'Додаткові валюти', value: subs.isEmpty ? null : subs.join(', '), onTap: () => push(const CurrenciesPage())),
            _Item(Icons.notifications_none_rounded, 'Нагадування', value: 'скоро', onTap: () => _info(context, 'Нагадування',
                'Щоденне нагадування внести витрати працюватиме у версії застосунку для телефона. Браузер не вміє надійно надсилати сповіщення, коли сторінку закрито.')),
            _Item(Icons.palette_outlined, 'Стиль', value: '${themeById(pr.themeId).name} · ${_modeLabel(pr.themeMode)}', onTap: () => push(const _ThemePage())),
            _Item(Icons.translate_rounded, 'Мова', value: 'Українська', onTap: () => _info(context, 'Мова',
                'Поки що застосунок українською. Англійська та інші мови з\'являться перед виходом для всіх.')),
          ]),
          const SizedBox(height: 16),
          Center(
            child: Text('PFinance · v0.7\nДані зберігаються лише на цьому пристрої',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

}

Future<void> _pickMonthStart(BuildContext context) async {
    final store = StoreScope.read(context);
    final v = await _choose<int>(context, 'Місяць починається', {for (var d = 1; d <= 28; d++) d: '$d-го числа'}, store.prefs.monthStartDay);
    if (v != null) store.updatePrefs((p) => p.monthStartDay = v);
  }

  Future<void> _setPin(BuildContext context) async {
    final store = StoreScope.read(context);
    if (store.prefs.pin != null) {
      final off = await _confirm(context, 'Вимкнути PIN-код?', 'Застосунок відкриватиметься без коду.');
      if (off) store.updatePrefs((p) => p.pin = null);
      return;
    }
    final ctrl = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новий PIN-код'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 4,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '4 цифри'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
          FilledButton(
            onPressed: () {
              if (RegExp(r'^\d{4}$').hasMatch(ctrl.text)) Navigator.pop(context, ctrl.text);
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
    if (pin != null) store.updatePrefs((p) => p.pin = pin);
  }

  Future<void> _export(BuildContext context) async {
    final store = StoreScope.read(context);
    final json = await store.exportJson();
    final d = DateTime.now();
    await FileSaver.instance.saveFile(
      name: 'pfinance-backup-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      bytes: Uint8List.fromList(utf8.encode(json)),
      fileExtension: 'json',
      mimeType: MimeType.json,
    );
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Резервну копію збережено')));
  }

  Future<void> _import(BuildContext context) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (files.isEmpty) return;
    final bytes = await files.single.readAsBytes();
    if (!context.mounted) return;
    if (!await _confirm(context, 'Відновити з копії?', 'Поточні дані буде замінено даними з файлу.')) return;
    if (!context.mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(children: [
            SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            SizedBox(width: 20),
            Expanded(child: Text('Відновлюю дані…')),
          ]),
        ),
      ),
    );
    try {
      await store.importJson(utf8.decode(bytes));
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Дані відновлено')));
    } catch (e) {
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text('Не вдалося прочитати файл: $e')));
    }
  }

  Future<void> _reset(BuildContext context) async {
    final store = StoreScope.read(context);
    if (await _confirm(context, 'Видалити всі дані?', 'Усі записи, рахунки й налаштування буде видалено без можливості відновлення.')) {
      await store.resetAll();
    }
  }

Future<bool> _confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Так')),
        ],
      ),
    ) ??
    false;

Future<T?> _choose<T>(BuildContext context, String title, Map<T, String> options, T current) => showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          for (final e in options.entries)
            ListTile(
              title: Text(e.value),
              trailing: e.key == current ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () => Navigator.pop(context, e.key),
            ),
        ],
      ),
    );

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GlassCard(
        radius: 22,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 56, color: Colors.white.withValues(alpha: 0.06)),
            c,
          ],
        ]),
      );
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.title, {this.value, this.subtitle, this.onTap, this.danger = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: danger ? scheme.error : scheme.primary),
      title: Text(title, style: TextStyle(color: danger ? scheme.error : null)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (value != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(value!, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          ),
        if (onTap != null) const Icon(Icons.chevron_right_rounded),
      ]),
      onTap: onTap,
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch(this.icon, this.title, this.value, this.onChanged);
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        value: value,
        onChanged: onChanged,
      );
}

/// Sub-page chrome: aurora background + transparent app bar.
class _Sub extends StatelessWidget {
  const _Sub({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => AuroraBackground(child: child);
}

// ---- Тема ---------------------------------------------------------------------

class _ThemePage extends StatelessWidget {
  const _ThemePage();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Стиль')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('Авто'), icon: Icon(Icons.brightness_auto_rounded)),
            ButtonSegment(value: ThemeMode.light, label: Text('Світла'), icon: Icon(Icons.light_mode_rounded)),
            ButtonSegment(value: ThemeMode.dark, label: Text('Темна'), icon: Icon(Icons.dark_mode_rounded)),
          ],
          selected: {store.themeMode},
          showSelectedIcon: false,
          onSelectionChanged: (s) => store.setThemeMode(s.first),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            for (final t in appThemes)
              GestureDetector(
                onTap: () => store.setTheme(t.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [t.aurora[0], t.aurora[1], t.aurora[2]]),
                    border: Border.all(color: t.id == store.themeId ? Colors.white : Colors.white24, width: t.id == store.themeId ? 3 : 1),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    AnimatedOpacity(
                      opacity: t.id == store.themeId ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.check_circle_rounded, color: Colors.white),
                    ),
                    Text(t.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  ]),
                ),
              ),
          ],
        ),
      ]),
    );
  }
}

// ---- Рахунки / Бюджет ---------------------------------------------------------

class _AccountsSettings extends StatelessWidget {
  const _AccountsSettings();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Рахунки')),
      floatingActionButton: FloatingActionButton(onPressed: () => editAccount(context), child: const Icon(Icons.add_rounded)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GlassCard(
          radius: 22,
          child: Column(children: [
            for (final a in store.accounts)
              ListTile(
                leading: Icon(kindLabels[a.kind]!.$2, color: Color(a.color)),
                title: Text(a.name),
                subtitle: Text('${kindLabels[a.kind]!.$1} · ${a.currency}${a.archived ? ' · прихований' : ''}'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => editAccount(context, existing: a),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _BudgetsSettings extends StatelessWidget {
  const _BudgetsSettings();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cur = store.baseCurrency;
    return Scaffold(
      appBar: AppBar(title: const Text('Бюджет')),
      floatingActionButton: FloatingActionButton(onPressed: () => editBudget(context, currency: cur), child: const Icon(Icons.add_rounded)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (store.budgets.isEmpty) const EmptyState(icon: Icons.track_changes_rounded, text: 'Бюджетів ще немає'),
        if (store.budgets.isNotEmpty)
          GlassCard(
            radius: 22,
            child: Column(children: [
              for (final b in store.budgets)
                ListTile(
                  leading: Text(store.category(b.categoryId)?.emoji ?? '🎯', style: const TextStyle(fontSize: 20)),
                  title: Text(store.category(b.categoryId)?.name ?? 'Усі витрати'),
                  trailing: Text('${money(b.amount, b.currency)} / міс.'),
                  onTap: () => editBudget(context, currency: b.currency, existing: b),
                ),
            ]),
          ),
      ]),
    );
  }
}

Future<void> changeBaseCurrency(BuildContext context) async {
  final store = StoreScope.read(context);
  final base = store.baseCurrency;
  final v = await _choose<String>(context, 'Основна валюта', {for (final c in currencies) c: c}, base);
  if (v == null || v == base) return;
  await store.updatePrefs((p) {
    // Re-express the manual rates against the new base.
    final k = p.rates[v];
    if (k != null && k > 0) {
      p.rates = {for (final e in p.rates.entries) if (e.key != v) e.key: e.value / k, base: 1 / k};
    }
    p.baseCurrency = v;
  });
}

String _modeLabel(ThemeMode m) => switch (m) {
      ThemeMode.system => 'авто',
      ThemeMode.light => 'світла',
      ThemeMode.dark => 'темна',
    };

Future<void> _info(BuildContext context, String title, String body) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Зрозуміло'))],
      ),
    );

// ---- Валюти --------------------------------------------------------------------

class CurrenciesPage extends StatelessWidget {
  const CurrenciesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final base = store.baseCurrency;
    final others = {...store.currenciesInUse, ...store.prefs.rates.keys}.where((c) => c != base).toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('Додаткові валюти')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GlassCard(
          radius: 22,
          child: ListTile(
            leading: const Icon(Icons.star_rounded),
            title: const Text('Основна валюта'),
            subtitle: const Text('У ній рахуються підсумки й статистика'),
            trailing: Text(base, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            onTap: () => changeBaseCurrency(context),
          ),
        ),
        SectionTitle('Курси (вручну)',
            trailing: TextButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Валюта'),
              onPressed: () async {
                final v = await _choose<String>(context, 'Додати валюту', {for (final c in currencies.where((c) => c != base && !others.contains(c))) c: c}, '');
                if (v != null && context.mounted) _editRate(context, v);
              },
            )),
        GlassCard(
          radius: 22,
          child: Column(children: [
            if (others.isEmpty) const Padding(padding: EdgeInsets.all(18), child: Text('Інших валют немає')),
            for (final c in others)
              ListTile(
                title: Text('1 $c'),
                trailing: Text(store.prefs.rates[c] == null ? 'курс не задано' : '= ${store.prefs.rates[c]!.toStringAsFixed(4)} $base',
                    style: TextStyle(color: store.prefs.rates[c] == null ? AppPalette.of(context).expense : null, fontWeight: FontWeight.w600)),
                onTap: () => _editRate(context, c),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Text('Автоматичне оновлення курсів (ЄЦБ / НБУ) з\'явиться пізніше.', style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }

  Future<void> _editRate(BuildContext context, String c) async {
    final store = StoreScope.read(context);
    final ctrl = TextEditingController(text: store.prefs.rates[c]?.toString() ?? '');
    final v = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Курс $c'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(prefixText: '1 $c = ', suffixText: store.baseCurrency),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text.replaceAll(',', '.'))),
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
    if (v != null && v > 0) store.updatePrefs((p) => p.rates = {...p.rates, c: v});
  }
}

// ---- Категорії (з підкатегоріями) -----------------------------------------------

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, required this.type});
  final TxType type;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cats = store.categoriesOf(type);
    return Scaffold(
      appBar: AppBar(title: Text(type == TxType.income ? 'Категорії доходів' : 'Категорії витрат')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Нова категорія',
        onPressed: () => editCategory(context, type: type),
        child: const Icon(Icons.add_rounded),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: cats.length,
            onReorderItem: (from, to) {
              final list = [...cats];
              list.insert(to, list.removeAt(from));
              for (final (i, c) in list.indexed) {
                if (c.sort != i) store.saveCategory(c.copyWith(sort: i));
              }
            },
            itemBuilder: (context, i) {
              final c = cats[i];
              final subs = store.subcategoriesOf(c.id);
              return Padding(
                key: ValueKey(c.id),
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  radius: 20,
                  child: Column(children: [
                    ListTile(
                      leading: EmojiAvatar(emoji: c.emoji, color: Color(c.color)),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: subs.isEmpty ? null : Text(subs.map((s) => s.name).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        tooltip: 'Додати підкатегорію',
                        icon: const Icon(Icons.playlist_add_rounded),
                        onPressed: () => editCategory(context, type: type, parent: c),
                      ),
                      onTap: () => editCategory(context, type: type, existing: c),
                    ),
                    if (store.prefs.subcategories)
                      for (final s in subs)
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 72, right: 16),
                          title: Text(s.name),
                          trailing: const Icon(Icons.edit_outlined, size: 18),
                          onTap: () => editCategory(context, type: type, existing: s),
                        ),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<void> editCategory(BuildContext context, {required TxType type, Category? existing, Category? parent}) async {
  final store = StoreScope.read(context);
  final isSub = parent != null || existing?.parentId != null;
  final name = TextEditingController(text: existing?.name ?? '');
  final emoji = TextEditingController(text: existing?.emoji ?? parent?.emoji ?? '');
  var color = existing?.color ?? parent?.color ?? colorChoices.first;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? (isSub ? 'Нова підкатегорія «${parent!.name}»' : 'Нова категорія') : (isSub ? 'Підкатегорія' : 'Категорія')),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              if (!isSub) ...[
                SizedBox(
                  width: 72,
                  child: TextField(controller: emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22), decoration: const InputDecoration(hintText: '—')),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(child: TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Назва'))),
            ]),
            if (!isSub) ...[
              const SizedBox(height: 16),
              ColorPickerRow(value: color, onChanged: (v) => setState(() => color = v)),
            ],
          ]),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () {
                store.saveCategory(existing.copyWith(deleted: true));
                Navigator.pop(context);
              },
              child: const Text('Видалити'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              final e = emoji.text.trim();
              store.saveCategory(existing?.copyWith(name: name.text.trim(), emoji: e, color: color) ??
                  Category(
                    name: name.text.trim(),
                    type: type,
                    parentId: parent?.id,
                    emoji: e,
                    color: color,
                    sort: parent != null ? store.subcategoriesOf(parent.id).length : store.categoriesOf(type).length,
                  ));
              Navigator.pop(context);
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    ),
  );
}
