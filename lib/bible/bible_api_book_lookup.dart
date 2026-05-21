/// Normalizes Bible book titles for matching API.Bible `name` / `nameLong`.
String normBibleBookTitle(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// Fills [cache]: norm(title) → API book id, using both `name` and `nameLong`.
void fillBibleBookIdCacheFromRows(
  Map<String, String> cache,
  List<dynamic> rows,
) {
  void put(String? raw, String id) {
    if (raw == null || raw.isEmpty) return;
    final n = normBibleBookTitle(raw);
    if (n.isNotEmpty) cache[n] = id;
    if (n.endsWith('.')) {
      cache[normBibleBookTitle(n.replaceAll(RegExp(r'\.\s*$'), ''))] = id;
    }
  }

  for (final row in rows) {
    final m = row as Map<String, dynamic>;
    final id = m['id'] as String? ?? '';
    if (id.isEmpty) continue;
    put(m['name'] as String?, id);
    put(m['nameLong'] as String?, id);
  }

  // Arabic 1/2/3 ↔ Roman I/II/III (NKJV etc.)
  for (final e in Map<String, String>.from(cache).entries.toList()) {
    final k = e.key;
    final id = e.value;
    if (k.startsWith('i ') && !k.startsWith('ii ')) {
      cache['1 ${k.substring(2)}'] = id;
    } else if (k.startsWith('ii ') && !k.startsWith('iii ')) {
      cache['2 ${k.substring(3)}'] = id;
    } else if (k.startsWith('iii ')) {
      cache['3 ${k.substring(4)}'] = id;
    }
  }
  for (final e in Map<String, String>.from(cache).entries.toList()) {
    final k = e.key;
    final id = e.value;
    if (k.startsWith('1 ')) {
      cache['i ${k.substring(2)}'] = id;
    } else if (k.startsWith('2 ')) {
      cache['ii ${k.substring(2)}'] = id;
    } else if (k.startsWith('3 ')) {
      cache['iii ${k.substring(2)}'] = id;
    }
  }

  void aliasIf(String a, String b) {
    final idA = cache[a];
    final idB = cache[b];
    if (idA != null && !cache.containsKey(b)) cache[b] = idA;
    if (idB != null && !cache.containsKey(a)) cache[a] = idB;
  }

  aliasIf('song of solomon', 'song of songs');
  aliasIf('psalms', 'psalm');
  aliasIf('revelation', 'revelations');
}

String? lookupBibleBookId(Map<String, String> cache, String displayName) {
  final primary = normBibleBookTitle(displayName);
  if (cache.containsKey(primary)) return cache[primary];
  return null;
}
