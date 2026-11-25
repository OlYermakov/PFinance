import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_app/l10n/de.dart' as de;
import 'package:money_app/l10n/en.dart' as en;
import 'package:money_app/l10n/es.dart' as es;
import 'package:money_app/l10n/fr.dart' as fr;
import 'package:money_app/l10n/it.dart' as it;
import 'package:money_app/l10n/l10n.dart';
import 'package:money_app/l10n/pl.dart' as pl;

/// Every Ukrainian text passed to tr() in lib/, unescaped like Dart does.
Set<String> _keysInCode() {
  final re = RegExp(r"tr\('((?:\\.|[^'\\])*)'");
  final out = <String>{};
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart') || f.path.contains('l10n')) continue;
    for (final m in re.allMatches(f.readAsStringSync())) {
      out.add(m.group(1)!.replaceAll(r"\'", "'").replaceAll(r'\n', '\n'));
    }
  }
  return out;
}

void main() {
  final tables = {'en': en.t, 'de': de.t, 'pl': pl.t, 'es': es.t, 'fr': fr.t, 'it': it.t};

  test('every language translates every text of the interface', () {
    final keys = _keysInCode();
    expect(keys.length, greaterThan(500));
    for (final e in tables.entries) {
      final missing = keys.where((k) => !e.value.containsKey(k)).toList();
      expect(missing, isEmpty, reason: '${e.key} lacks translations');
    }
  });

  test('translations keep the placeholders', () {
    final ph = RegExp(r'\{\d\}');
    List<String> of(String s) => [for (final m in ph.allMatches(s)) m.group(0)!]..sort();
    for (final e in tables.entries) {
      for (final k in e.value.keys) {
        expect(of(e.value[k]!), of(k), reason: '${e.key}: $k');
      }
    }
  });

  test('tr fills in arguments and falls back to Ukrainian', () {
    lang = 'de';
    expect(tr('Ухвалено {0}', ['x']), 'Ухвалено x'); // no translation: Ukrainian
    expect(tr('Збережено записів: {0}', [3]), 'Gespeicherte Einträge: 3');
    lang = 'uk';
    expect(tr('Збережено записів: {0}', [3]), 'Збережено записів: 3');
  });

  test('device locale picks the language', () {
    expect(languageFor('de-AT'), 'de');
    expect(languageFor('pl_PL'), 'pl');
    expect(languageFor('uk'), 'uk');
    expect(languageFor('ja-JP'), 'en');
  });
}
