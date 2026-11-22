// Minimal read-only SQLite 3 reader in pure Dart (works on the web).
//
// Reads table b-trees (with overflow pages) and decodes records, which is
// all an import of another app's backup needs. No indexes, WAL or writes.

import 'dart:convert';
import 'dart:typed_data';

class SqliteReader {
  SqliteReader(this.bytes) : _bd = ByteData.sublistView(bytes) {
    if (bytes.length < 100 || ascii.decode(bytes.sublist(0, 15), allowInvalid: true) != 'SQLite format 3') {
      throw const FormatException('Це не база SQLite');
    }
    final ps = _bd.getUint16(16);
    pageSize = ps == 1 ? 65536 : ps;
    usable = pageSize - bytes[20];
    final enc = _bd.getUint32(56);
    if (enc > 1) throw const FormatException('Підтримується лише UTF-8');
    _tables = {
      for (final r in _scan(1))
        if (r[0] == 'table' && r[3] is num) (r[1] as String): (root: (r[3] as num).toInt(), sql: r[4] as String? ?? ''),
    };
  }

  final Uint8List bytes;
  final ByteData _bd;
  late final int pageSize;
  late final int usable;
  late final Map<String, ({int root, String sql})> _tables;

  Iterable<String> get tableNames => _tables.keys;
  bool hasTable(String name) => _tables.containsKey(name);

  /// Column names in declaration order, parsed from the CREATE TABLE text.
  List<String> columns(String table) {
    final sql = _tables[table]?.sql ?? '';
    final open = sql.indexOf('('), close = sql.lastIndexOf(')');
    if (open < 0 || close < open) return const [];
    final body = sql.substring(open + 1, close);
    final parts = <String>[];
    var depth = 0, start = 0;
    for (var i = 0; i < body.length; i++) {
      final ch = body[i];
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      if (ch == ',' && depth == 0) {
        parts.add(body.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(body.substring(start));
    final out = <String>[];
    for (final p in parts) {
      final t = p.trim();
      if (t.isEmpty) continue;
      final first = t.split(RegExp(r'\s+')).first.replaceAll(RegExp('["`\\[\\]]'), '');
      final upper = first.toUpperCase();
      if (const {'PRIMARY', 'UNIQUE', 'CHECK', 'FOREIGN', 'CONSTRAINT'}.contains(upper)) continue;
      out.add(first);
    }
    return out;
  }

  /// All rows of [table] as maps column → value (int, double, String,
  /// Uint8List or null). An INTEGER PRIMARY KEY column gets the rowid.
  List<Map<String, Object?>> rows(String table) {
    final t = _tables[table];
    if (t == null) return const [];
    final cols = columns(table);
    final pkCol = RegExp(r'(\w+)\s+INTEGER\s+PRIMARY\s+KEY', caseSensitive: false).firstMatch(t.sql)?.group(1);
    final out = <Map<String, Object?>>[];
    for (final (rowid, vals) in _scanWithRowid(t.root)) {
      final m = <String, Object?>{};
      for (var i = 0; i < cols.length; i++) {
        m[cols[i]] = i < vals.length ? vals[i] : null;
      }
      if (pkCol != null && m[pkCol] == null) m[pkCol] = rowid;
      out.add(m);
    }
    return out;
  }

  // ---- B-tree -------------------------------------------------------------

  Iterable<List<Object?>> _scan(int root) => _scanWithRowid(root).map((e) => e.$2);

  Iterable<(int, List<Object?>)> _scanWithRowid(int root) sync* {
    final stack = <int>[root];
    final seen = <int>{};
    while (stack.isNotEmpty) {
      final page = stack.removeLast();
      if (!seen.add(page)) continue; // corrupted loop guard
      final base = (page - 1) * pageSize;
      final hdr = page == 1 ? 100 : 0;
      final type = bytes[base + hdr];
      final n = _bd.getUint16(base + hdr + 3);
      if (type == 0x05) {
        // interior table page: visit children left to right
        final right = _bd.getUint32(base + hdr + 8);
        final kids = <int>[];
        for (var i = 0; i < n; i++) {
          final ptr = _bd.getUint16(base + hdr + 12 + 2 * i);
          kids.add(_bd.getUint32(base + ptr));
        }
        kids.add(right);
        stack.addAll(kids.reversed);
      } else if (type == 0x0D) {
        for (var i = 0; i < n; i++) {
          var p = base + _bd.getUint16(base + hdr + 8 + 2 * i);
          final (size, l1) = _varint(p);
          p += l1;
          final (rowid, l2) = _varint(p);
          p += l2;
          yield (rowid, _record(_payload(p, size)));
        }
      } else {
        throw FormatException('Невідомий тип сторінки $type');
      }
    }
  }

  Uint8List _payload(int p, int size) {
    final x = usable - 35;
    if (size <= x) return Uint8List.sublistView(bytes, p, p + size);
    final m = ((usable - 12) * 32 ~/ 255) - 23;
    final k = m + ((size - m) % (usable - 4));
    final local = k <= x ? k : m;
    final out = BytesBuilder(copy: false)..add(Uint8List.sublistView(bytes, p, p + local));
    var next = _bd.getUint32(p + local);
    var left = size - local;
    while (left > 0 && next != 0) {
      final base = (next - 1) * pageSize;
      final take = left < usable - 4 ? left : usable - 4;
      out.add(Uint8List.sublistView(bytes, base + 4, base + 4 + take));
      left -= take;
      next = _bd.getUint32(base);
    }
    return out.takeBytes();
  }

  List<Object?> _record(Uint8List r) {
    final bd = ByteData.sublistView(r);
    var (hsize, l) = _varintIn(r, 0);
    var hp = l;
    var dp = hsize;
    final out = <Object?>[];
    while (hp < hsize) {
      final (st, sl) = _varintIn(r, hp);
      hp += sl;
      switch (st) {
        case 0:
          out.add(null);
        case >= 1 && <= 6:
          final n = const [0, 1, 2, 3, 4, 6, 8][st];
          out.add(_int(r, dp, n));
          dp += n;
        case 7:
          out.add(bd.getFloat64(dp));
          dp += 8;
        case 8:
          out.add(0);
        case 9:
          out.add(1);
        case >= 12:
          final n = (st - 12) ~/ 2;
          final slice = Uint8List.sublistView(r, dp, dp + n);
          out.add(st.isEven ? Uint8List.fromList(slice) : utf8.decode(slice, allowMalformed: true));
          dp += n;
        default:
          out.add(null);
      }
    }
    return out;
  }

  // Signed big-endian integer of n bytes; built from doubles so it also
  // works where 64-bit ints are not available (the web).
  static int _int(Uint8List b, int p, int n) {
    num v = 0;
    for (var i = 0; i < n; i++) {
      v = v * 256 + b[p + i];
    }
    if (n > 0 && b[p] >= 0x80) v -= _pow256(n);
    return v.toInt();
  }

  static num _pow256(int n) {
    num v = 1;
    for (var i = 0; i < n; i++) {
      v *= 256;
    }
    return v;
  }

  (int, int) _varint(int p) => _varintIn(bytes, p);

  static (int, int) _varintIn(Uint8List b, int p) {
    num v = 0;
    for (var i = 0; i < 8; i++) {
      final c = b[p + i];
      v = v * 128 + (c & 0x7f);
      if (c < 0x80) return (v.toInt(), i + 1);
    }
    v = v * 256 + b[p + 8];
    return (v.toInt(), 9);
  }
}
