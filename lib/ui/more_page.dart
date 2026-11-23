import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../state/app_store.dart';
import 'accounts_page.dart' show EditAccountsPage, editAccount, groupOf;
import 'app_icon.dart';
import 'edit_transaction.dart' show openTxnEditor, repeatLabel;
import 'export_pf.dart';
import 'share_file.dart';
import 'format.dart';
import 'theme.dart';
import 'transactions_page.dart' show TxnTile;
import 'widgets.dart';

part 'more_extra.dart';

const appVersion = 'v0.9.40';

/// Full names of the supported currencies (Settings → currencies).
const currencyNames = {
  'UAH': 'Гривня', 'USD': 'Долар США', 'EUR': 'Євро', 'GBP': 'Фунт стерлінгів', 'PLN': 'Злотий', //
  'CHF': 'Швейцарський франк', 'CZK': 'Чеська крона', 'CAD': 'Канадський долар', 'AUD': 'Австралійський долар',
  'JPY': 'Єна', 'CNY': 'Юань', 'TRY': 'Турецька ліра', 'SEK': 'Шведська крона', 'NOK': 'Норвезька крона',
  'DKK': 'Данська крона', 'HUF': 'Форинт', 'RON': 'Румунський лей', 'GEL': 'Ларі', 'KZT': 'Тенге', 'ILS': 'Шекель',
};

String currencySymbol(String c) => NumberFormat.simpleCurrency(name: c).currencySymbol;

/// "Більше": settings in Money Manager's order and look (flat rows).
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pr = store.prefs;
    final scheme = Theme.of(context).colorScheme;
    void push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => AuroraBackground(child: page)));
    final subs = pr.rates.keys.where((c) => c != pr.baseCurrency).toList()..sort();
    return SafeArea(
      bottom: false,
      // The logo header stays put; only the menu below it scrolls.
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(children: [
            const PfLogo(size: 40),
            const Spacer(),
            Text('PFinance · $appVersion', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
        Expanded(child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _Group(children: [
            _Item(Icons.receipt_long_outlined, 'Налаштування записів',
                subtitle: 'Початок місяця, тижня, перенесення, час, свайп…', onTap: () => push(const _TxnSettingsPage())),
            _Item(Icons.repeat_rounded, 'Повторювані записи', onTap: () => push(const RepeatsPage())),
            _Item(Icons.content_copy_rounded, 'Копіювання записів', onTap: () => push(const _CopyPastePage())),
          ]),
          const _Band('Категорії й рахунки'),
          _Group(children: [
            _Item(Icons.south_west_rounded, 'Категорії доходів', onTap: () => push(const CategoriesPage(type: TxType.income))),
            _Item(Icons.north_east_rounded, 'Категорії витрат', onTap: () => push(const CategoriesPage(type: TxType.expense))),
            _Item(Icons.account_balance_wallet_outlined, 'Рахунки',
                subtitle: 'Групи, рахунки, у підсумках, переказ-витрата…', onTap: () => push(const _AccountsMenu())),
            _Item(Icons.track_changes_rounded, 'Бюджет', onTap: () => push(const _BudgetPage())),
            _Item(Icons.sell_outlined, 'Теги', onTap: () => push(const _TagsPage())),
          ]),
          const _Band('Налаштування'),
          _Group(children: [
            _Item(Icons.settings_backup_restore_rounded, 'Резервна копія', subtitle: 'Експорт, імпорт, повне скидання', onTap: () => push(const _BackupPage())),
            _Item(Icons.lock_outline_rounded, 'PIN-код', badge: pr.pin == null ? null : 'УВІМК.', onTap: () => _pinSettings(context)),
            _Item(Icons.payments_outlined, 'Основна валюта',
                subtitle: '${pr.baseCurrency} (${currencySymbol(pr.baseCurrency)})', onTap: () => push(const _MainCurrencyPage())),
            _Item(Icons.currency_exchange_rounded, 'Додаткові валюти',
                subtitle: subs.isEmpty ? null : subs.map(currencySymbol).join(', '), onTap: () => push(const CurrenciesPage())),
            _Item(Icons.notifications_none_rounded, 'Нагадування', onTap: () => push(const _AlarmPage())),
            _Item(Icons.palette_outlined, 'Стиль', subtitle: '${_modeLabel(pr.themeMode)} · ${themeById(pr.themeId).name}', onTap: () => push(const _ThemePage())),
            _Item(Icons.apps_rounded, 'Іконка застосунку', onTap: () => _pickAppIcon(context)),
            _Item(Icons.translate_rounded, 'Мова', subtitle: 'Українська', onTap: () => _info(context, 'Мова',
                'Поки що застосунок українською. Англійська та інші мови з\'являться перед виходом для всіх.')),
            _Item(Icons.help_outline_rounded, 'Довідка', onTap: () => push(const _HelpPage())),
          ]),
          const SizedBox(height: 20),
          Center(child: Text('Дані зберігаються лише на цьому пристрої', style: Theme.of(context).textTheme.bodySmall)),
        ],
      )),
      ]),
    );
  }
}

