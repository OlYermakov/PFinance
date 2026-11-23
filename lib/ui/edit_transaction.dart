import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../state/app_store.dart';
import 'accounts_page.dart' show editAccount;
import 'format.dart';
import 'more_page.dart' show CategoriesPage, currencySymbol, editCategory;
import 'theme.dart';
import 'widgets.dart';

/// Opens the full-screen record editor (Money Manager layout: labelled rows on
/// top, a picker panel at the bottom).
Future<void> openTxnEditor(BuildContext context, {Txn? existing, DateTime? date, int? amount}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => AuroraBackground(
      child: TxnEditor(existing: existing, date: date, amount: amount),
    ),
  ),
);

enum _Field { account, toAccount, category, amount, toAmount, fee }

class TxnEditor extends StatefulWidget {
  const TxnEditor({super.key, this.existing, this.date, this.amount});
  final Txn? existing;
  final DateTime? date;
  final int? amount; // minor units of the account currency

  @override
  State<TxnEditor> createState() => _TxnEditorState();
}

class _TxnEditorState extends State<TxnEditor> {
  late TxType _type;
  late DateTime _date;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId; // top-level
  String? _subId;
  String? _expanded; // category whose subcategories are open in the panel
  final _expr = <_Field, String>{_Field.amount: '', _Field.toAmount: '', _Field.fee: ''};
  bool _showFee = false;
  final _note = TextEditingController();
  final _noteFocus = FocusNode();
  _Field? _panel;
  String? _error;
  int _savedInSeries = 0;
  RepeatEvery? _repeat; // new records only
  String? _amountCur; // MM: the amount may be typed in another currency

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    final e = widget.existing;
    _type = e?.type ?? TxType.expense;
    final now = DateTime.now();
    _date = e?.date ?? (widget.date != null ? DateTime(widget.date!.year, widget.date!.month, widget.date!.day, now.hour, now.minute) : now);
    // MM: a new record starts with no account chosen.
    _accountId = e?.accountId;
    _toAccountId = e?.toAccountId;
    final c = store.category(e?.categoryId);
    if (c?.parentId != null) {
      _categoryId = c!.parentId;
      _subId = c.id;
    } else {
      _categoryId = c?.id;
    }
    _note.text = e?.note ?? '';
    if (e != null) {
      final cur = store.account(e.accountId)?.currency ?? store.baseCurrency;
      _expr[_Field.amount] = _input(e.amount, cur);
      if (e.toAmount != null) {
        _expr[_Field.toAmount] = _input(e.toAmount!, store.account(e.toAccountId)?.currency ?? cur);
      }
    } else {
      if (widget.amount != null) {
        _expr[_Field.amount] = _input(widget.amount!, store.account(_accountId)?.currency ?? store.baseCurrency);
      }
      // Like Money Manager: a new record starts with the account grid open.
      _panel = _Field.account;
    }
    _noteFocus.addListener(() {
      setState(() {
        if (_noteFocus.hasFocus) _panel = null;
      });
    });
    // The note autocomplete layer is always mounted; it draws nothing
    // unless there are matches.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _noteOverlay.show();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  static String _input(int minor, String cur) => minorToInput(minor, cur).replaceAll('.', ',');

  int? _minor(_Field f, String currency) {
    final v = evalExpression(_expr[f]!);
    if (v == null || v < 0) return null;
    var m = 1;
    for (var i = 0; i < decimalsOf(currency); i++) {
      m *= 10;
    }
    return (v * m).round();
  }

  void _open(_Field? f) {
    FocusScope.of(context).unfocus();
    setState(() => _panel = _panel == f ? null : f);
  }

  /// Moves to the next empty field after a choice, as Money Manager does.
  void _advance(_Field from) {
    final store = StoreScope.read(context);
    setState(() {
      _error = null;
      if (from == _Field.account && _type == TxType.transfer && _toAccountId == null) {
        _panel = _Field.toAccount;
      } else if (from == _Field.account && _type != TxType.transfer && _categoryId == null) {
        _panel = _Field.category;
      } else if ((from == _Field.category || from == _Field.toAccount || from == _Field.account) && _expr[_Field.amount]!.isEmpty) {
        _panel = _Field.amount;
      } else if (from == _Field.amount && _crossCurrency(store) && _expr[_Field.toAmount]!.isEmpty) {
        _panel = _Field.toAmount;
      } else {
        _panel = null;
      }
    });
  }

