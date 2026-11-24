// Home-screen app (PWA) and browser storage helpers. Web only; elsewhere the
// stub answers "installed" so no hints are shown.
import 'pwa_stub.dart' if (dart.library.js_interop) 'pwa_web.dart' as impl;

/// Running from the home screen (not in a browser tab).
bool get isStandalone => impl.isStandalone;

/// iPhone or iPad Safari: the only way to install is Share → «На початковий екран».
bool get isIos => impl.isIos;

/// Ask the browser not to clear this site's data under storage pressure.
/// Returns whether the data is now protected (null when unknown).
Future<bool?> persistStorage() => impl.persistStorage();
