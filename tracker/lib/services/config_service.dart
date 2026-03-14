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

  static const String _configFileName = 'user_config.json';
  static const String _langKey = 'language';
  static const String _showLabelsKey = 'show_labels';
  static const String _sizeKey = 'size';
  static const String _contrastKey = 'contrast';

  Map<String, dynamic>? _cachedConfig;
  final _tr = TranslationService();

  Future<Map<String, dynamic>> loadConfig() async {
    if (_cachedConfig != null) return _cachedConfig!;
    final userConfig = await _loadUserConfig();
    _cachedConfig = userConfig ?? await _loadDefaultConfig();
    return _cachedConfig!;
  }

  Future<Map<String, dynamic>> _loadDefaultConfig() async {
    final jsonString = await rootBundle.loadString(
      'assets/config/default_config.json',
    );
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> _loadUserConfig() async {
    try {
      final file = await _configFile();
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConfig(Map<String, dynamic> config) async {
    _cachedConfig = config;
    final file = await _configFile();
    await file.writeAsString(jsonEncode(config));
  }

  Future<void> resetToDefault() async {
    _cachedConfig = null;
    final file = await _configFile();
    if (await file.exists()) await file.delete();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_langKey);
    await prefs.remove(_showLabelsKey);
    await prefs.remove(_sizeKey);
    await prefs.remove(_contrastKey);
  }

  // Inicijalizira TranslationService — pozvati pri startu app
  Future<void> initTranslations() async {
    final config = await loadConfig();
    final lang = await getLanguage();
    final translations = config['translations'] as Map<String, dynamic>? ?? {};
    _tr.init(translations, lang);
  }

  Future<List<ButtonModel>> loadButtons() async {
    final config = await loadConfig();
    final list = config['buttons'] as List<dynamic>;
    return list.map((b) => ButtonModel.fromJson(b as Map<String, dynamic>)).toList();
  }

  // Lista dostupnih jezika iz config JSONa
  Future<List<Map<String, String>>> loadLanguages() async {
    final config = await loadConfig();
    final list = config['languages'] as List<dynamic>? ?? [];
    return list.map((l) => Map<String, String>.from(l as Map)).toList();
  }

  // Jezik
  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_langKey)) return prefs.getString(_langKey)!;
    final config = await loadConfig();
    return config['language'] as String? ?? 'en';
  }

  Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang);
    final config = await loadConfig();
    final translations = config['translations'] as Map<String, dynamic>? ?? {};
    _tr.setLanguage(lang, translations);
  }

  // Show labels
  Future<bool> getShowLabels() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_showLabelsKey)) return prefs.getBool(_showLabelsKey)!;
    final config = await loadConfig();
    final ui = config['ui'] as Map<String, dynamic>?;
    return ui?['show_labels'] as bool? ?? true;
  }

  Future<void> setShowLabels(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showLabelsKey, value);
  }

  // Veličina: small | medium | large
  Future<String> getSize() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_sizeKey)) return prefs.getString(_sizeKey)!;
    final config = await loadConfig();
    final ui = config['ui'] as Map<String, dynamic>?;
    return ui?['size'] as String? ?? 'medium';
  }

  Future<void> setSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sizeKey, size);
  }

  // Kontrast: normal | high
  Future<String> getContrast() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_contrastKey)) return prefs.getString(_contrastKey)!;
    final config = await loadConfig();
    final ui = config['ui'] as Map<String, dynamic>?;
    return ui?['contrast'] as String? ?? 'normal';
  }

  Future<void> setContrast(String contrast) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_contrastKey, contrast);
  }

  Future<File> _configFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_configFileName');
  }
}