// ---- Flat building blocks ------------------------------------------------------

/// Section band between groups ("Налаштування").
class _Band extends StatelessWidget {
  const _Band(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
      );
}

/// Full-width rows on a flat panel, separated by hairlines.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return Container(
      decoration: BoxDecoration(
        color: panelColor(context),
        border: Border.symmetric(horizontal: BorderSide(color: line)),
      ),
      child: Column(children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: line),
          c,
        ],
      ]),
    );
  }
}

/// Settings row: optional grey icon, title (with a small accent badge),
/// grey subtitle, and the current value in the accent colour on the right.
class _Item extends StatelessWidget {
  const _Item(this.icon, this.title, {this.value, this.subtitle, this.badge, this.onTap, this.danger = false, this.trailing});
  final IconData? icon;
  final String title;
  final String? subtitle;
  final String? value;
  final String? badge;
  final VoidCallback? onTap;
  final bool danger;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(icon == null ? 20 : 16, 11, 16, 11),
        child: Row(children: [
          if (icon != null) ...[Icon(icon, color: scheme.onSurfaceVariant, size: 24), const SizedBox(width: 16)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(title, style: TextStyle(fontSize: 16, color: danger ? scheme.error : null))),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Text(badge!, style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w600)),
                ],
              ]),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                ),
            ]),
          ),
          if (value != null) ...[
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(value!, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: TextStyle(color: scheme.primary, fontSize: 15)),
            ),
          ],
          ?trailing,
        ]),
      ),
    );
  }
}

/// Info header with a round outlined icon (MM Tag / Alarm pages).
class _InfoHeader extends StatelessWidget {
  const _InfoHeader(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: panelColor(context),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.primary)),
          child: Icon(icon, color: scheme.primary, size: 28),
        ),
        const SizedBox(width: 20),
        Expanded(child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14, height: 1.35))),
      ]),
    );
  }
}

String _onOff(bool v) => v ? 'Увімк.' : 'Вимк.';

String _modeLabel(ThemeMode m) => switch (m) {
      ThemeMode.system => 'Як у системі',
      ThemeMode.light => 'Світлий',
      ThemeMode.dark => 'Темний',
    };

Future<void> _info(BuildContext context, String title, String body) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Зрозуміло'))],
      ),
    );

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

Future<String?> _askText(BuildContext context, String title, {String initial = '', String? hint}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: hint), onSubmitted: (v) => Navigator.pop(context, v.trim())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
        FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Зберегти')),
      ],
    ),
  );
}

// ---- PIN ------------------------------------------------------------------------

Future<void> _pinSettings(BuildContext context) async {
  final store = StoreScope.read(context);
  if (store.prefs.pin != null) {
    final v = await _choose<String>(context, 'PIN-код', {'change': 'Змінити PIN-код', 'off': 'Вимкнути PIN-код'}, '');
    if (v == 'off') {
      store.updatePrefs((p) => p.pin = null);
      return;
    }
    if (v != 'change') return;
  }
  if (!context.mounted) return;
  final pin = await Navigator.of(context).push<String>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _PinSetup()));
  if (pin != null) store.updatePrefs((p) => p.pin = pin);
}

class _PinSetup extends StatefulWidget {
  const _PinSetup();

