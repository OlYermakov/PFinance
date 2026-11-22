// Daily exchange rates for a given day, from the free currency-api dataset
// (github.com/fawazahmed0/exchange-api, served by jsDelivr with a Cloudflare
// mirror). One file per day and base currency; data starts in March 2024.

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Rates of [day] against [base]: currency → value of 1 unit in [base].
/// Returns an empty map when the day has no data, null when offline.
Future<Map<String, double>?> fetchDailyRates(DateTime day, String base) async {
  final d = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  final b = base.toLowerCase();
  final urls = [
    'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@$d/v1/currencies/$b.min.json',
    'https://$d.currency-api.pages.dev/v1/currencies/$b.min.json',
  ];
  var notFound = 0;
  for (final u in urls) {
    try {
      final r = await http.get(Uri.parse(u)).timeout(const Duration(seconds: 15));
      if (r.statusCode == 404) {
        notFound++;
        continue;
      }
      if (r.statusCode != 200) continue;
      return parseDailyRates(jsonDecode(r.body), base);
    } catch (_) {
      // try the mirror
    }
  }
  return notFound == urls.length ? {} : null;
}

/// {"date": "...", "eur": {"uah": 48.1, ...}} → {"UAH": 1 / 48.1, ...}
Map<String, double> parseDailyRates(Object? json, String base) {
  final out = <String, double>{};
  if (json is! Map) return out;
  final m = json[base.toLowerCase()];
  if (m is! Map) return out;
  for (final e in m.entries) {
    final v = e.value;
    final code = (e.key as String).toUpperCase();
    if (v is num && v > 0 && code.length == 3) out[code] = 1 / v;
  }
  return out;
}
