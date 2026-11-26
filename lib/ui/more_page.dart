import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../state/app_store.dart';
import 'accounts_page.dart' show EditAccountsPage, editAccount, groupOf;
import 'app_icon.dart';
import 'edit_transaction.dart' show openTxnEditor, repeatLabel;
import 'export_pf.dart';
import 'pwa.dart';
import 'share_file.dart';
import 'stats_charts.dart';
import 'format.dart';
import 'theme.dart';
import 'transactions_page.dart' show TxnTile;
import 'widgets.dart';
import '../l10n/l10n.dart';

part 'more_extra.dart';

const appVersion = 'v0.9.89';

/// Full names of the supported currencies (Settings → currencies).
Map<String, String> get currencyNames => {
  'UAH': tr('Гривня'), 'USD': tr('Долар США'), 'EUR': tr('Євро'), 'GBP': tr('Фунт стерлінгів'), 'PLN': tr('Злотий'), //
  'CHF': tr('Швейцарський франк'), 'CZK': tr('Чеська крона'), 'CAD': tr('Канадський долар'), 'AUD': tr('Австралійський долар'),
  'JPY': tr('Єна'), 'CNY': tr('Юань'), 'TRY': tr('Турецька ліра'), 'SEK': tr('Шведська крона'), 'NOK': tr('Норвезька крона'),
  'DKK': tr('Данська крона'), 'HUF': tr('Форинт'), 'RON': tr('Румунський лей'), 'GEL': tr('Ларі'), 'KZT': tr('Тенге'), 'ILS': tr('Шекель'),
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                const PfLogo(size: 40),
                const Spacer(),
                Text('PFinance · $appVersion', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                _Group(
                  children: [
                    _Item(
                      Icons.receipt_long_outlined,
                      tr('Налаштування записів'),
                      subtitle: tr('Початок місяця, тижня, перенесення, час, свайп…'),
                      onTap: () => push(const _TxnSettingsPage()),
                    ),
                    _Item(Icons.repeat_rounded, tr('Повторювані записи'), onTap: () => push(const RepeatsPage())),
                    _Item(Icons.content_copy_rounded, tr('Копіювання записів'), onTap: () => push(const _CopyPastePage())),
                  ],
                ),
                _Band(tr('Категорії й рахунки')),
                _Group(
                  children: [
                    _Item(Icons.south_west_rounded, tr('Категорії доходів'), onTap: () => push(const CategoriesPage(type: TxType.income))),
                    _Item(Icons.north_east_rounded, tr('Категорії витрат'), onTap: () => push(const CategoriesPage(type: TxType.expense))),
                    _Item(
                      Icons.account_balance_wallet_outlined,
                      tr('Рахунки'),
                      subtitle: tr('Групи, рахунки, у підсумках, переказ-витрата…'),
                      onTap: () => push(const _AccountsMenu()),
                    ),
                    _Item(Icons.track_changes_rounded, tr('Бюджет'), onTap: () => push(const _BudgetPage())),
                    _Item(Icons.sell_outlined, tr('Теги'), onTap: () => push(const _TagsPage())),
                  ],
                ),
                _Band(tr('Налаштування')),
                _Group(
                  children: [
                    _Item(
                      Icons.settings_backup_restore_rounded,
                      tr('Резервна копія'),
                      subtitle: tr('Експорт, імпорт, повне скидання'),
                      onTap: () => push(const _BackupPage()),
                    ),
                    _Item(Icons.lock_outline_rounded, tr('PIN-код'), badge: pr.pin == null ? null : tr('УВІМК.'), onTap: () => _pinSettings(context)),
                    _Item(
                      Icons.payments_outlined,
                      tr('Основна валюта'),
                      subtitle: '${pr.baseCurrency} (${currencySymbol(pr.baseCurrency)})',
                      onTap: () => push(const _MainCurrencyPage()),
                    ),
                    _Item(
                      Icons.currency_exchange_rounded,
                      tr('Додаткові валюти'),
                      subtitle: subs.isEmpty ? null : subs.map(currencySymbol).join(', '),
                      onTap: () => push(const CurrenciesPage()),
                    ),
                    _Item(Icons.notifications_none_rounded, tr('Нагадування'), onTap: () => push(const _AlarmPage())),
                    _Item(
                      Icons.palette_outlined,
                      tr('Стиль'),
                      subtitle: '${_modeLabel(pr.themeMode)} · ${themeById(pr.themeId).name}',
                      onTap: () => push(const _ThemePage()),
                    ),
                    _Item(Icons.apps_rounded, tr('Іконка застосунку'), onTap: () => _pickAppIcon(context)),
                    _Item(
                      Icons.translate_rounded,
                      tr('Мова'),
                      subtitle: languages[pr.language] ?? languages['uk'],
                      onTap: () async {
                        final v = await chooseOption<String>(context, tr('Мова'), languages, pr.language);
                        if (v != null) await store.updatePrefs((p) => p.language = v);
                      },
                    ),
                    _Item(Icons.help_outline_rounded, tr('Довідка'), onTap: () => push(const _HelpPage())),
                  ],
                ),
                const SizedBox(height: 20),
                Center(child: Text(tr('Дані зберігаються лише на цьому пристрої'), style: Theme.of(context).textTheme.bodySmall)),
              ],
            ),
          ),
        ],
      ),
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
      child: Column(
        children: [
          for (final (i, c) in children.indexed) ...[if (i > 0) Divider(height: 1, thickness: 1, color: line), c],
        ],
      ),
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
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, color: danger ? scheme.error : scheme.primary, size: 24), const SizedBox(width: 16)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title, style: TextStyle(fontSize: 15, color: danger ? scheme.error : null)),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          badge!,
                          style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Text(
                  value!,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(color: scheme.primary, fontSize: 15),
                ),
              ),
            ],
            ?trailing,
          ],
        ),
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
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scheme.primary),
            ),
            child: Icon(icon, color: scheme.primary, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

String _onOff(bool v) => v ? tr('Увімк.') : tr('Вимк.');

String _modeLabel(ThemeMode m) => switch (m) {
  ThemeMode.system => tr('Як у системі'),
  ThemeMode.light => tr('Світлий'),
  ThemeMode.dark => tr('Темний'),
};

Future<void> _info(BuildContext context, String title, String body) => showSheetDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: Text(body),
    actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('Зрозуміло')))],
  ),
);

