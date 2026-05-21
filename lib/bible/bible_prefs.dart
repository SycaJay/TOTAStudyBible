import 'package:shared_preferences/shared_preferences.dart';

const _kDefaultTranslationKey = 'bible_default_translation_id';

class BiblePrefs {
  BiblePrefs._();
  static final BiblePrefs instance = BiblePrefs._();

  Future<String> getDefaultTranslationId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kDefaultTranslationKey) ?? 'kjv';
  }

  Future<void> setDefaultTranslationId(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDefaultTranslationKey, id);
  }
}
