import 'dart:typed_data';

import 'share_file.dart' show ShareResult;

Future<ShareResult> shareFileResult(Uint8List bytes, String name, String mime) async => ShareResult.unsupported;
