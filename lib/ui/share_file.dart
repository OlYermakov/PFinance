import 'dart:typed_data';

import 'share_file_stub.dart' if (dart.library.js_interop) 'share_file_web.dart' as impl;

enum ShareResult { shared, cancelled, unsupported }

/// Opens the system share sheet with a file (iPhone: "Save to Files" for
/// iCloud Drive, Mail, Messages…). [ShareResult.unsupported] when the browser
/// can't share files, so the caller can fall back to a download.
Future<ShareResult> shareFileResult(Uint8List bytes, String name, String mime) => impl.shareFileResult(bytes, name, mime);

/// Same, true unless unsupported (a closed sheet counts as handled).
Future<bool> shareFile(Uint8List bytes, String name, String mime) async => await shareFileResult(bytes, name, mime) != ShareResult.unsupported;