  @override
  State<_PinSetup> createState() => _PinSetupState();
}

class _PinSetupState extends State<_PinSetup> {
  String? _first;
  bool _mismatch = false;

  @override
  Widget build(BuildContext context) => PinPad(
        message: _first == null ? (_mismatch ? 'Коди не збіглися' : 'Введи новий PIN-код') : 'Повтори PIN-код',
        onClose: () => Navigator.pop(context),
        onComplete: (code) async {
          if (_first == null) {
            setState(() {
              _first = code;
              _mismatch = false;
            });
            return true;
          }
          if (code == _first) {
            Navigator.pop(context, code);
            return true;
          }
          setState(() {
            _first = null;
            _mismatch = true;
          });
          return true;
        },
      );
}

// ---- Іконка застосунку ------------------------------------------------------------

Future<void> _pickAppIcon(BuildContext context) async {
  final store = StoreScope.read(context);
  final v = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Іконка застосунку', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Wrap(spacing: 16, runSpacing: 16, children: [
          for (var i = 0; i < appIconCount; i++)
            GestureDetector(
              onTap: () => Navigator.pop(context, i),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: store.prefs.appIcon == i ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
                ),
                child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset(appIconAsset(i), width: 68, height: 68)),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        Text('На телефоні нова іконка з\'явиться, коли знову додаси сайт на головний екран.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    ),
  );
  if (v == null) return;
  await store.updatePrefs((p) => p.appIcon = v);
  applyAppIcon(v);
}

// ---- Валюти --------------------------------------------------------------------------

Future<void> changeBaseCurrency(BuildContext context) async {
  final store = StoreScope.read(context);
  final base = store.baseCurrency;
  final v = await _choose<String>(context, 'Основна валюта', {for (final c in currencies) c: '$c — ${currencyNames[c] ?? c}'}, base);
  if (v == null || v == base) return;
  await store.updatePrefs((p) {
    // Re-express the rates against the new base.
    final k = p.rates[v];
    if (k != null && k > 0) {
      p.rates = {for (final e in p.rates.entries) if (e.key != v) e.key: e.value / k, base: 1 / k};
    }
    p.baseCurrency = v;
  });
}

/// MM "Main Currency Setting": sample, symbol position, decimals, Save.
class _MainCurrencyPage extends StatefulWidget {
  const _MainCurrencyPage();

  @override
  State<_MainCurrencyPage> createState() => _MainCurrencyPageState();
}

class _MainCurrencyPageState extends State<_MainCurrencyPage> {
  late final Prefs _p = StoreScope.read(context).prefs;
  late bool _front = _p.currencyFront;
  late bool _decimals = _p.showDecimals;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final c = store.baseCurrency;
    final sym = currencySymbol(c);
    final sample = _decimals ? '1,00' : '1';
    return Scaffold(
      appBar: AppBar(title: const Text('Основна валюта'), actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: OutlinedButton(onPressed: () => changeBaseCurrency(context), child: const Text('Змінити')),
        ),
      ]),
      body: ListView(children: [
        Container(
          color: panelColor(context),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(children: [
            Text('$c — ${currencyNames[c] ?? c} ($sym)', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
            const SizedBox(height: 6),
            Text(_front ? '$sym $sample' : '$sample $sym', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w500)),
          ]),
        ),
        const SizedBox(height: 12),
        _Group(children: [
          _Item(null, 'Позиція символу', value: _front ? 'Спереду' : 'Позаду', onTap: () => setState(() => _front = !_front)),
          _Item(null, 'Десяткові', value: _decimals ? '1,00' : '1', onTap: () => setState(() => _decimals = !_decimals)),
        ]),
        Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () async {
              await store.updatePrefs((p) {
                p.currencyFront = _front;
                p.showDecimals = _decimals;
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Зберегти'),
          ),
        ),
      ]),
    );
  }
}

/// MM "Sub Currency Setting": "USD 1.00 = EUR 0,891108" rows, edit mode, add,
/// and a refresh button that fetches today's rates.
class CurrenciesPage extends StatefulWidget {
  const CurrenciesPage({super.key});

  @override
  State<CurrenciesPage> createState() => _CurrenciesPageState();
}