Future<bool> _confirm(BuildContext context, String title, String body) async =>
    await showSheetDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Скасувати'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Так'))),
        ],
      ),
    ) ??
    false;

Future<T?> _choose<T>(BuildContext context, String title, Map<T, String> options, T current, {String? note, Map<T, Color>? colors, Widget? preview}) =>
    chooseOption<T>(context, title, options, current, note: note, colors: colors, preview: preview);

Future<String?> _askText(BuildContext context, String title, {String initial = '', String? hint}) {
  final ctrl = TextEditingController(text: initial);
  return showSheetDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Скасувати'))),
        FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: Text(tr('Зберегти'))),
      ],
    ),
  );
}

// ---- PIN ------------------------------------------------------------------------

Future<void> _pinSettings(BuildContext context) async {
  final store = StoreScope.read(context);
  if (store.prefs.pin != null) {
    final v = await _choose<String>(context, tr('PIN-код'), {'change': tr('Змінити PIN-код'), 'off': tr('Вимкнути PIN-код')}, '');
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
    message: _first == null ? (_mismatch ? tr('Коди не збіглися') : tr('Введи новий PIN-код')) : tr('Повтори PIN-код'),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Іконка застосунку'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
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
            ],
          ),
          const SizedBox(height: 16),
          Text(tr('На телефоні нова іконка з\'явиться, коли знову додаси сайт на головний екран.'), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
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
  final v = await _choose<String>(context, tr('Основна валюта'), {for (final c in currencies) c: '$c — ${currencyNames[c] ?? c}'}, base);
  if (v == null || v == base) return;
  await store.updatePrefs((p) {
    // Re-express the rates against the new base.
    final k = p.rates[v];
    if (k != null && k > 0) {
      p.rates = {
        for (final e in p.rates.entries)
          if (e.key != v) e.key: e.value / k,
        base: 1 / k,
      };
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
      appBar: AppBar(
        title: Text(tr('Основна валюта')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton(onPressed: () => changeBaseCurrency(context), child: Text(tr('Змінити'))),
          ),
        ],
      ),
      body: ListView(
        children: [
          Container(
            color: panelColor(context),
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text('$c — ${currencyNames[c] ?? c} ($sym)', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
                const SizedBox(height: 6),
                Text(_front ? '$sym $sample' : '$sample $sym', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Group(
            children: [
              _Item(null, tr('Позиція символу'), value: _front ? tr('Спереду') : tr('Позаду'), onTap: () => setState(() => _front = !_front)),
              _Item(null, tr('Десяткові'), value: _decimals ? '1,00' : '1', onTap: () => setState(() => _decimals = !_decimals)),
            ],
          ),
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
              child: Text(tr('Зберегти')),
            ),
          ),
        ],
      ),
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
    final base = store.baseCurrency;
    final others = {...store.currenciesInUse, ...store.prefs.rates.keys}.where((c) => c != base).toList()..sort();
    final nf = NumberFormat('#,##0.######', numberLocale);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Додаткові валюти')),
        actions: [
          IconButton(tooltip: tr('Редагувати'), icon: Icon(_edit ? Icons.check_rounded : Icons.edit_outlined), onPressed: () => setState(() => _edit = !_edit)),
          IconButton(
            tooltip: tr('Додати валюту'),
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final v = await _choose<String>(context, tr('Додати валюту'), {
                for (final c in currencies.where((c) => c != base && !others.contains(c))) c: '$c — ${currencyNames[c] ?? c}',
              }, '');
              if (v != null && context.mounted) _editRate(context, v);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: tr('Оновити курси'),
        onPressed: _loading ? null : () => _refresh(store),
        child: _loading ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Icon(Icons.sync_rounded),
      ),
      body: ListView(
        children: [
          if (others.isEmpty)
            EmptyState(icon: Icons.currency_exchange_rounded, text: tr('Додаткових валют немає.\nДодай валюту кнопкою «+».'))
          else
            _Group(
              children: [
                for (final c in others)
                  _Item(
                    null,
                    '$c 1,00 = $base ${store.prefs.rates[c] == null ? '?' : nf.format(store.prefs.rates[c])}',
                    subtitle: '$c — ${currencyNames[c] ?? c} (${currencySymbol(c)})',
                    trailing: _edit ? IconButton(icon: const MinusBadge(), onPressed: () => store.updatePrefs((p) => p.rates = {...p.rates}..remove(c))) : null,
                    onTap: () => _editRate(context, c),
                  ),
              ],
            ),
          _Group(
            children: [
              _Item(
                null,
                tr('Оновлювати курси щодня'),
                subtitle: store.prefs.ratesUpdated == 0
                    ? tr('Ще не оновлювались')
                    : tr('Оновлено {0}', [shortDate(DateTime.fromMillisecondsSinceEpoch(store.prefs.ratesUpdated))]),
                trailing: Switch(
                  value: store.prefs.autoRates,
                  onChanged: (v) async {
                    await store.updatePrefs((p) => p.autoRates = v);
                    if (v) await store.refreshRates();
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              tr(
                'Ці курси переводять баланси рахунків в основну валюту. Щоденне оновлення бере сьогоднішні курси з open.er-api.com при першому відкритті застосунку за день; кнопка внизу оновлює їх одразу. Курс, змінений уручну, діє до наступного оновлення. Записи завжди рахуються за курсом свого дня.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh(AppStore store) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    final n = await store.refreshRates(force: true);
    if (mounted) setState(() => _loading = false);
    messenger.showSnackBar(SnackBar(content: Text(n == null ? tr('Не вдалося отримати курси. Перевір інтернет.') : tr('Оновлено курсів: {0}', [n]))));
  }

  Future<void> _editRate(BuildContext context, String c) async {
    final store = StoreScope.read(context);
    final ctrl = TextEditingController(text: store.prefs.rates[c]?.toString() ?? '');
    final v = await showSheetDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Курс {0}', [c])),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(prefixText: '1 $c = ', suffixText: store.baseCurrency),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Скасувати'))),
          FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text.replaceAll(',', '.'))), child: Text(tr('Зберегти'))),
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
    final title = parent?.name ?? (type == TxType.income ? tr('Категорії доходів') : tr('Категорії витрат'));
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (parent != null)
            IconButton(
              tooltip: tr('Змінити категорію'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => editCategory(context, type: type, existing: parent),
            ),
          IconButton(
            tooltip: parent == null ? tr('Нова категорія') : tr('Нова підкатегорія'),
            icon: const Icon(Icons.add_rounded),
            onPressed: () => editCategory(context, type: type, parent: parent),
          ),
        ],
      ),
      body: Column(
        children: [
          if (parent == null) ...[
            Container(
              color: panelColor(context),
              child: SwitchListTile(
                title: Text(tr('Підкатегорії')),
                value: store.prefs.subcategories,
                onChanged: (v) => store.updatePrefs((p) => p.subcategories = v),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (cats.isEmpty)
            Expanded(
              child: EmptyState(
                icon: Icons.category_outlined,
                text: parent == null ? tr('Категорій ще немає.\nДодай першу кнопкою «+».') : tr('Підкатегорій немає.'),
              ),
            )
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
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AuroraBackground(
                                  child: CategoriesPage(type: type, parent: c),
                                ),
                              ),
                            )
                          : () => editCategory(context, type: type, existing: c),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: line)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: tr('Видалити'),
                              icon: const MinusBadge(),
                              onPressed: () async {
                                if (await _confirm(context, tr('Видалити «{0}»?', [c.name]), tr('Записи з цією категорією залишаться, але без категорії.'))) {
                                  store.saveCategory(c.copyWith(deleted: true));
                                }
                              },
                            ),
                            if (hasIcon(c.emoji)) ...[Text(c.emoji, style: const TextStyle(fontSize: 20)), const SizedBox(width: 8)],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(subs.isEmpty ? c.name : '${c.name} (${subs.length})', style: const TextStyle(fontSize: 16)),
                                  if (subs.isNotEmpty && store.prefs.subcategories)
                                    Text(
                                      subs.map((s) => s.name).join(', '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: tr('Змінити'),
                              icon: Icon(Icons.edit_outlined, color: scheme.onSurfaceVariant),
                              onPressed: () => editCategory(context, type: type, existing: c),
                            ),
                            ReorderableDragStartListener(
                              index: i,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                                child: Icon(Icons.drag_handle_rounded, color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// MM «Редаг.»/«Додати» category page: «Категорія» (and «Підкатегорія» for a
/// subcategory), a red «Зберегти»; a subcategory can become a main category.
Future<void> editCategory(BuildContext context, {required TxType type, Category? existing, Category? parent}) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (_) => AuroraBackground(
      child: _CategoryForm(type: type, existing: existing, parent: parent),
    ),
  ),
);

class _CategoryForm extends StatefulWidget {
  const _CategoryForm({required this.type, this.existing, this.parent});
  final TxType type;
  final Category? existing;
  final Category? parent;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _emoji = TextEditingController(text: hasIcon(widget.existing?.emoji) ? widget.existing!.emoji : '');
  late int _color = widget.existing?.color ?? widget.parent?.color ?? colorChoices.first;

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    super.dispose();
  }

  Category? _parent(AppStore store) => widget.parent ?? store.category(widget.existing?.parentId);

  void _save() {
    final store = StoreScope.read(context);
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final e = widget.existing;
    final parent = _parent(store);
    store.saveCategory(
      e?.copyWith(name: name, emoji: _emoji.text.trim(), color: _color) ??
          Category(
            name: name,
            type: widget.type,
            parentId: parent?.id,
            emoji: _emoji.text.trim(),
            color: _color,
            sort: parent != null ? store.subcategoriesOf(parent.id).length : store.categoriesOf(widget.type).length,
          ),
    );
    Navigator.pop(context);
  }

  /// MM «→ Основна категорія»: the subcategory moves up; its records stay with it.
  Future<void> _promote() async {
    final store = StoreScope.read(context);
    final e = widget.existing!;
    if (!await _confirm(context, tr('Зробити «{0}» основною категорією?', [e.name]), tr('Записи цієї підкатегорії перейдуть разом із нею.'))) return;
    await store.saveCategory(
      Category(
        id: e.id,
        name: _name.text.trim().isEmpty ? e.name : _name.text.trim(),
        type: e.type,
        emoji: e.emoji,
        color: e.color,
        sort: store.categoriesOf(e.type).length,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final parent = _parent(store);
    final isSub = parent != null;
    final isNew = widget.existing == null;
    const valueStyle = TextStyle(fontSize: 16);
    InputDecoration plain([String? hint]) => InputDecoration(
      hintText: hint,
      filled: false,
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    );
    Widget row(String label, Widget child) => SizedBox(
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 96,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(label, style: TextStyle(fontSize: 14, color: muted)),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: scheme.onSurface.withValues(alpha: 0.12))),
              ),
              alignment: Alignment.centerLeft,
              child: child,
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? tr('Додати') : tr('Редаг.')),
        actions: [
          if (isSub && !isNew)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                  side: BorderSide(color: muted.withValues(alpha: 0.6)),
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(tr('Основна категорія')),
                onPressed: _promote,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (isSub) ...[
            row(tr('Категорія'), Text(parent.name, style: valueStyle.copyWith(color: muted))),
            row(tr('Підкатегорія'), TextField(controller: _name, autofocus: true, style: valueStyle, decoration: plain(), onSubmitted: (_) => _save())),
          ] else
            row(tr('Категорія'), TextField(controller: _name, autofocus: true, style: valueStyle, decoration: plain(), onSubmitted: (_) => _save())),
          const SizedBox(height: 28),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.of(context).expense,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: const StadiumBorder(),
            ),
            onPressed: _save,
            child: Text(tr('Зберегти'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
          ),
          if (!isSub) ...[
            const SizedBox(height: 28),
            Text(tr('Додатково'), style: TextStyle(fontSize: 14, color: muted)),
            const SizedBox(height: 4),
            row(tr('Значок'), TextField(controller: _emoji, style: const TextStyle(fontSize: 20), decoration: plain(tr('— (емодзі, необовʼязково)')))),
            const SizedBox(height: 12),
            ColorPickerRow(value: _color, onChanged: (v) => setState(() => _color = v)),
          ],
        ],
      ),
    );
  }
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
  await store.markBackedUp();
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Резервну копію збережено'))));
}

/// Backup through the share sheet: iCloud Drive ("Зберегти у Файли"), Mail…
/// Also used by the reminder on the Records tab.
Future<void> shareBackup(BuildContext context) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final d = DateTime.now();
  final name = 'pfinance-backup-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json';
  final bytes = Uint8List.fromList(utf8.encode(await store.exportJson()));
  switch (await shareFileResult(bytes, name, 'application/json')) {
    case ShareResult.shared:
      await store.markBackedUp();
      return;
    case ShareResult.cancelled:
      return;
    case ShareResult.unsupported:
      await FileSaver.instance.saveFile(name: name.replaceAll('.json', ''), bytes: bytes, fileExtension: 'json', mimeType: MimeType.json);
      await store.markBackedUp();
      messenger.showSnackBar(SnackBar(content: Text(tr('Цей браузер не вміє ділитися файлами, тому копію збережено як завантаження'))));
  }
}

Future<void> _import(BuildContext context) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
  if (files.isEmpty) return;
  final bytes = await files.single.readAsBytes();
  if (!context.mounted) return;
  if (!await _confirm(context, tr('Відновити з копії?'), tr('Поточні дані буде замінено даними з файлу.'))) return;
  if (!context.mounted) return;
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            SizedBox(width: 20),
            Expanded(child: Text(tr('Відновлюю дані…'))),
          ],
        ),
      ),
    ),
  );
  try {
    await store.importJson(utf8.decode(bytes));
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(tr('Дані відновлено'))));
  } catch (e) {
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(tr('Не вдалося прочитати файл: {0}', [e]))));
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
  if (!await _confirm(
    context,
    tr('Імпортувати з Money Manager?'),
    tr('Поточні записи, рахунки, категорії, повтори й бюджети буде замінено даними з файлу. Налаштування вигляду залишаться.'),
  )) {
    return;
  }
  if (!context.mounted) return;
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            SizedBox(width: 20),
            Expanded(child: Text(tr('Імпортую дані…'))),
          ],
        ),
      ),
    ),
  );
  try {
    final s = await store.importMoneyManagerBackup(bytes);
    nav.pop();
    if (!context.mounted) return;
    await _info(
      context,
      tr('Імпорт завершено'),
      tr('Рахунків: {0}\nКатегорій: {1}\nЗаписів: {2}\nПовторів: {3}\nБюджетів: {4}', [
        s['accounts'],
        s['categories'],
        s['transactions'],
        s['repeats'],
        s['budgets'],
      ]),
    );
  } catch (e) {
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(tr('Не вдалося імпортувати файл: {0}', [e]))));
  }
}

