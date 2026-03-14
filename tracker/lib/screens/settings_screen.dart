// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import '../services/config_service.dart';
import '../services/export_service.dart';
import '../services/translation_service.dart';
import '../services/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _config = ConfigService();
  final _export = ExportService();
  final _tr = TranslationService();
  final _theme = AppTheme();

  String _language = 'en';
  bool _showLabels = true;
  String _size = 'medium';
  String _contrast = 'normal';
  bool _loading = true;
  List<Map<String, String>> _languages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final language = await _config.getLanguage();
    final showLabels = await _config.getShowLabels();
    final size = await _config.getSize();
    final contrast = await _config.getContrast();
    final languages = await _config.loadLanguages();
    setState(() {
      _language = language;
      _showLabels = showLabels;
      _size = size;
      _contrast = contrast;
      _languages = languages;
      _loading = false;
    });
  }

  Future<void> _setLanguage(String lang) async {
    await _config.setLanguage(lang);
    setState(() => _language = lang);
  }

  Future<void> _setShowLabels(bool value) async {
    await _config.setShowLabels(value);
    setState(() => _showLabels = value);
  }

  Future<void> _setSize(String size) async {
    await _config.setSize(size);
    _theme.setSize(size);
    setState(() => _size = size);
  }

  Future<void> _setContrast(String contrast) async {
    await _config.setContrast(contrast);
    _theme.setContrast(contrast);
    setState(() => _contrast = contrast);
  }

  Future<void> _resetToDefault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tr.t('reset_confirm_title')),
        content: Text(_tr.t('reset_confirm_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tr.t('reset_confirm_cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tr.t('reset_confirm_ok'))),
        ],
      ),
    );
    if (confirm == true) { await _config.resetToDefault(); await _load(); }
  }

  Future<void> _importJson() async {
    final result = await _export.importJson();
    if (!mounted || result.cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.success
        ? _tr.t('import_success', params: {
            'imported': '${result.imported}',
            'skipped': '${result.skipped}',
          })
        : _tr.t('import_error', params: {'error': result.errorMessage ?? ''})),
    ));
  }

  Future<void> _importCsv() async {
    final result = await _export.importCsv();
    if (!mounted || result.cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.success
        ? _tr.t('import_success', params: {
            'imported': '${result.imported}',
            'skipped': '${result.skipped}',
          })
        : _tr.t('import_error', params: {'error': result.errorMessage ?? ''})),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _loading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _theme.border)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text('‹', style: TextStyle(fontSize: 22, color: _theme.inkLight)),
        ),
        const SizedBox(width: 16),
        Text(_tr.t('settings_title'), style: TextStyle(
          fontFamily: 'monospace', fontSize: _theme.headerSize * 0.8,
          fontWeight: FontWeight.w600, color: _theme.ink)),
      ]),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          _sectionLabel(_tr.t('settings_display')),
          _settingsRow(
            label: _tr.t('settings_show_labels'),
            trailing: Switch(value: _showLabels, onChanged: _setShowLabels,
              activeColor: _theme.accent)),
          const SizedBox(height: 12),
          _sectionLabel(_tr.t('settings_size')),
          _segmentedControl(
            options: [
              {'value': 'small',  'label': _tr.t('settings_size_small')},
              {'value': 'medium', 'label': _tr.t('settings_size_medium')},
              {'value': 'large',  'label': _tr.t('settings_size_large')},
            ],
            selected: _size,
            onSelect: _setSize,
          ),
          const SizedBox(height: 12),
          _sectionLabel(_tr.t('settings_contrast')),
          _segmentedControl(
            options: [
              {'value': 'normal', 'label': _tr.t('settings_contrast_normal')},
              {'value': 'high',   'label': _tr.t('settings_contrast_high')},
            ],
            selected: _contrast,
            onSelect: _setContrast,
          ),
          const SizedBox(height: 28),

          _sectionLabel(_tr.t('settings_language')),
          _buildLanguageDropdown(),
          const SizedBox(height: 28),

          _sectionLabel(_tr.t('settings_export')),
          _actionButton(_tr.t('settings_export_json'), () => _export.exportJson()),
          const SizedBox(height: 6),
          _actionButton(_tr.t('settings_export_csv'), () => _export.exportCsv()),
          const SizedBox(height: 6),
          _actionButton(_tr.t('settings_export_json_all'), () => _export.exportJson(includeDeleted: true)),
          const SizedBox(height: 6),
          _actionButton(_tr.t('settings_export_csv_all'), () => _export.exportCsv(includeDeleted: true)),
          const SizedBox(height: 28),

          _sectionLabel(_tr.t('settings_import')),
          _actionButton(_tr.t('settings_import_json'), _importJson),
          const SizedBox(height: 6),
          _actionButton(_tr.t('settings_import_csv'), _importCsv),
          const SizedBox(height: 28),

          _sectionLabel(_tr.t('settings_reset')),
          _actionButton(_tr.t('settings_reset_btn'), _resetToDefault, destructive: true),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    if (_languages.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _theme.surface,
        border: Border.all(color: _theme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _language,
          isExpanded: true,
          dropdownColor: _theme.surface,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: _theme.bodySize,
            color: _theme.ink,
          ),
          items: _languages.map((lang) {
            return DropdownMenuItem<String>(
              value: lang['code'],
              child: Text(lang['label'] ?? lang['code'] ?? ''),
            );
          }).toList(),
          onChanged: (val) { if (val != null) _setLanguage(val); },
        ),
      ),
    );
  }

  Widget _segmentedControl({
    required List<Map<String, String>> options,
    required String selected,
    required Function(String) onSelect,
  }) {
    return Row(
      children: options.map((opt) {
        final isSelected = selected == opt['value'];
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(opt['value']!),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _theme.accent : _theme.surface,
                border: Border.all(
                  color: isSelected ? _theme.accent : _theme.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(opt['label']!, style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: _theme.captionSize,
                  color: isSelected ? _theme.accentText : _theme.inkLight,
                )),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(), style: TextStyle(
        fontFamily: 'monospace', fontSize: 10,
        letterSpacing: 1.2, color: _theme.inkFaint)),
    );
  }

  Widget _settingsRow({required String label, required Widget trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _theme.surface,
        border: Border.all(color: _theme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontFamily: 'monospace', fontSize: _theme.bodySize, color: _theme.ink)),
          trailing,
        ],
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onTap, {bool destructive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: _theme.surface,
          border: Border.all(
            color: destructive ? _theme.destructive : _theme.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(
          fontFamily: 'monospace', fontSize: _theme.bodySize,
          color: destructive ? _theme.destructive : _theme.ink)),
      ),
    );
  }
}
