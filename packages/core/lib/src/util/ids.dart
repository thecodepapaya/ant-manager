import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

final _rand = Random.secure();
const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// ULID: time-sortable unique id.
String newId([DateTime? at]) {
  var ms = (at ?? DateTime.now()).millisecondsSinceEpoch;
  final time = List.filled(10, '0');
  for (var i = 9; i >= 0; i--) {
    time[i] = _alphabet[ms % 32];
    ms ~/= 32;
  }
  final rand = List.generate(16, (_) => _alphabet[_rand.nextInt(32)]);
  return time.join() + rand.join();
}

/// Canonical JSON: sorted keys, so equal content always hashes equally (LLD 04 §4.1).
String canonicalJson(Object? value) => jsonEncode(_sort(value));

Object? _sort(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _sort(v[k])};
  }
  if (v is List) return v.map(_sort).toList();
  return v;
}

String sha256Hex(String s) => sha256.convert(utf8.encode(s)).toString();

/// YYYY-MM-DD of [t] shifted by [utcOffset] (profile time zone offset, #87).
String dayOf(DateTime t, Duration utcOffset) {
  final l = t.toUtc().add(utcOffset);
  return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}
