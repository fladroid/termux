// lib/services/config_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/button_model.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  static const String _configFileName = 'user_config.json';
  static const String _langKey = 'language';
  static const String _showLabelsKey = 'show_labels';

  Future<Map<String, dynamic>> loadConfig() async {
    final userConfig = await _loadUserConfig();
    if (userConfig != null) return userConfig;
    return await _loadDefaultConfig();
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
      final jsonString = await file.readAsString();
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConfig(Map<String, dynamic> config) async {
    final file = await _configFile();
    await file.writeAsString(jsonEncode(config));
  }

  Future<void> resetToDefault() async {
    final file = await _configFile();
    if (await file.exists()) await file.delete();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_langKey);
    await prefs.remove(_showLabelsKey);
  }

  Future<List<ButtonModel>> loadButtons() async {
    final config = await loadConfig();
    final list = config['buttons'] as List<dynamic>;
    return list.map((b) => ButtonModel.fromJson(b as Map<String, dynamic>)).toList();
  }

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_langKey)) return prefs.getString(_langKey)!;
    final config = await loadConfig();
    return config['language'] as String? ?? 'en';
  }

  Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang);
  }

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

  Future<File> _configFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_configFileName');
  }
}
