// lib/services/translation_service.dart

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  Map<String, dynamic> _translations = {};
  String _language = 'en';

  void init(Map<String, dynamic> allTranslations, String language) {
    _language = language;
    _translations = allTranslations[language] as Map<String, dynamic>? ?? {};
  }

  void setLanguage(String language, Map<String, dynamic> allTranslations) {
    _language = language;
    _translations = allTranslations[language] as Map<String, dynamic>? ?? {};
  }

  String t(String key, {Map<String, String>? params}) {
    String text = _translations[key] as String? ?? key;
    if (params != null) {
      params.forEach((k, v) => text = text.replaceAll('{$k}', v));
    }
    return text;
  }

  List<String> tList(String key) {
    final list = _translations[key];
    if (list is List) return list.cast<String>();
    return [];
  }

  String dayName(int weekday) {
    final days = tList('days');
    if (days.isEmpty) return '';
    return days[(weekday - 1) % 7];
  }

  String monthName(int month) {
    final months = tList('months');
    if (months.isEmpty) return '';
    return months[(month - 1) % 12];
  }

  String formatDate(DateTime dt) {
    final day   = dayName(dt.weekday);
    final month = monthName(dt.month);
    return '$day, ${dt.day}. $month ${dt.year}.';
  }

  String formatHeaderMain(DateTime dt) {
    final now      = DateTime.now();
    final today    = DateTime(now.year, now.month, now.day);
    final selected = DateTime(dt.year, dt.month, dt.day);
    final diff     = selected.difference(today).inDays;
    if (diff ==  0) return t('today');
    if (diff == -1) return t('yesterday');
    if (diff ==  1) return t('tomorrow');
    return formatDate(dt);
  }

  bool isRelativeDay(DateTime dt) {
    final now  = DateTime.now();
    final diff = DateTime(dt.year, dt.month, dt.day)
        .difference(DateTime(now.year, now.month, now.day)).inDays;
    return diff >= -1 && diff <= 1;
  }

  String get language => _language;
}
