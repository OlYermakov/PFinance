import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../state/app_store.dart';

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
  CellValue? eur(int minor, String cur) {
    if (cur == 'EUR') return DoubleCellValue(major(minor, cur));
    if (store.baseCurrency == 'EUR' && store.prefs.rates.containsKey(cur)) {
      return DoubleCellValue(store.toBase(minor, cur) / 100);
    }
    return null;
  }

  void row(DateTime d, String acc, String cat, String sub, String note, String type, int minor, String cur) {
    final amount = DoubleCellValue(major(minor, cur));
    sheet.appendRow([
      TextCellValue(df.format(d)),
      TextCellValue(acc),
      TextCellValue(cat),
      TextCellValue(sub),
      TextCellValue(note),
      eur(minor, cur),
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
        row(t.date, acc?.name ?? '', top?.name ?? '', sub, t.note, t.type == TxType.income ? 'Income' : 'Exp.', t.amount, cur);
      case TxType.transfer:
        final dst = store.account(t.toAccountId);
        row(t.date, acc?.name ?? '', dst?.name ?? '', '', t.note, 'Transfer-Out', t.amount, cur);
        row(t.date, dst?.name ?? '', acc?.name ?? '', '', t.note, 'Transfer-In', t.toAmount ?? t.amount, dst?.currency ?? cur);
    }
  }
  return Uint8List.fromList(excel.encode()!);
}

Future<void> exportForPf(BuildContext context) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = buildPfWorkbook(store);
    final d = DateTime.now();
    await FileSaver.instance.saveFile(
      name: 'PF-export-${DateFormat('yyyy-MM-dd').format(d)}',
      bytes: bytes,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
    messenger.showSnackBar(SnackBar(content: Text('Excel збережено: ${store.txns.length} записів. Імпортуй його в PF кнопкою імпорту.')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Не вдалося створити файл: $e')));
  }
}
