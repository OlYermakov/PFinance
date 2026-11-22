// Core data model.
//
// Every entity carries `id`, `updatedAt` and `deleted` so that a future sync
// layer can merge changes between devices (last-writer-wins per record,
// deletions kept as tombstones). Amounts are stored as integers in minor
// units (cents/kopiyky) to avoid floating-point errors.

import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v7();

enum TxType { expense, income, transfer }

enum AccountKind { cash, card, bank, savings, credit, investment, other }

abstract class Entity {
  String get id;
  DateTime get updatedAt;
  bool get deleted;
  Map<String, Object?> toJson();
}

DateTime _date(Object? v) =>
    v is int ? DateTime.fromMillisecondsSinceEpoch(v) : DateTime.now();

class Account implements Entity {
  @override
  final String id;
  final String name;
  final AccountKind kind;
  final String currency; // ISO 4217
  final int initialBalance; // minor units
  final int color; // ARGB
  final int sort;
  final bool archived;
  final bool includeInTotal;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  Account({
    String? id,
    required this.name,
    this.kind = AccountKind.card,
    required this.currency,
    this.initialBalance = 0,
    this.color = 0xFF4F7CFF,
    this.sort = 0,
    this.archived = false,
    this.includeInTotal = true,
    this.group,
    this.settleDay,
    this.payDay,
    this.payFrom,
    DateTime? updatedAt,
    this.deleted = false,
  })  : id = id ?? newId(),
        updatedAt = updatedAt ?? DateTime.now();

  /// User-named account group ("Банк", "Гаманець"…); null = by kind.
  final String? group;

  /// Card billing cycle (MM "Card"): the day the statement closes, the day it
  /// is paid, and the account it is paid from. Null for non-card accounts.
  final int? settleDay;
  final int? payDay;
  final String? payFrom;
  bool get isCard => settleDay != null;

  Account copyWith({
    String? group,
    String? name,
    AccountKind? kind,
    String? currency,
    int? initialBalance,
    int? color,
    int? sort,
    bool? archived,
    bool? includeInTotal,
    bool? deleted,
    (int?, int?, String?)? card, // (settleDay, payDay, payFrom); (null,null,null) clears
  }) =>
      Account(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        currency: currency ?? this.currency,
        initialBalance: initialBalance ?? this.initialBalance,
        color: color ?? this.color,
        sort: sort ?? this.sort,
        archived: archived ?? this.archived,
        includeInTotal: includeInTotal ?? this.includeInTotal,
        group: group ?? this.group,
        settleDay: card != null ? card.$1 : settleDay,
        payDay: card != null ? card.$2 : payDay,
        payFrom: card != null ? card.$3 : payFrom,
        deleted: deleted ?? this.deleted,
      );

  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'currency': currency,
        'initialBalance': initialBalance,
        'color': color,
        'sort': sort,
        'archived': archived,
        'includeInTotal': includeInTotal,
        'group': group,
        if (settleDay != null) 'settleDay': settleDay,
        if (payDay != null) 'payDay': payDay,
        if (payFrom != null) 'payFrom': payFrom,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
      };

  factory Account.fromJson(Map<String, Object?> j) => Account(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        kind: AccountKind.values.asNameMap()[j['kind']] ?? AccountKind.other,
        currency: j['currency'] as String? ?? 'USD',
        initialBalance: (j['initialBalance'] as num?)?.toInt() ?? 0,
        color: (j['color'] as num?)?.toInt() ?? 0xFF4F7CFF,
        sort: (j['sort'] as num?)?.toInt() ?? 0,
        archived: j['archived'] as bool? ?? false,
        includeInTotal: j['includeInTotal'] as bool? ?? true,
        group: j['group'] as String?,
        settleDay: (j['settleDay'] as num?)?.toInt(),
        payDay: (j['payDay'] as num?)?.toInt(),
        payFrom: j['payFrom'] as String?,
        updatedAt: _date(j['updatedAt']),
        deleted: j['deleted'] as bool? ?? false,
      );
}

