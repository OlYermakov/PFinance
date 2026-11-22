import 'package:sembast/sembast_memory.dart';

/// Used by tests.
Future<Database> openMemoryDatabase(String name) =>
    databaseFactoryMemory.openDatabase(name);
