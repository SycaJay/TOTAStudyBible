/// How text is loaded for a [BibleTranslation].
enum BibleEditionKind {
  /// Shipped JSON under `assets/bible/{id}/` (same shape as KJV).
  bundledLocal,

  /// Try bundled assets first; if missing and [BibleApiConfig.isConfigured], use API.Bible.
  bundledOrApi,

  /// API.Bible only (copyrighted / licensed — requires API key and ABS terms).
  apiOnly,
}

class BibleTranslation {
  const BibleTranslation({
    required this.id,
    required this.label,
    required this.kind,
    this.apiAbbreviation = '',
    this.apiNameHint,
  });

  final String id;
  final String label;
  final BibleEditionKind kind;

  /// Primary match against API.Bible `abbreviation` / `abbreviationLocal` (uppercased compare).
  final String apiAbbreviation;

  /// Fallback: first bible whose `name` contains this (lower case substring).
  final String? apiNameHint;

  bool get isBundledFirst =>
      kind == BibleEditionKind.bundledLocal ||
      kind == BibleEditionKind.bundledOrApi;
}

/// First ten: public-domain family (bundled JSON when present; else API when key set).
/// Next rows: API-only popular translations (need `API_BIBLE_KEY`).
const List<BibleTranslation> kAllBibleTranslations = [
  BibleTranslation(
    id: 'kjv',
    label: 'KJV (King James Version)',
    kind: BibleEditionKind.bundledLocal,
    apiAbbreviation: 'KJV',
  ),
  BibleTranslation(
    id: 'asv',
    label: 'ASV (American Standard Version, 1901)',
    kind: BibleEditionKind.bundledOrApi,
    apiAbbreviation: 'ASV',
    apiNameHint: 'american standard',
  ),
  BibleTranslation(
    id: 'darby',
    label: 'Darby Translation',
    kind: BibleEditionKind.bundledOrApi,
    apiAbbreviation: 'DBY',
    apiNameHint: 'darby',
  ),
  BibleTranslation(
    id: 'ylt',
    label: 'YLT (Young’s Literal Translation)',
    kind: BibleEditionKind.bundledOrApi,
    apiAbbreviation: 'YLT',
    apiNameHint: 'young',
  ),
  BibleTranslation(
    id: 'webster',
    label: 'Webster Bible',
    kind: BibleEditionKind.bundledOrApi,
    apiAbbreviation: 'WEBSTER',
    apiNameHint: 'webster',
  ),
  BibleTranslation(
    id: 'geneva1599',
    label: 'Geneva Bible (1599)',
    kind: BibleEditionKind.bundledOrApi,
    apiAbbreviation: 'GNV',
    apiNameHint: 'geneva',
  ),
  BibleTranslation(
    id: 'douay1895',
    label: 'Douay-Rheims (1899)',
    kind: BibleEditionKind.bundledOrApi,
    apiAbbreviation: 'DRA',
    apiNameHint: 'douay',
  ),
  BibleTranslation(
    id: 'rv1895',
    label: 'Revised Version (1895)',
    kind: BibleEditionKind.bundledOrApi,
    apiAbbreviation: 'RV',
    apiNameHint: 'revised version',
  ),
  BibleTranslation(
    id: 'web',
    label: 'WEB (World English Bible)',
    kind: BibleEditionKind.bundledOrApi,
    apiAbbreviation: 'WEB',
    apiNameHint: 'world english',
  ),
  BibleTranslation(
    id: 'wmb',
    label: 'WMB (World Messianic Bible)',
    kind: BibleEditionKind.bundledOrApi,
    apiAbbreviation: 'WMB',
    apiNameHint: 'messianic',
  ),
  BibleTranslation(
    id: 'niv',
    label: 'NIV (New International Version)',
    kind: BibleEditionKind.bundledOrApi,
    apiAbbreviation: 'NIV',
  ),
  BibleTranslation(
    id: 'nlt',
    label: 'NLT (New Living Translation)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'NLT',
  ),
  BibleTranslation(
    id: 'esv',
    label: 'ESV (English Standard Version)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'ESV',
  ),
  BibleTranslation(
    id: 'nkjv',
    label: 'NKJV (New King James Version)',
    kind: BibleEditionKind.bundledOrApi,
    apiAbbreviation: 'NKJV',
  ),
  BibleTranslation(
    id: 'csb',
    label: 'CSB (Christian Standard Bible)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'CSB',
  ),
  BibleTranslation(
    id: 'nasb',
    label: 'NASB (New American Standard Bible)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'NASB',
    apiNameHint: 'new american standard',
  ),
  BibleTranslation(
    id: 'amp',
    label: 'AMP (Amplified Bible)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'AMP',
    apiNameHint: 'amplified',
  ),
  BibleTranslation(
    id: 'msg',
    label: 'MSG (The Message)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'MSG',
  ),
  BibleTranslation(
    id: 'cev',
    label: 'CEV (Contemporary English Version)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'CEV',
    apiNameHint: 'contemporary english',
  ),
  BibleTranslation(
    id: 'net',
    label: 'NET Bible',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'NET',
  ),
  BibleTranslation(
    id: 'nrsv',
    label: 'NRSV (New Revised Standard Version)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'NRSV',
  ),
  BibleTranslation(
    id: 'nrsvue',
    label: 'NRSVue (Updated Edition)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'NRSVUE',
    apiNameHint: 'nrsvue',
  ),
  BibleTranslation(
    id: 'rsv',
    label: 'RSV (Revised Standard Version)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'RSV',
  ),
  BibleTranslation(
    id: 'gnb',
    label: 'GNB / GNT (Good News Bible)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'GNT',
    apiNameHint: 'good news',
  ),
  BibleTranslation(
    id: 'ncv',
    label: 'NCV (New Century Version)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'NCV',
  ),
  BibleTranslation(
    id: 'nirv',
    label: 'NIRV (New International Reader’s Version)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'NIRV',
  ),
  BibleTranslation(
    id: 'icb',
    label: 'ICB (International Children’s Bible)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'ICB',
  ),
  BibleTranslation(
    id: 'erv',
    label: 'ERV (Easy-to-Read Version)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'ERV',
    apiNameHint: 'easy-to-read',
  ),
  BibleTranslation(
    id: 'hcsb',
    label: 'HCSB (Holman Christian Standard Bible)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'HCSB',
  ),
  BibleTranslation(
    id: 'voice',
    label: 'The Voice',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'VOICE',
    apiNameHint: 'voice',
  ),
  BibleTranslation(
    id: 'leb',
    label: 'LEB (Lexham English Bible)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'LEB',
  ),
  BibleTranslation(
    id: 'nabre',
    label: 'NABRE (New American Bible Revised Edition)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'NABRE',
  ),
  BibleTranslation(
    id: 'njps',
    label: 'NJPS (Jewish Publication Society Tanakh)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'NJPS',
    apiNameHint: 'jewish publication',
  ),
  BibleTranslation(
    id: 'cjb',
    label: 'CJB (Complete Jewish Bible)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'CJB',
    apiNameHint: 'complete jewish',
  ),
  BibleTranslation(
    id: 'tlb',
    label: 'TLB (Living Bible)',
    kind: BibleEditionKind.apiOnly,
    apiAbbreviation: 'TLB',
    apiNameHint: 'living bible',
  ),
];

BibleTranslation? translationById(String id) {
  for (final t in kAllBibleTranslations) {
    if (t.id == id) return t;
  }
  return null;
}

bool translationNeedsApiKey(BibleTranslation t) =>
    t.kind == BibleEditionKind.apiOnly;

bool translationAvailableNow(BibleTranslation t, bool apiConfigured) {
  if (t.kind == BibleEditionKind.apiOnly) {
    return apiConfigured;
  }
  if (t.kind == BibleEditionKind.bundledLocal) {
    return true;
  }
  return true;
}