class Category implements Entity {
  @override
  final String id;
  final String name;
  final TxType type; // expense or income
  final String? parentId; // sub-categories
  final String emoji;
  final int color;
  final int sort;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  Category({
    String? id,
    required this.name,
    required this.type,
    this.parentId,
    this.emoji = '',
    this.color = 0xFF8E8E93,
    this.sort = 0,
    DateTime? updatedAt,
    this.deleted = false,
  })  : id = id ?? newId(),
        updatedAt = updatedAt ?? DateTime.now();

  Category copyWith({
    String? name,
    String? emoji,
    int? color,
    int? sort,
    bool? deleted,
  }) =>
      Category(
        id: id,
        name: name ?? this.name,
        type: type,
        parentId: parentId,
        emoji: emoji ?? this.emoji,
        color: color ?? this.color,
        sort: sort ?? this.sort,
        deleted: deleted ?? this.deleted,
      );

  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'parentId': parentId,
        'emoji': emoji,
        'color': color,
        'sort': sort,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
      };

  factory Category.fromJson(Map<String, Object?> j) => Category(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        type: TxType.values.asNameMap()[j['type']] ?? TxType.expense,
        parentId: j['parentId'] as String?,
        emoji: j['emoji'] as String? ?? '',
        color: (j['color'] as num?)?.toInt() ?? 0xFF8E8E93,
        sort: (j['sort'] as num?)?.toInt() ?? 0,
        updatedAt: _date(j['updatedAt']),
        deleted: j['deleted'] as bool? ?? false,
      );
}

class Txn implements Entity {
  @override
  final String id;
  final TxType type;
  final int amount; // minor units, always positive
  final String accountId;
  final String? toAccountId; // transfers only
  final int? toAmount; // transfers between currencies
  final String? categoryId; // null for transfers
  final DateTime date;
  final String note;

  /// Value in the base currency at the rate of the record's day ([atBaseCur]
  /// names that base). Null until the rate is known; then current rates apply.
  final int? atBase;
  final String? atBaseCur;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  Txn({
    String? id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.toAmount,
    this.categoryId,
    required this.date,
    this.note = '',
    this.atBase,
    this.atBaseCur,
    DateTime? updatedAt,
    this.deleted = false,
  })  : id = id ?? newId(),
        updatedAt = updatedAt ?? DateTime.now();

  Txn withBase(int? value, String? currency) => Txn(
        id: id,
        type: type,
        amount: amount,
        accountId: accountId,
        toAccountId: toAccountId,
        toAmount: toAmount,
        categoryId: categoryId,
        date: date,
        note: note,
        atBase: value,
        atBaseCur: currency,
        deleted: deleted,
      );

  Txn copyWith({bool? deleted}) => Txn(
        id: id,
        type: type,
        amount: amount,
        accountId: accountId,
        toAccountId: toAccountId,
        toAmount: toAmount,
        categoryId: categoryId,
        date: date,
        note: note,
        atBase: atBase,
        atBaseCur: atBaseCur,
        deleted: deleted ?? this.deleted,
      );

  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'accountId': accountId,
        'toAccountId': toAccountId,
        'toAmount': toAmount,
        'categoryId': categoryId,
        'date': date.millisecondsSinceEpoch,
        'note': note,
        if (atBase != null) 'atBase': atBase,
        if (atBaseCur != null) 'atBaseCur': atBaseCur,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
      };

  factory Txn.fromJson(Map<String, Object?> j) => Txn(
        id: j['id'] as String,
        type: TxType.values.asNameMap()[j['type']] ?? TxType.expense,
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        accountId: j['accountId'] as String? ?? '',
        toAccountId: j['toAccountId'] as String?,
        toAmount: (j['toAmount'] as num?)?.toInt(),
        categoryId: j['categoryId'] as String?,
        date: _date(j['date']),
        note: j['note'] as String? ?? '',
        atBase: (j['atBase'] as num?)?.toInt(),
        atBaseCur: j['atBaseCur'] as String?,
        updatedAt: _date(j['updatedAt']),
        deleted: j['deleted'] as bool? ?? false,
      );
}

/// Monthly spending limit for a category (or overall when categoryId is null).
class Budget implements Entity {
  @override
  final String id;
  final String? categoryId;
  final int amount; // minor units per month
  final String currency;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  Budget({
    String? id,
    this.categoryId,
    required this.amount,
    required this.currency,
    DateTime? updatedAt,
    this.deleted = false,
  })  : id = id ?? newId(),
        updatedAt = updatedAt ?? DateTime.now();

