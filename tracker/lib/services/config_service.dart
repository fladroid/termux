// lib/services/config_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/button_model.dart';
import 'translation_service.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  static const _configFile  = 'user_config.json';
  static const _langKey     = 'language';
  static const _labelsKey   = 'show_labels';
  static const _sizeKey     = 'size';
  static const _contrastKey = 'contrast';

  Map<String, dynamic>? _cache;
  final _tr = TranslationService();

  Future<Map<String, dynamic>> loadConfig() async {
    _cache ??= await _loadUserConfig() ?? await _loadDefaultConfig();
    return _cache!;
  }

  Future<Map<String, dynamic>> _loadDefaultConfig() async {
    final s = await rootBundle.loadString('assets/config/default_config.json');
    return jsonDecode(s) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> _loadUserConfig() async {
    try {
      final f = await _userConfigFile();
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  Future<void> initTranslations() async {
    final config = await loadConfig();
    final lang   = await getLanguage();
    final tr     = config['translations'] as Map<String, dynamic>? ?? {};
    _tr.init(tr, lang);
  }

  Future<void> resetToDefault() async {
    _cache = null;
    final f = await _userConfigFile();
    if (await f.exists()) await f.delete();
    final prefs = await SharedPreferences.getInstance();
    for (final k in [_langKey, _labelsKey, _sizeKey, _contrastKey]) {
      await prefs.remove(k);
    }
    await initTranslations();
  }

  Future<List<ButtonModel>> loadButtons() async {
    final config = await loadConfig();
    final list   = config['buttons'] as List<dynamic>;
    return list.map((b) => ButtonModel.fromJson(b as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, String>>> loadLanguages() async {
    final config = await loadConfig();
    final list   = config['languages'] as List<dynamic>? ?? [];
    return list.map((l) => Map<String, String>.from(l as Map)).toList();
  }

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_langKey)) return prefs.getString(_langKey)!;
    return (await loadConfig())['language'] as String? ?? 'en';
  }

  Future<void> setLanguage(String lang) async {
    final prefs  = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang);
    final config = await loadConfig();
    _tr.setLanguage(lang, config['translations'] as Map<String, dynamic>? ?? {});

    // Loguj promjenu settingsa
    // (db_service import bi napravio circular dependency pa logujemo iz home/settings)
  }

  Future<bool> getShowLabels() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_labelsKey)) return prefs.getBool(_labelsKey)!;
    final ui = (await loadConfig())['ui'] as Map<String, dynamic>?;
    return ui?['show_labels'] as bool? ?? true;
  }

  Future<void> setShowLabels(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_labelsKey, v);
  }

  Future<String> getSize() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_sizeKey)) return prefs.getString(_sizeKey)!;
    final ui = (await loadConfig())['ui'] as Map<String, dynamic>?;
    return ui?['size'] as String? ?? 'medium';
  }

  Future<void> setSize(String v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sizeKey, v);
  }

  Future<String> getContrast() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_contrastKey)) return prefs.getString(_contrastKey)!;
    final ui = (await loadConfig())['ui'] as Map<String, dynamic>?;
    return ui?['contrast'] as String? ?? 'normal';
  }

  Future<void> setContrast(String v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contrastKey, v);
  }

  Future<File> _userConfigFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_configFile');
  }
}
