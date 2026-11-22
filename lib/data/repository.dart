import 'package:sembast/sembast.dart';

import 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';
import 'models.dart';

/// Local persistence. All records live in sembast stores keyed by id.
/// Deletions are soft (tombstones) so a future sync can propagate them.
class Repository {
  Repository(this.db);

  final Database db;

  static Future<Repository> open() async =>
      Repository(await openAppDatabase('money_app.db'));

  final accounts = stringMapStoreFactory.store('accounts');
  final categories = stringMapStoreFactory.store('categories');
  final txns = stringMapStoreFactory.store('transactions');
  final budgets = stringMapStoreFactory.store('budgets');
  final settings = StoreRef<String, Object?>('settings');

  Future<List<T>> _all<T>(
    StoreRef<String, Map<String, Object?>> store,
    T Function(Map<String, Object?>) parse,
  ) async {
    final recs = await store.find(db);
    return recs.map((r) => parse(r.value)).toList();
  }

  Future<List<Account>> loadAccounts() => _all(accounts, Account.fromJson);
  Future<List<Category>> loadCategories() =>
      _all(categories, Category.fromJson);
  Future<List<Txn>> loadTxns() => _all(txns, Txn.fromJson);
  Future<List<Budget>> loadBudgets() => _all(budgets, Budget.fromJson);

  Future<void> put(Entity e) {
    final store = switch (e) {
      Account() => accounts,
      Category() => categories,
      Txn() => txns,
      Budget() => budgets,
      _ => throw ArgumentError('Unknown entity ${e.runtimeType}'),
    };
    return store.record(e.id).put(db, e.toJson());
  }

  Future<Object?> getSetting(String key) => settings.record(key).get(db);
  Future<void> setSetting(String key, Object? value) =>
      settings.record(key).put(db, value);

  /// Full snapshot for backup/export.
  Future<Map<String, Object?>> exportAll() async => {
        'format': 'money_app_backup',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'accounts': (await accounts.find(db)).map((r) => r.value).toList(),
        'categories': (await categories.find(db)).map((r) => r.value).toList(),
        'transactions': (await txns.find(db)).map((r) => r.value).toList(),
        'budgets': (await budgets.find(db)).map((r) => r.value).toList(),
        'settings': {
          for (final r in await settings.find(db)) r.key: r.value,
        },
      };

  /// Replaces all data with a backup snapshot.
  Future<void> importAll(Map<String, Object?> data) async {
    if (data['format'] != 'money_app_backup') {
      throw const FormatException('Not a backup file');
    }
    // Deep-copy into plain Dart maps and lists (jsonDecode on the web returns
    // lazily converted JS-backed maps for nested values).
    List<Map<String, Object?>> list(String k) => [
          for (final e in (data[k] as List? ?? const [])) _plain(e) as Map<String, Object?>,
        ];
    await db.transaction((t) async {
      for (final s in [accounts, categories, txns, budgets]) {
        await s.delete(t);
      }
      await settings.delete(t);
      for (final (store, key) in [
        (accounts, 'accounts'),
        (categories, 'categories'),
        (txns, 'transactions'),
        (budgets, 'budgets'),
      ]) {
        for (final j in list(key)) {
          await store.record(j['id'] as String).put(t, j);
        }
      }
      final s = data['settings'];
      if (s is Map) {
        for (final e in s.entries) {
          await settings.record(e.key as String).put(t, _plain(e.value));
        }
      }
    });
  }

  Future<void> wipe() async {
    await db.transaction((t) async {
      for (final s in [accounts, categories, txns, budgets]) {
        await s.delete(t);
      }
      await settings.delete(t);
    });
  }
}

Object? _plain(Object? v) => switch (v) {
      Map() => <String, Object?>{for (final e in v.entries) e.key as String: _plain(e.value)},
      List() => [for (final e in v) _plain(e)],
      _ => v,
    };