  /// "Далі" (MM): go to the next field of the form, in its order.
  void _next() {
    final store = StoreScope.read(context);
    final order = <_Field?>[
      _Field.account,
      if (_type == TxType.transfer) _Field.toAccount,
      if (_type != TxType.transfer) _Field.category,
      _Field.amount,
      if (_crossCurrency(store)) _Field.toAmount,
      if (_type == TxType.transfer && _showFee) _Field.fee,
      null, // the note
    ];
    final current = _noteFocus.hasFocus ? null : _panel;
    final i = _noteFocus.hasFocus ? order.length - 1 : (current == null ? -1 : order.indexOf(current));
    if (i == order.length - 1) {
      FocusScope.of(context).unfocus(); // past the note: just close the keyboard
      return;
    }
    final f = order[i + 1];
    if (f == null) {
      setState(() => _panel = null);
      _noteFocus.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _panel = f);
    }
  }

  /// The amount in [accCur] minor units; typed in another currency it is
  /// converted with the rates from the settings.
  int? _amountIn(AppStore store, String accCur) {
    final from = _amountCur;
    if (from == null || from == accCur) return _minor(_Field.amount, accCur);
    final v = evalExpression(_expr[_Field.amount]!);
    if (v == null || v < 0) return null;
    double rate(String c) => c == store.baseCurrency ? 1 : (store.prefs.rates[c] ?? 0);
    if (rate(from) == 0 || rate(accCur) == 0) return null;
    final inAcc = v * rate(from) / rate(accCur);
    var m = 1;
    for (var i = 0; i < decimalsOf(accCur); i++) {
      m *= 10;
    }
    return (inAcc * m).round();
  }

  bool _crossCurrency(AppStore store) {
    final a = store.account(_accountId), b = store.account(_toAccountId);
    return _type == TxType.transfer && a != null && b != null && a.currency != b.currency;
  }

  /// Note history for the chosen category (MM "Note button").
  Future<void> _pickNote(AppStore store) async {
    final notes = store.noteSuggestions(_subId ?? _categoryId, '');
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => notes.isEmpty
          ? const Padding(padding: EdgeInsets.fromLTRB(24, 0, 24, 32), child: Text('Нотаток для цієї категорії ще немає'))
          : ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 24),
              children: [for (final n in notes) ListTile(title: Text(n), onTap: () => Navigator.pop(context, n))],
            ),
    );
    if (v != null) setState(() => _note.text = v);
  }

  Future<void> _save({bool keepOpen = false, bool copy = false}) async {
    final store = StoreScope.read(context);
    final acc = store.account(_accountId);
    if (acc == null) return setState(() => _error = 'Обери рахунок');
    if (_type != TxType.transfer && _categoryId == null) {
      return setState(() => _error = 'Обери категорію');
    }
    final amount = _amountIn(store, acc.currency);
    if (amount == null || amount == 0) {
      return setState(() => _error = 'Введи суму');
    }
    int? toAmount;
    int? fee;
    if (_type == TxType.transfer) {
      final to = store.account(_toAccountId);
      if (to == null || to.id == acc.id) {
        return setState(() => _error = 'Обери рахунок, куди переказ');
      }
      if (to.currency != acc.currency) {
        toAmount = _minor(_Field.toAmount, to.currency);
        if (toAmount == null || toAmount == 0) {
          return setState(() => _error = 'Введи суму зарахування в ${to.currency}');
        }
      }
      if (_showFee) fee = _minor(_Field.fee, acc.currency);
    }
    final txn = Txn(
      id: keepOpen || copy ? null : widget.existing?.id,
      type: _type,
      amount: amount,
      accountId: acc.id,
      toAccountId: _type == TxType.transfer ? _toAccountId : null,
      toAmount: toAmount,
      categoryId: _type == TxType.transfer ? null : (_subId ?? _categoryId),
      date: copy && store.prefs.copyToToday ? DateTime.now() : _date,
      note: _note.text.trim(),
    );
    final messenger = ScaffoldMessenger.of(context);
    await store.saveTxn(txn);
    if (fee != null && fee > 0) {
      // A transfer fee is an expense on the sending account.
      await store.saveTxn(
        Txn(type: TxType.expense, amount: fee, accountId: acc.id, categoryId: _feeCategory(store)?.id, date: txn.date, note: 'Комісія за переказ'),
      );
    }
    if (_repeat != null && _isNew && !copy) {
      // This record is the first occurrence; the rule makes the next ones.
      await store.saveRepeat(RepeatRule(template: txn, every: _repeat!, start: txn.date, lastDone: txn.date));
      _repeat = null;
    }
    HapticFeedback.lightImpact();
    if (!mounted) return;
    if (copy) {
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text('Скопійовано на ${shortDate(txn.date)}')));
      return;
    }
    if (keepOpen) {
      // Save and start the next record: it keeps date, account and type.
      setState(() {
        _savedInSeries++;
        _expr.updateAll((_, _) => '');
        _showFee = false;
        _note.clear();
        _subId = null;
        _categoryId = null;
        _expanded = null;
        _error = null;
        _panel = _type == TxType.transfer ? _Field.amount : _Field.category;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Category? _feeCategory(AppStore store) {
    final cats = store.categoriesOf(TxType.expense);
    return cats.where((c) => c.name.toLowerCase().contains('коміс')).firstOrNull ?? cats.where((c) => c.name == 'Інше').firstOrNull ?? cats.lastOrNull;
  }

  Future<void> _pickDate() async {
    _open(null);
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d != null) {
      setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
    }
  }

  Future<void> _pickTime() async {
    _open(null);
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date));
    if (t != null) {
      setState(() => _date = DateTime(_date.year, _date.month, _date.day, t.hour, t.minute));
    }
  }

  Future<void> _addTag() async {
    _open(null);
    final store = StoreScope.read(context);
    final ctrl = TextEditingController();
    final existing = store.tags().map((t) => t.tag).toList();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Тег'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(prefixText: '#', hintText: 'відпустка'),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
            if (existing.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final t in existing.take(12)) ActionChip(label: Text('#$t'), onPressed: () => Navigator.pop(context, t))],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Додати')),
        ],
      ),
    );
    final clean = tag?.trim().replaceAll('#', '').replaceAll(RegExp(r'\s+'), '_');
    if (clean == null || clean.isEmpty) return;
    if (_tagsOf(_note.text).contains(clean.toLowerCase())) return;
    setState(() => _note.text = '${_note.text.trim()} #$clean'.trim());
  }

  static final _tagRe = RegExp(r'#([\p{L}\p{N}_-]+)', unicode: true);
  static List<String> _tagsOf(String note) => [for (final m in _tagRe.allMatches(note)) m.group(1)!.toLowerCase()];

  void _removeTag(String tag) => setState(() {
    _note.text = _note.text.replaceAll(RegExp('\\s*#${RegExp.escape(tag)}(?![\\p{L}\\p{N}_-])', unicode: true, caseSensitive: false), '').trim();
  });

  Future<void> _templates() async {
    _open(null);
    final store = StoreScope.read(context);
    final picked = await showModalBottomSheet<Txn>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final list = StoreScope.of(context).templates.where((t) => t.type == _type).toList();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Шаблони', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Часті записи одним дотиком: оренда, кава, проїзд.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                for (final t in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(store.category(t.categoryId)?.emoji ?? (t.type == TxType.transfer ? '🔁' : '⭐'), style: const TextStyle(fontSize: 22)),
                    title: Text(t.note.isNotEmpty ? t.note : txnTitle(store, t)),
                    subtitle: Text('${txnTitle(store, t)} · ${store.account(t.accountId)?.name ?? ''}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (t.amount > 0) Text(money(t.amount, store.currencyOf(t)), style: const TextStyle(fontWeight: FontWeight.w700)),
                        IconButton(
                          tooltip: 'Видалити шаблон',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () async {
                            await store.deleteTemplate(t);
                            setSheet(() {});
                          },
                        ),
                      ],
                    ),
                    onTap: () => Navigator.pop(context, t),
                  ),
                if (list.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Шаблонів ще немає.')),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.star_outline_rounded),
                  label: const Text('Зберегти поточний запис як шаблон'),
                  onPressed: () async {
                    final acc = store.account(_accountId);
                    await store.saveTemplate(
                      Txn(
                        type: _type,
                        amount: acc == null ? 0 : (_amountIn(store, acc.currency) ?? 0),
                        accountId: _accountId ?? '',
                        toAccountId: _type == TxType.transfer ? _toAccountId : null,
                        categoryId: _type == TxType.transfer ? null : (_subId ?? _categoryId),
                        date: _date,
                        note: _note.text.trim(),
                      ),
                    );
                    setSheet(() {});
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _type = picked.type;
      if (store.account(picked.accountId) != null) {
        _accountId = picked.accountId;
      }
      _toAccountId = picked.toAccountId;
      final c = store.category(picked.categoryId);
      _categoryId = c?.parentId ?? c?.id;
      _subId = c?.parentId != null ? c!.id : null;
      if (picked.amount > 0) {
        _expr[_Field.amount] = _input(picked.amount, store.currencyOf(picked));
      }
      _note.text = picked.note;
      _panel = picked.amount > 0 ? null : _Field.amount;
    });
  }

  // ---- UI --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = AppPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final acc = store.account(_accountId);
    final to = store.account(_toAccountId);
    final cross = _crossCurrency(store);
    final accent = switch (_type) {
      TxType.expense => p.expense,
      TxType.income => incomeColor(context, store),
      TxType.transfer => scheme.onSurface,
    };
    final title = switch (_type) {
      TxType.expense => 'Витрата',
      TxType.income => 'Дохід',
      TxType.transfer => 'Переказ',
    };
    final cat = store.category(_subId ?? _categoryId);
    final top = store.category(_categoryId);
    final suggestions = _type == TxType.transfer || !store.prefs.noteSuggestions || _note.text.trim().isEmpty
        ? const <String>[]
        : store.noteSuggestions(_subId ?? _categoryId, _note.text.trim());
    final tags = _tagsOf(_note.text);
    final cur = acc?.currency ?? store.baseCurrency;

    Widget amountText(_Field f, String currency) {
      final e = _expr[f]!;
      final v = evalExpression(e);
      final hasOp = RegExp(r'[+−×÷]').hasMatch(e);
      return Row(
        children: [
          Expanded(
            child: Text(
              e,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: accent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasOp && v != null) Text('= ${_CalcPad.fmt(v)}  ', style: TextStyle(color: scheme.onSurfaceVariant)),
          Text(
            currency,
            style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    final form = ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _TypeTabs(
          value: _type,
          colors: {TxType.income: incomeColor(context, store), TxType.expense: p.expense, TxType.transfer: scheme.onSurface},
          onChanged: (t) => setState(() {
            if (_type != t) {
              _categoryId = null;
              _subId = null;
              _expanded = null;
            }
            _type = t;
            _error = null;
            _panel = _accountId == null
                ? _Field.account
                : t == TxType.transfer
                ? (_toAccountId == null ? _Field.toAccount : _Field.amount)
                : _Field.category;
          }),
        ),
        const SizedBox(height: 8),
        _FormRow(
          label: 'Дата',
          accent: accent,
          trailing: _isNew ? _repeatButton(scheme) : null,
          child: Row(
            children: [
              InkWell(
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(_dateLabel(_date), style: _valueStyle),
                ),
              ),
              if (store.prefs.timeMode != 0) ...[
                const SizedBox(width: 14),
                InkWell(
                  onTap: _pickTime,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(TimeOfDay.fromDateTime(_date).format(context), style: _valueStyle),
                  ),
                ),
              ],
            ],
          ),
        ),
        ...(() {
          final accRow = _FormRow(
            label: _type == TxType.transfer ? 'Звідки' : 'Рахунок',
            accent: accent,
            active: _panel == _Field.account,
            onTap: () => _open(_Field.account),
            trailing: _type == TxType.transfer
                ? IconButton(
                    tooltip: 'Поміняти місцями',
                    icon: const Icon(Icons.swap_vert_rounded),
                    onPressed: () => setState(() {
                      final a = _accountId;
                      _accountId = _toAccountId ?? _accountId;
                      _toAccountId = a;
                    }),
                  )
                : null,
            child: Text(acc?.name ?? '', style: _valueStyle),
          );
          final Widget catRow = _type == TxType.transfer
              ? _FormRow(
                  label: 'Куди',
                  accent: accent,
                  active: _panel == _Field.toAccount,
                  onTap: () => _open(_Field.toAccount),
                  child: Text(to?.name ?? '', style: _valueStyle),
                )
              : _FormRow(
                  label: 'Категорія',
                  accent: accent,
                  active: _panel == _Field.category,
                  onTap: () => _open(_Field.category),
                  child: Text(
                    cat == null ? '' : (cat.parentId != null ? '${top?.name ?? ''} / ${cat.name}' : cat.name),
                    style: _valueStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
          return store.prefs.categoryFirst && _type != TxType.transfer ? [catRow, accRow] : [accRow, catRow];
        })(),
        _FormRow(
          label: 'Сума',
          accent: accent,
          active: _panel == _Field.amount,
          onTap: () => _open(_Field.amount),
          trailing: _type == TxType.transfer
              ? Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: _showFee ? scheme.primary.withValues(alpha: 0.15) : null,
                    ),
                    onPressed: () => setState(() {
                      _showFee = !_showFee;
                      _panel = _showFee ? _Field.fee : null;
                    }),
                    child: const Text('Комісія'),
                  ),
                )
              : null,
          child: amountText(_Field.amount, _amountCur ?? cur),
        ),
        if (cross)
          _FormRow(
            label: 'Зараховано',
            accent: accent,
            active: _panel == _Field.toAmount,
            onTap: () => _open(_Field.toAmount),
            child: amountText(_Field.toAmount, to!.currency),
          ),
        if (_type == TxType.transfer && _showFee)
          _FormRow(label: 'Комісія', accent: accent, active: _panel == _Field.fee, onTap: () => _open(_Field.fee), child: amountText(_Field.fee, cur)),
        _FormRow(
          label: 'Нотатка',
          accent: accent,
          active: _noteFocus.hasFocus,
          trailing: store.prefs.noteButton && _type != TxType.transfer
              ? IconButton(tooltip: 'Попередні нотатки', icon: const Icon(Icons.notes_rounded), onPressed: () => _pickNote(store))
              : _note.text.isNotEmpty && _noteFocus.hasFocus
              ? IconButton(
                  tooltip: 'Очистити',
                  icon: Icon(Icons.cancel_rounded, size: 20, color: scheme.onSurfaceVariant),
                  onPressed: () => setState(() => _note.clear()),
                )
              : null,
          // MM: as you type, earlier notes drop down above the field with
          // the typed letters in red; tap one to take it.
          child: OverlayPortal(
            controller: _noteOverlay,
            overlayChildBuilder: (context) {
              final list = _noteFocus.hasFocus && _note.text.trim().isNotEmpty ? suggestions.where((s) => s != _note.text).toList() : const <String>[];
              if (list.isEmpty) return const SizedBox.shrink();
              return CompositedTransformFollower(
                link: _noteLink,
                targetAnchor: Alignment.topLeft,
                followerAnchor: Alignment.bottomLeft,
                offset: const Offset(-16, -4),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  // a tap here must not count as "outside" the note field
                  child: TextFieldTapRegion(
                    child: SizedBox(
                      width: _noteWidth + 16,
                      child: Material(
                        color: const Color(0xFF3A3C42),
                        borderRadius: BorderRadius.circular(8),
                        elevation: 6,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final s in list)
                                InkWell(
                                  onTap: () => setState(() {
                                    _note.text = s;
                                    _note.selection = TextSelection.collapsed(offset: s.length);
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                    child: _highlight(s, _note.text.trim(), accent),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            child: CompositedTransformTarget(
              link: _noteLink,
              child: LayoutBuilder(
                builder: (context, box) {
                  _noteWidth = box.maxWidth;
                  return TextField(
                    controller: _note,
                    focusNode: _noteFocus,
                    style: _valueStyle,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                      hintText: 'магазин, одержувач…',
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _save(),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Divider(height: 22, color: Colors.white.withValues(alpha: 0.08)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in tags) InputChip(label: Text('#$t'), onDeleted: () => _removeTag(t), visualDensity: VisualDensity.compact),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Тег', style: TextStyle(fontSize: 14)),
              shape: const StadiumBorder(),
              side: BorderSide.none,
              backgroundColor: Colors.black.withValues(alpha: 0.22),
              visualDensity: VisualDensity.compact,
              onPressed: _addTag,
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
                  ),
                ),
        ),
        if (_savedInSeries > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Збережено записів: $_savedInSeries', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            if (!_isNew) ...[
              IconButton.outlined(
                tooltip: 'Видалити',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  await store.deleteTxn(widget.existing!);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(width: 8),
              if (store.prefs.copyPaste) ...[
                IconButton.outlined(tooltip: 'Копіювати', icon: const Icon(Icons.copy_rounded), onPressed: () => _save(copy: true)),
                const SizedBox(width: 8),
              ],
            ],
            // MM: a wide "Зберегти" and a narrow "Далі", both 47pt high
            Expanded(
              flex: 11,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _type == TxType.transfer ? scheme.primary : accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => _save(),
                child: const Text('Зберегти', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
              ),
            ),
            if (_isNew) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    foregroundColor: scheme.onSurface,
                    side: BorderSide(color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _next,
                  child: const Text('Далі', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ],
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(title, key: ValueKey(title)),
        ),
        centerTitle: true,
        actions: [IconButton(tooltip: 'Шаблони', icon: const Icon(Icons.star_outline_rounded), onPressed: _templates)],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: form),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _panel == null ? const SizedBox(width: double.infinity) : _buildPanel(store, accent),
            ),
          ],
        ),
      ),
    );
  }

  final _noteLink = LayerLink();
  final _noteOverlay = OverlayPortalController();
  double _noteWidth = 240;

  /// [text] with the first match of [query] in [color] (MM autocomplete).
  static Widget _highlight(String text, String query, Color color) {
    final i = text.toLowerCase().indexOf(query.toLowerCase());
    const base = TextStyle(fontSize: 16);
    if (i < 0 || query.isEmpty) return Text(text, style: base, maxLines: 1, overflow: TextOverflow.ellipsis);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, i)),
          TextSpan(
            text: text.substring(i, i + query.length),
            style: TextStyle(color: color),
          ),
          TextSpan(text: text.substring(i + query.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  static const _valueStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w400);

  static String _dateLabel(DateTime d) {
    final w = weekdayShort(d);
    return '${w[0].toUpperCase()}${w.substring(1)} ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  Widget _repeatButton(ColorScheme scheme) => PopupMenuButton<String>(
    tooltip: 'Повторювати',
    initialValue: _repeat?.name ?? 'none',
    onSelected: (v) => setState(() => _repeat = RepeatEvery.values.asNameMap()[v]),
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'none', child: Text('Не повторювати')),
      for (final r in RepeatEvery.values) PopupMenuItem(value: r.name, child: Text(repeatLabel(r))),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat_rounded, color: _repeat == null ? scheme.onSurfaceVariant : scheme.primary),
          Text(
            _repeat == null ? 'Повтор' : repeatShort(_repeat!),
            style: TextStyle(fontSize: 11, color: _repeat == null ? scheme.onSurfaceVariant : scheme.primary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );

  Widget _buildPanel(AppStore store, Color accent) {
    final f = _panel!;
    final scheme = Theme.of(context).colorScheme;
    final (String title, VoidCallback? edit, Widget body) = switch (f) {
      _Field.account || _Field.toAccount => (
        'Рахунок',
        null,
        _Grid(
          accent: accent,
          cells: [
            for (final a in store.activeAccounts.where((a) => f == _Field.account || a.id != _accountId))
              _Cell(
                a.name,
                selected: a.id == (f == _Field.account ? _accountId : _toAccountId),
                onTap: () {
                  setState(() {
                    if (f == _Field.account) {
                      _accountId = a.id;
                      if (_toAccountId == a.id) _toAccountId = null;
                    } else {
                      _toAccountId = a.id;
                    }
                  });
                  _advance(f);
                },
              ),
            _Cell('Додати', muted: true, onTap: () => editAccount(context)),
          ],
        ),
      ),
      _Field.category => ('Категорія', () => _pushPage(CategoriesPage(type: _type)), _categoryGrid(store, accent)),
      _ => (
        switch (f) {
          _Field.toAmount => 'Зараховано',
          _Field.fee => 'Комісія',
          _ => 'Сума',
        },
        null,
        Column(
          children: [
            if (f == _Field.amount) _currencyRow(store, scheme),
            _CalcPad(
              accent: _type == TxType.transfer ? scheme.primary : accent,
              onKey: (k) => setState(() => _expr[f] = _CalcPad.apply(_expr[f]!, k)),
              onDone: () {
                final v = evalExpression(_expr[f]!);
                setState(() => _expr[f] = v == null ? '' : _CalcPad.fmt(v));
                _advance(f);
              },
            ),
          ],
        ),
      ),
    };
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.only(left: 16),
            color: Colors.white.withValues(alpha: 0.06),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ),
                if (edit != null) IconButton(tooltip: 'Редагувати', icon: const Icon(Icons.edit_outlined), onPressed: edit),
                IconButton(tooltip: 'Закрити', icon: const Icon(Icons.close_rounded), onPressed: () => _open(null)),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.42),
            child: SingleChildScrollView(child: body),
          ),
        ],
      ),
    );
  }

  /// MM: the currencies in use above the keypad; the chosen one is lit.
  Widget _currencyRow(AppStore store, ColorScheme scheme) {
    final accCur = store.account(_accountId)?.currency ?? store.baseCurrency;
    final list = <String>{accCur, store.baseCurrency, ...store.prefs.rates.keys}.toList();
    if (list.length < 2) return const SizedBox.shrink();
    final sel = _amountCur ?? accCur;
    return Container(
      height: 44,
      color: const Color(0xFF2E3557),
      child: Row(
        children: [
          for (final c in list)
            InkWell(
              onTap: () => setState(() => _amountCur = c == accCur ? null : c),
              child: Container(
                width: 60,
                alignment: Alignment.center,
                color: c == sel ? Colors.white.withValues(alpha: 0.16) : null,
                child: Text(currencySymbol(c), style: const TextStyle(fontSize: 17, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  void _pushPage(Widget page) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => AuroraBackground(child: page)));

  Widget _categoryGrid(AppStore store, Color accent) {
    final useSubs = store.prefs.subcategories;
    final cells = <_Cell>[
      for (final c in store.categoriesOf(_type)) _categoryCell(store, c, useSubs ? store.subcategoriesOf(c.id) : const <Category>[]),
      _Cell('Додати', muted: true, onTap: () => editCategory(context, type: _type)),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 3) {
      final row = cells.sublist(i, (i + 3).clamp(0, cells.length));
      rows.add(_Grid(accent: accent, cells: row));
      final open = row.where((c) => c.id != null && c.id == _expanded).firstOrNull;
      if (open != null) {
        rows.add(
          _Grid(
            accent: accent,
            tinted: true,
            cells: [
              for (final s in store.subcategoriesOf(open.id!))
                _Cell(
                  s.name,
                  selected: _subId == s.id,
                  onTap: () {
                    setState(() {
                      _categoryId = open.id;
                      _subId = s.id;
                    });
                    _advance(_Field.category);
                  },
                ),
              _Cell(
                'Додати',
                muted: true,
                onTap: () => editCategory(context, type: _type, parent: store.category(open.id)),
              ),
            ],
          ),
        );
      }
    }
    return Column(children: rows);
  }

  _Cell _categoryCell(AppStore store, Category c, List<Category> subs) => _Cell(
    c.name,
    emoji: hasIcon(c.emoji) ? c.emoji : null,
    id: c.id,
    selected: _categoryId == c.id || _expanded == c.id,
    chevron: subs.isEmpty ? null : (_expanded == c.id ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded),
    onTap: () {
      if (subs.isNotEmpty && _expanded != c.id) {
        setState(() => _expanded = c.id);
        return;
      }
      // Tapping an open category again picks it without a subcategory.
      setState(() {
        _categoryId = c.id;
        _subId = null;
      });
      _advance(_Field.category);
    },
  );
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.value, required this.colors, required this.onChanged});
  final TxType value;
  final Map<TxType, Color> colors;
  final ValueChanged<TxType> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = {TxType.income: 'Дохід', TxType.expense: 'Витрата', TxType.transfer: 'Переказ'};
    return Row(
      children: [
        for (final t in [TxType.income, TxType.expense, TxType.transfer])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.5),
              child: GestureDetector(
                onTap: () => onChanged(t),
                // MM: flat rectangles, the chosen one outlined in its colour
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: Colors.black.withValues(alpha: 0.22),
                    border: Border.all(color: t == value ? colors[t]! : Colors.black.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Text(
                    labels[t]!,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: t == value ? colors[t] : Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One labelled line of the form: grey label on the left, value on an
/// underline that takes the type colour while its picker is open.
class _FormRow extends StatelessWidget {
  const _FormRow({required this.label, required this.child, required this.accent, this.active = false, this.onTap, this.trailing});
  final String label;
  final Widget child;
  final Color accent;
  final bool active;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 74,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(label, style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant)),
              ),
            ),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: active ? accent : Colors.white.withValues(alpha: 0.12), width: active ? 2 : 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(alignment: Alignment.centerLeft, child: child),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell {
  const _Cell(this.label, {required this.onTap, this.emoji, this.selected = false, this.muted = false, this.chevron, this.id});
  final String label;
  final String? emoji;
  final VoidCallback onTap;
  final bool selected;
  final bool muted;
  final IconData? chevron;
  final String? id;
}

/// Money Manager–style 3-column picker grid.
class _Grid extends StatelessWidget {
  const _Grid({required this.cells, required this.accent, this.tinted = false});
  final List<_Cell> cells;
  final Color accent;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = Colors.white.withValues(alpha: 0.07);
    final rows = <List<_Cell?>>[];
    for (var i = 0; i < cells.length; i += 3) {
      final r = <_Cell?>[...cells.sublist(i, (i + 3).clamp(0, cells.length))];
      while (r.length < 3) {
        r.add(null);
      }
      rows.add(r);
    }
    return Column(
      children: [
        for (final r in rows)
          Row(
            children: [
              for (final c in r)
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: tinted ? accent.withValues(alpha: 0.10) : ((c?.selected ?? false) ? Colors.white.withValues(alpha: 0.06) : null),
                      border: Border(
                        right: BorderSide(color: line),
                        bottom: BorderSide(color: line),
                      ),
                    ),
                    child: c == null
                        ? null
                        : InkWell(
                            onTap: c.onTap,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    c.emoji == null ? c.label : '${c.emoji} ${c.label}',
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: c.selected ? FontWeight.w700 : FontWeight.w500,
                                      color: c.selected ? accent : (c.muted ? scheme.onSurfaceVariant : null),
                                    ),
                                  ),
                                ),
                                if (c.chevron != null) Positioned(bottom: 2, child: Icon(c.chevron, size: 16, color: scheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Amount keypad with a built-in calculator (+ − × ÷).
class _CalcPad extends StatelessWidget {
  const _CalcPad({required this.accent, required this.onKey, required this.onDone});
  final Color accent;
  final ValueChanged<String> onKey;
  final VoidCallback onDone;

  static const _ops = '+−×÷';

  static String apply(String e, String k) {
    if (k == '⌫') return e.isEmpty ? e : e.substring(0, e.length - 1);
    if (k == '=') {
      final v = evalExpression(e);
      return v == null ? e : fmt(v);
    }
    final last = e.isEmpty ? '' : e[e.length - 1];
    if (_ops.contains(k)) {
      if (e.isEmpty) return e;
      if (_ops.contains(last)) return e.substring(0, e.length - 1) + k;
      return e + k;
    }
    if (k == '00' || k == '000') {
      var r = e;
      for (var i = 0; i < k.length; i++) {
        r = apply(r, '0');
      }
      return r;
    }
    final current = RegExp(r'[0-9,]*$').firstMatch(e)!.group(0)!; // number being typed
    if (current == '0' && k != ',') return e.substring(0, e.length - 1) + k; // no leading zeros
    if (k == ',') {
      if (current.contains(',')) return e;
      return current.isEmpty ? '${e}0,' : '$e,';
    }
    // At most two decimals per number.
    final dec = current.indexOf(',');
    if (dec >= 0 && current.length - dec - 1 >= 2) return e;
    return e + k;
  }

  static String fmt(double v) {
    var s = ((v * 100).roundToDouble() / 100).toStringAsFixed(2);
    if (s.endsWith('.00')) s = s.substring(0, s.length - 3);
    return s.replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final line = Colors.white.withValues(alpha: 0.07);
    Widget key(String k, {int flex = 1, Color? bg, Color? fg, VoidCallback? onTap}) => Expanded(
      flex: flex,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            right: BorderSide(color: line),
            bottom: BorderSide(color: line),
          ),
        ),
        child: InkWell(
          onTap: onTap ?? () => onKey(k),
          child: Center(
            child: k == '⌫'
                ? const Icon(Icons.backspace_outlined, size: 22)
                : Text(
                    k,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: fg),
                  ),
          ),
        ),
      ),
    );
    final opBg = Colors.black.withValues(alpha: 0.22);
    // MM layout: operators on top; "=", "," and ⌫ in the right column;
    // 00 / 0 / 000 and OK at the bottom.
    return Column(
      children: [
        Row(
          children: [
            for (final k in ['+', '−', '×', '÷']) key(k, bg: opBg),
          ],
        ),
        Row(children: [key('7'), key('8'), key('9'), key('=')]),
        Row(children: [key('4'), key('5'), key('6'), key(',')]),
        Row(children: [key('1'), key('2'), key('3'), key('⌫')]),
        Row(
          children: [
            key('00'),
            key('0'),
            key('000'),
            key('OK', bg: accent, fg: Colors.white, onTap: onDone),
          ],
        ),
      ],
    );
  }
}

/// Evaluates "12,5+3×2" (× and ÷ before + and −). A trailing operator is
/// ignored ("12+" → 12). Null if there is no number.
double? evalExpression(String s) {
  if (s.isEmpty) return null;
  final tokens = RegExp(r'[0-9]+(?:,[0-9]*)?|[+−×÷]').allMatches(s).map((m) => m.group(0)!).toList();
  if (tokens.join() != s) return null;
  final nums = <double>[];
  final ops = <String>[];
  var expectNumber = true;
  for (final t in tokens) {
    if (expectNumber) {
      final v = double.tryParse(t.replaceAll(',', '.'));
      if (v == null) return null;
      nums.add(v);
      expectNumber = false;
      if (ops.isNotEmpty && (ops.last == '×' || ops.last == '÷')) {
        final b = nums.removeLast(), a = nums.removeLast(), op = ops.removeLast();
        if (op == '÷' && b == 0) return null;
        nums.add(op == '×' ? a * b : a / b);
      }
    } else {
      ops.add(t);
      expectNumber = true;
    }
  }
  if (nums.isEmpty) return null;
  if (expectNumber) ops.removeLast();
  var r = nums.first;
  for (var i = 0; i < ops.length; i++) {
    r = ops[i] == '+' ? r + nums[i + 1] : r - nums[i + 1];
  }
  return r;
}

String repeatLabel(RepeatEvery r) => switch (r) {
  RepeatEvery.day => 'Щодня',
  RepeatEvery.week => 'Щотижня',
  RepeatEvery.twoWeeks => 'Кожні 2 тижні',
  RepeatEvery.fourWeeks => 'Кожні 4 тижні',
  RepeatEvery.month => 'Щомісяця',
  RepeatEvery.quarter => 'Щокварталу',
  RepeatEvery.year => 'Щороку',
};

String repeatShort(RepeatEvery r) => switch (r) {
  RepeatEvery.day => 'день',
  RepeatEvery.week => 'тиждень',
  RepeatEvery.twoWeeks => '2 тижні',
  RepeatEvery.fourWeeks => '4 тижні',
  RepeatEvery.month => 'місяць',
  RepeatEvery.quarter => 'квартал',
  RepeatEvery.year => 'рік',
};
