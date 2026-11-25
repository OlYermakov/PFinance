import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import 'widgets.dart' show chooseOption;
import '../state/app_store.dart';
import '../l10n/l10n.dart';

/// Builds an .xlsx in the export layout the PF dashboard already imports
/// (Period, Accounts, Category, Subcategory, Note, EUR, Income/Expense,
/// Description, Amount, Currency, Accounts). Transfers become a
/// Transfer-Out / Transfer-In pair, the counter-account is in Category.
Uint8List buildPfWorkbook(AppStore store, {DateTime? from, DateTime? to}) {
  final excel = Excel.createExcel();
  final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
  final sheet = excel[sheetName];
  const headers = ['Period', 'Accounts', 'Category', 'Subcategory', 'Note', 'EUR', 'Income/Expense', 'Description', 'Amount', 'Currency', 'Accounts'];
  sheet.appendRow([for (final h in headers) TextCellValue(h)]);
  final df = DateFormat('dd.MM.yyyy, HH:mm:ss');

  double major(int minor, String cur) => minor / 100;
  CellValue? eur(int minor, String cur, [Txn? src]) {
    if (cur == 'EUR') return DoubleCellValue(major(minor, cur));
    // the rate of the record's day when known
    if (src != null && src.atBase != null && src.atBaseCur == 'EUR') return DoubleCellValue(src.atBase! / 100);
    if (store.baseCurrency == 'EUR' && store.prefs.rates.containsKey(cur)) {
      return DoubleCellValue(store.toBase(minor, cur) / 100);
    }
    return null;
  }

  void row(DateTime d, String acc, String cat, String sub, String note, String type, int minor, String cur, [Txn? src]) {
    final amount = DoubleCellValue(major(minor, cur));
    sheet.appendRow([
      TextCellValue(df.format(d)),
      TextCellValue(acc),
      TextCellValue(cat),
      TextCellValue(sub),
      TextCellValue(note),
      eur(minor, cur, src),
      TextCellValue(type),
      TextCellValue(''),
      amount,
      TextCellValue(cur),
      amount,
    ]);
  }

  final list = store.txns.where((t) => (from == null || !t.date.isBefore(from)) && (to == null || t.date.isBefore(to))).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  for (final t in list) {
    final acc = store.account(t.accountId);
    final cur = acc?.currency ?? store.baseCurrency;
    switch (t.type) {
      case TxType.income || TxType.expense:
        final c = store.category(t.categoryId);
        final top = store.topCategory(t.categoryId);
        final sub = c != null && top != null && c.id != top.id ? c.name : '';
        row(t.date, acc?.name ?? '', top?.name ?? '', sub, t.note, t.type == TxType.income ? 'Income' : 'Exp.', t.amount, cur, t);
      case TxType.transfer:
        final dst = store.account(t.toAccountId);
        row(t.date, acc?.name ?? '', dst?.name ?? '', '', t.note, 'Transfer-Out', t.amount, cur, t);
        row(t.date, dst?.name ?? '', acc?.name ?? '', '', t.note, 'Transfer-In', t.toAmount ?? t.amount, dst?.currency ?? cur);
    }
  }
  return Uint8List.fromList(excel.encode()!);
}

/// MM «Надісл. Ексель»: pick the period first (this month, last month, this
/// year, last year, everything), then save the .xlsx. [month] is the
/// accounting month on screen; the choices are counted from it.
Future<void> exportForPf(BuildContext context, {DateTime? month}) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final m = month ?? store.periodOf(DateTime.now());
  final cur = store.periodRange(m);
  final prev = store.periodRange(DateTime(m.year, m.month - 1));
  ({DateTime start, DateTime end}) year(int y) => store.yearRange(y);
  final df = DateFormat('d.M.yyyy');
  String span(({DateTime start, DateTime end}) r) {
    final last = r.end.subtract(const Duration(days: 1));
    return '${df.format(r.start)} ~ ${last.day}.${last.month}.';
  }

  final options = <(String, ({DateTime start, DateTime end})?)>[
    (tr('Місяць ({0})', [span(cur)]), cur),
    (tr('Мин. місяць ({0})', [span(prev)]), prev),
    (tr('Рік ({0})', [span(year(m.year))]), year(m.year)),
    (tr('Мин. рік ({0})', [span(year(m.year - 1))]), year(m.year - 1)),
    (tr('Все'), null),
  ];
  final picked = await chooseOption<int>(context, tr('Експорт в Excel'), {for (final (i, o) in options.indexed) i: o.$1}, -1);
  if (picked == null) return;
  final r = options[picked].$2;
  try {
    final bytes = buildPfWorkbook(store, from: r?.start, to: r?.end);
    final n = store.txns.where((t) => r == null || (!t.date.isBefore(r.start) && t.date.isBefore(r.end))).length;
    final f = DateFormat('yyyy-MM-dd');
    final name = r == null
        ? 'PF-export-all-${f.format(DateTime.now())}'
        : 'PF-export-${f.format(r.start)}_${f.format(r.end.subtract(const Duration(days: 1)))}';
    await FileSaver.instance.saveFile(name: name, bytes: bytes, fileExtension: 'xlsx', mimeType: MimeType.microsoftExcel);
    messenger.showSnackBar(SnackBar(content: Text(tr('Excel збережено: {0} записів. Імпортуй його в PF кнопкою імпорту.', [n]))));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(tr('Не вдалося створити файл: {0}', [e]))));
  }
}
