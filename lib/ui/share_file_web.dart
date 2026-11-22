import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<bool> shareFile(Uint8List bytes, String name, String mime) async {
  final file = web.File([bytes.toJS].toJS, name, web.FilePropertyBag(type: mime));
  final data = web.ShareData(files: [file].toJS, title: name);
  try {
    if (!web.window.navigator.canShare(data)) return false;
    await web.window.navigator.share(data).toDart;
    return true;
  } catch (e) {
    // AbortError: the user closed the sheet; anything else: not supported.
    return e.toString().contains('AbortError');
  }
}
