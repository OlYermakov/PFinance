// Interface languages. The Ukrainian text in the code is the key; each other
// language has a table from that text to its translation. A text with no
// translation is shown in Ukrainian, so nothing is ever blank.

import 'de.dart' as de;
import 'en.dart' as en;
import 'es.dart' as es;
import 'fr.dart' as fr;
import 'it.dart' as it;
import 'pl.dart' as pl;

/// Language codes in the order of the picker, with their own names.
const languages = <String, String>{
  'uk': 'Українська',
  'en': 'English',
  'de': 'Deutsch',
  'pl': 'Polski',
  'es': 'Español',
  'fr': 'Français',
  'it': 'Italiano',
};

const _tables = <String, Map<String, String>>{
  'en': en.t,
  'de': de.t,
  'pl': pl.t,
  'es': es.t,
  'fr': fr.t,
  'it': it.t,
};

/// The current interface language (a key of [languages]).
String lang = 'uk';

/// The supported language for a device locale such as "de-AT"; English when
/// the device speaks none of them.
String languageFor(String deviceLocale) {
  final c = deviceLocale.split(RegExp('[-_]')).first.toLowerCase();
  return languages.containsKey(c) ? c : 'en';
}

/// [uk] in the current language. `{0}`, `{1}`… are replaced by [args].
String tr(String uk, [List<Object?> args = const []]) {
  var s = _tables[lang]?[uk] ?? uk;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}