class _CurrenciesPageState extends State<CurrenciesPage> {
  bool _edit = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final base = store.baseCurrency;
    final others = {...store.currenciesInUse, ...store.prefs.rates.keys}.where((c) => c != base).toList()..sort();
    final nf = NumberFormat('#,##0.######', locale);
    return Scaffold(
      appBar: AppBar(title: const Text('Додаткові валюти'), actions: [
        IconButton(tooltip: 'Редагувати', icon: Icon(_edit ? Icons.check_rounded : Icons.edit_outlined), onPressed: () => setState(() => _edit = !_edit)),
        IconButton(
          tooltip: 'Додати валюту',
          icon: const Icon(Icons.add_rounded),
          onPressed: () async {
            final v = await _choose<String>(context, 'Додати валюту',
                {for (final c in currencies.where((c) => c != base && !others.contains(c))) c: '$c — ${currencyNames[c] ?? c}'}, '');
            if (v != null && context.mounted) _editRate(context, v);
          },
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Оновити курси',
        onPressed: _loading ? null : () => _refresh(store, others),
        child: _loading ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Icon(Icons.sync_rounded),
      ),
      body: ListView(children: [
        if (others.isEmpty)
          const EmptyState(icon: Icons.currency_exchange_rounded, text: 'Додаткових валют немає.\nДодай валюту кнопкою «+».')
        else
          _Group(children: [
            for (final c in others)
              _Item(
                null,
                '$c 1,00 = $base ${store.prefs.rates[c] == null ? '?' : nf.format(store.prefs.rates[c])}',
                subtitle: '$c — ${currencyNames[c] ?? c} (${currencySymbol(c)})',
                trailing: _edit
                    ? IconButton(
                        icon: Icon(Icons.remove_circle_rounded, color: scheme.error),
                        onPressed: () => store.updatePrefs((p) => p.rates = {...p.rates}..remove(c)),
                      )
                    : null,
                onTap: () => _editRate(context, c),
              ),
          ]),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Кнопка оновлення бере сьогоднішні курси з open.er-api.com. Курс можна змінити й уручну.',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ]),
    );
  }

  Future<void> _refresh(AppStore store, List<String> codes) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('https://open.er-api.com/v6/latest/${store.baseCurrency}'));
      final j = jsonDecode(res.body) as Map<String, Object?>;
      final rates = (j['rates'] as Map).cast<String, num>();
      var n = 0;
      await store.updatePrefs((p) {
        final next = {...p.rates};
        for (final c in codes) {
          final r = rates[c];
          if (r != null && r > 0) {
            next[c] = double.parse((1 / r).toStringAsFixed(6));
            n++;
          }
        }
        p.rates = next;
      });
      messenger.showSnackBar(SnackBar(content: Text('Оновлено курсів: $n')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Не вдалося отримати курси. Перевір інтернет.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text.replaceAll(',', '.'))), child: const Text('Зберегти')),
        ],
      ),
    );
    if (v != null && v > 0) store.updatePrefs((p) => p.rates = {...p.rates, c: v});
  }
}

// ---- Категорії ---------------------------------------------------------------------

