import 'package:web/web.dart' as web;

void applyAppIcon(int i) {
  String path(int size) => i == 0 ? (size == 180 ? 'icons/Icon-192.png' : 'icons/Icon-$size.png') : 'icons/alt/icon$i-$size.png';
  void setLink(String rel, String href) {
    final nodes = web.document.querySelectorAll('link[rel="$rel"]');
    if (nodes.length == 0) {
      final l = web.document.createElement('link') as web.HTMLLinkElement
        ..rel = rel
        ..href = href;
      web.document.head?.append(l);
      return;
    }
    for (var k = 0; k < nodes.length; k++) {
      (nodes.item(k) as web.HTMLLinkElement).href = href;
    }
  }

  setLink('icon', i == 0 ? 'favicon.png' : path(192));
  setLink('apple-touch-icon', path(180));
}

int? _lastPageColor;

void applyPageColor(int argb) {
  if (_lastPageColor == argb) return;
  _lastPageColor = argb;
  final hex = '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  final metas = web.document.querySelectorAll('meta[name="theme-color"]');
  for (var k = 0; k < metas.length; k++) {
    (metas.item(k) as web.Element).remove();
  }
  final m = web.document.createElement('meta') as web.HTMLMetaElement
    ..name = 'theme-color'
    ..content = hex;
  web.document.head?.append(m);
  web.document.documentElement?.setAttribute('style', 'background:$hex');
  web.document.body?.style.background = hex;
}