  Budget copyWith({int? amount, bool? deleted}) => Budget(
        id: id,
        categoryId: categoryId,
        amount: amount ?? this.amount,
        currency: currency,
        deleted: deleted ?? this.deleted,
      );

  @override
  Map<String, Object?> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'amount': amount,
        'currency': currency,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
      };

  factory Budget.fromJson(Map<String, Object?> j) => Budget(
        id: j['id'] as String,
        categoryId: j['categoryId'] as String?,
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        currency: j['currency'] as String? ?? 'USD',
        updatedAt: _date(j['updatedAt']),
        deleted: j['deleted'] as bool? ?? false,
      );
}

enum RepeatEvery { day, week, twoWeeks, fourWeeks, month, quarter, year }

/// A repeating record (Money Manager's "Repeat Setting"). Stored in the
/// settings store, so it travels with backups. Due copies are created as
/// ordinary transactions when the app opens.
class RepeatRule {
  RepeatRule({String? id, required this.template, required this.every, required this.start, this.end, this.lastDone})
      : id = id ?? newId();

  final String id;
  final Txn template; // date is ignored; the time of day is kept
  final RepeatEvery every;
  final DateTime start;
  final DateTime? end;
  final DateTime? lastDone;

  RepeatRule copyWith({Txn? template, RepeatEvery? every, DateTime? start, DateTime? end, bool clearEnd = false, DateTime? lastDone}) => RepeatRule(
        id: id,
        template: template ?? this.template,
        every: every ?? this.every,
        start: start ?? this.start,
        end: clearEnd ? null : (end ?? this.end),
        lastDone: lastDone ?? this.lastDone,
      );

  /// The n-th occurrence (n = 0 is [start]). Month/year steps keep the day of
  /// month, clamped to the month's length (31 → 30/28).
  DateTime occurrence(int n) {
    final s = start;
    DateTime clamp(int y, int m) {
      final last = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, s.day > last ? last : s.day, s.hour, s.minute);
    }

    return switch (every) {
      RepeatEvery.day => DateTime(s.year, s.month, s.day + n, s.hour, s.minute),
      RepeatEvery.week => DateTime(s.year, s.month, s.day + 7 * n, s.hour, s.minute),
      RepeatEvery.twoWeeks => DateTime(s.year, s.month, s.day + 14 * n, s.hour, s.minute),
      RepeatEvery.fourWeeks => DateTime(s.year, s.month, s.day + 28 * n, s.hour, s.minute),
      RepeatEvery.month => clamp(s.year, s.month + n),
      RepeatEvery.quarter => clamp(s.year, s.month + 3 * n),
      RepeatEvery.year => clamp(s.year + n, s.month),
    };
  }

  /// Occurrences after [lastDone] up to and including [now].
  List<DateTime> dueUntil(DateTime now) {
    final out = <DateTime>[];
    for (var n = 0; n < 5000; n++) {
      final d = occurrence(n);
      if (d.isAfter(now) || (end != null && d.isAfter(end!))) break;
      if (lastDone == null || d.isAfter(lastDone!)) out.add(d);
    }
    return out;
  }

  DateTime? nextAfter(DateTime now) {
    for (var n = 0; n < 5000; n++) {
      final d = occurrence(n);
      if (end != null && d.isAfter(end!)) return null;
      if (d.isAfter(now)) return d;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'template': template.toJson(),
        'every': every.name,
        'start': start.millisecondsSinceEpoch,
        'end': end?.millisecondsSinceEpoch,
        'lastDone': lastDone?.millisecondsSinceEpoch,
      };

  factory RepeatRule.fromJson(Map<String, Object?> j) => RepeatRule(
        id: j['id'] as String,
        template: Txn.fromJson(Map<String, Object?>.from(j['template'] as Map)),
        every: RepeatEvery.values.asNameMap()[j['every']] ?? RepeatEvery.month,
        start: _date(j['start']),
        end: j['end'] == null ? null : _date(j['end']),
        lastDone: j['lastDone'] == null ? null : _date(j['lastDone']),
      );
}