/// MM category list: "Підкатегорії" switch, rows with delete, name (count) and
/// subcategories, edit pencil and drag handle. Tapping a row opens its
/// subcategories.
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, required this.type, this.parent});
  final TxType type;
  final Category? parent;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final cats = parent == null ? store.categoriesOf(type) : store.subcategoriesOf(parent!.id);
    final line = scheme.onSurface.withValues(alpha: 0.08);
    final title = parent?.name ?? (type == TxType.income ? 'Категорії доходів' : 'Категорії витрат');
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [
        IconButton(
          tooltip: parent == null ? 'Нова категорія' : 'Нова підкатегорія',
          icon: const Icon(Icons.add_rounded),
          onPressed: () => editCategory(context, type: type, parent: parent),
        ),
      ]),
      body: Column(children: [
        if (parent == null) ...[
          Container(
            color: panelColor(context),
            child: SwitchListTile(
              title: const Text('Підкатегорії'),
              value: store.prefs.subcategories,
              onChanged: (v) => store.updatePrefs((p) => p.subcategories = v),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (cats.isEmpty)
          Expanded(child: EmptyState(icon: Icons.category_outlined, text: parent == null ? 'Категорій ще немає.\nДодай першу кнопкою «+».' : 'Підкатегорій немає.'))
        else
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 40),
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
                final subs = parent == null ? store.subcategoriesOf(c.id) : const <Category>[];
                return Material(
                  key: ValueKey(c.id),
                  color: panelColor(context),
                  child: InkWell(
                    onTap: parent == null && store.prefs.subcategories
                        ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuroraBackground(child: CategoriesPage(type: type, parent: c))))
                        : () => editCategory(context, type: type, existing: c),
                    child: Container(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line))),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        IconButton(
                          tooltip: 'Видалити',
                          icon: Icon(Icons.remove_circle_rounded, color: scheme.error, size: 28),
                          onPressed: () async {
                            if (await _confirm(context, 'Видалити «${c.name}»?', 'Записи з цією категорією залишаться, але без категорії.')) {
                              store.saveCategory(c.copyWith(deleted: true));
                            }
                          },
                        ),
                        if (hasIcon(c.emoji)) ...[Text(c.emoji, style: const TextStyle(fontSize: 20)), const SizedBox(width: 8)],
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(subs.isEmpty ? c.name : '${c.name} (${subs.length})', style: const TextStyle(fontSize: 16)),
                            if (subs.isNotEmpty && store.prefs.subcategories)
                              Text(subs.map((s) => s.name).join(', '),
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                          ]),
                        ),
                        IconButton(
                          tooltip: 'Змінити',
                          icon: Icon(Icons.edit_outlined, color: scheme.onSurfaceVariant),
                          onPressed: () => editCategory(context, type: type, existing: c),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(padding: const EdgeInsets.fromLTRB(4, 8, 16, 8), child: Icon(Icons.drag_handle_rounded, color: scheme.onSurfaceVariant)),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}

Future<void> editCategory(BuildContext context, {required TxType type, Category? existing, Category? parent}) async {
  final store = StoreScope.read(context);
  final isSub = parent != null || existing?.parentId != null;
  final name = TextEditingController(text: existing?.name ?? '');
  final emoji = TextEditingController(text: hasIcon(existing?.emoji) ? existing!.emoji : '');
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

// ---- Резервна копія: дії ------------------------------------------------------------------

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

/// Backup through the share sheet: iCloud Drive ("Зберегти у Файли"), Mail…
Future<void> _shareBackup(BuildContext context) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final d = DateTime.now();
  final name = 'pfinance-backup-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json';
  final bytes = Uint8List.fromList(utf8.encode(await store.exportJson()));
  if (await shareFile(bytes, name, 'application/json')) return;
  await FileSaver.instance.saveFile(name: name.replaceAll('.json', ''), bytes: bytes, fileExtension: 'json', mimeType: MimeType.json);
  messenger.showSnackBar(const SnackBar(content: Text('Цей браузер не вміє ділитися файлами, тому копію збережено як завантаження')));
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

/// Import of a Money Manager backup (.mmbak).
Future<void> _importMm(BuildContext context) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  // Any file type: iOS greys out unknown extensions such as .mmbak.
  final files = await FilePicker.pickFiles(type: FileType.any);
  if (files.isEmpty) return;
  final bytes = await files.single.readAsBytes();
  if (!context.mounted) return;
  if (!await _confirm(context, 'Імпортувати з Money Manager?', 'Поточні записи, рахунки, категорії, повтори й бюджети буде замінено даними з файлу. Налаштування вигляду залишаться.')) return;
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
          Expanded(child: Text('Імпортую дані…')),
        ]),
      ),
    ),
  );
  try {
    final s = await store.importMoneyManagerBackup(bytes);
    nav.pop();
    if (!context.mounted) return;
    await _info(
      context,
      'Імпорт завершено',
      'Рахунків: ${s['accounts']}\nКатегорій: ${s['categories']}\nЗаписів: ${s['transactions']}\nПовторів: ${s['repeats']}\nБюджетів: ${s['budgets']}',
    );
  } catch (e) {
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text('Не вдалося імпортувати файл: $e')));
  }
}
