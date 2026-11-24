import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

bool get isStandalone {
  if (web.window.matchMedia('(display-mode: standalone)').matches) return true;
  // iOS Safari: navigator.standalone
  final s = (web.window.navigator as JSObject).getProperty<JSAny?>('standalone'.toJS);
  return s != null && s.isA<JSBoolean>() && (s as JSBoolean).toDart;
}

bool get isIos {
  final ua = web.window.navigator.userAgent;
  if (RegExp('iPhone|iPad|iPod').hasMatch(ua)) return true;
  // iPadOS reports itself as a Mac with touch.
  return ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1;
}

Future<bool?> persistStorage() async {
  try {
    final storage = web.window.navigator.storage;
    if ((await storage.persisted().toDart).toDart) return true;
    return (await storage.persist().toDart).toDart;
  } catch (_) {
    return null;
  }
}
