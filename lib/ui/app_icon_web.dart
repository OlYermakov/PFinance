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
