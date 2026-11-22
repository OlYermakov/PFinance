import 'dart:typed_data';

import 'share_file_stub.dart' if (dart.library.js_interop) 'share_file_web.dart' as impl;

/// Opens the system share sheet with a file (iPhone: "Save to Files" for
/// iCloud Drive, Mail, Messages…). Returns false when the browser can't
/// share files, so the caller can fall back to a download.
Future<bool> shareFile(Uint8List bytes, String name, String mime) => impl.shareFile(bytes, name, mime);