/// How to put PFinance on the home screen; there it works like an app and
/// the browser does not clear its data.
Future<void> showInstallHelp(BuildContext context) {
  final steps = isIos
      ? [
          tr('Відкрий PFinance у Safari.'),
          tr('Натисни «Поділитися» (квадрат зі стрілкою вгору) внизу екрана.'),
          tr('Обери «На початковий екран» і натисни «Додати».'),
          tr('Далі відкривай PFinance значком з головного екрана.'),
        ]
      : [
          tr('Відкрий меню браузера (⋮ або ⋯).'),
          tr('Обери «Установити застосунок» або «Додати на головний екран».'),
          tr('Далі відкривай PFinance значком з головного екрана чи робочого столу.'),
        ];
  return showSheetDialog<void>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(tr('Додати на головний екран')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${i + 1}.',
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(child: Text(steps[i])),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              tr('Так PFinance відкривається на весь екран, працює без інтернету, а браузер не стирає записи, ') +
                  tr('навіть якщо ти довго не заходив у Safari.'),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(shape: const StadiumBorder()),
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Зрозуміло')),
          ),
        ],
      );
    },
  );
}

/// «5 днів тому», «сьогодні», «ще не було».
String backupAgo(int ms) {
  if (ms == 0) return tr('ще не було');
  final last = DateTime.fromMillisecondsSinceEpoch(ms);
  final n = DateTime.now();
  final days = DateTime(n.year, n.month, n.day).difference(DateTime(last.year, last.month, last.day)).inDays;
  if (days <= 0) return tr('сьогодні');
  if (days == 1) return tr('вчора');
  final m10 = days % 10, m100 = days % 100;
  // Ukrainian has three plural forms; the other languages say "days" for 2+.
  final w = lang != 'uk'
      ? tr('днів')
      : m10 == 1 && m100 != 11
      ? tr('день')
      : (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14) ? tr('дні') : tr('днів'));
  return tr('{0} {1} тому', [days, w]);
}
