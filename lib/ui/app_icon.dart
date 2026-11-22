import 'app_icon_stub.dart' if (dart.library.js_interop) 'app_icon_web.dart' as impl;

/// Alternative app icons (MM "Application Icon"). Index 0 is the default PF icon.
const appIconCount = 6;

String appIconAsset(int i) => 'assets/images/app_icons/icon$i.png';

/// Points the page's favicon, home-screen icon and manifest at icon [i].
/// A phone keeps the icon it had when the page was added to the home screen,
/// so a new choice shows after re-adding it.
void applyAppIcon(int i) => impl.applyAppIcon(i);
