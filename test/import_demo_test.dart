@Tags(['manual'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_app/data/db_factory_memory.dart';
import 'package:money_app/data/models.dart';
import 'package:money_app/data/repository.dart';
import 'package:money_app/state/app_store.dart';

void main() {
  test('import demo', () async {
    final s = AppStore(Repository(await openMemoryDatabase(newId())));
    await s.load();
    await s.importJson(File(Platform.environment['IN']!).readAsStringSync());
    print('txns ${s.txns.length} accounts ${s.accounts.length}');
  });
}
