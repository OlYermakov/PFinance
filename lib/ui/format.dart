import 'package:intl/intl.dart';

const locale = 'uk';

/// Global display option (Settings → decimals).
bool showDecimals = true;

/// Currency symbol in front of the number ("€ 1,00") instead of behind.
bool currencyFront = false;

const currencies = <String>[
  'UAH', 'USD', 'EUR', 'GBP', 'PLN', 'CHF', 'CZK', 'CAD', 'AUD', 'JPY', //
  'CNY', 'TRY', 'SEK', 'NOK', 'DKK', 'HUF', 'RON', 'GEL', 'KZT', 'ILS',
];

int decimalsOf(String currency) =>
    NumberFormat.currency(name: currency).decimalDigits ?? 2;

String money(int minor, String currency, {bool sign = false}) {
  final f = NumberFormat.currency(
    locale: locale,
    name: currency,
    symbol: NumberFormat.simpleCurrency(name: currency).currencySymbol,
  );
  final d = f.decimalDigits ?? 2;
  final v = minor / _pow10(d);
  if (!showDecimals) f.maximumFractionDigits = 0;
  if (!showDecimals) f.minimumFractionDigits = 0;
  var s = f.format(showDecimals ? v.abs() : v.abs().roundToDouble());
  if (currencyFront) {
    final sym = f.currencySymbol;
    s = '$sym ${s.replaceAll(sym, '').trim()}';
  }
  if (minor < 0) return '−$s';
  if (sign && minor > 0) return '+$s';
  return s;
}

/// Amount without the currency symbol ("1 006,87", "−26,00"), as MM shows
/// figures inside lists where the currency is obvious.
String formatPlainMoney(int minor, String currency) {
  final d = decimalsOf(currency);
  final f = NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: showDecimals ? d : 0);
  final s = f.format((minor / _pow10(d)).abs());
  return minor < 0 ? '−$s' : s;
}

/// Parses user input like "1 234,50" or "1234.5" into minor units.
int? parseMoney(String input, String currency) {
  final cleaned = input.replaceAll(RegExp(r'[\s ]'), '').replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final v = double.tryParse(cleaned);
  if (v == null || v < 0) return null;
  return (v * _pow10(decimalsOf(currency))).round();
}

String minorToInput(int minor, String currency) {
  final d = decimalsOf(currency);
  final v = minor / _pow10(d);
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(d);
}

int _pow10(int d) {
  var r = 1;
  for (var i = 0; i < d; i++) {
    r *= 10;
  }
  return r;
}

String monthTitle(DateTime m) {
  final s = DateFormat.yMMMM(locale).format(m);
  return s[0].toUpperCase() + s.substring(1);
}

String dayTitle(DateTime d) {
  final s = DateFormat('EEEE, d MMMM', locale).format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String shortDate(DateTime d) => DateFormat('d MMM y', locale).format(d);

String shortDayMonth(DateTime d) => DateFormat('d MMM', locale).format(d);

String weekdayShort(DateTime d) => DateFormat('EEE', locale).format(d);
