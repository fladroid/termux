// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import '../services/config_service.dart';
import '../services/export_service.dart';
import '../services/db_service.dart';
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
  final _db     = DbService();
  final _tr     = TranslationService();
  final _theme  = AppTheme();

  String _language   = 'en';
  bool   _showLabels = true;
  String _size       = 'medium';
  String _contrast   = 'normal';
  bool   _loading    = true;
  List<Map<String, String>> _languages = [];
  Map<String, dynamic> _dbStats = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final lang      = await _config.getLanguage();
    final labels    = await _config.getShowLabels();
    final size      = await _config.getSize();
    final contrast  = await _config.getContrast();
    final languages = await _config.loadLanguages();
    final stats     = await _db.getDbStats();
    setState(() {
      _language = lang; _showLabels = labels;
      _size = size; _contrast = contrast;
      _languages = languages; _dbStats = stats; _loading = false;
    });
  }

  Future<void> _setLanguage(String lang) async {
    await _config.setLanguage(lang);
    setState(() => _language = lang);
  }

  Future<void> _resetToDefault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   Text(_tr.t('reset_confirm_title')),
        content: Text(_tr.t('reset_confirm_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_tr.t('reset_confirm_cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),  child: Text(_tr.t('reset_confirm_ok'))),
        ],
      ),
    );
    if (confirm == true) { await _config.resetToDefault(); await _load(); }
  }


  Future<void> _importJson() async {
    final r = await _export.importJson();
    if (!mounted || r.cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
      r.success
        ? _tr.t('import_success', params: {'imported': '${r.imported}', 'skipped': '${r.skipped}'})
        : _tr.t('import_error',   params: {'error': r.errorMessage ?? ''}))));
  }

  Future<void> _importCsv() async {
    final r = await _export.importCsv();
    if (!mounted || r.cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
      r.success
        ? _tr.t('import_success', params: {'imported': '${r.imported}', 'skipped': '${r.skipped}'})
        : _tr.t('import_error',   params: {'error': r.errorMessage ?? ''}))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.background,
      body: SafeArea(child: Column(children: [
        _buildTopBar(),
        _loading
            ? const Expanded(child: Center(child: CircularProgressIndicator()))
            : Expanded(child: _buildContent()),
      ])),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _theme.border))),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text('‹', style: TextStyle(fontSize: 22, color: _theme.inkLight))),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        _sectionLabel(_tr.t('settings_display')),
        _settingsRow(label: _tr.t('settings_show_labels'),
          trailing: Switch(value: _showLabels,
            onChanged: (v) async { await _config.setShowLabels(v); setState(() => _showLabels = v); },
            activeColor: _theme.accent)),
        const SizedBox(height: 12),

        _sectionLabel(_tr.t('settings_size')),
        _segmented([
          {'value': 'small',  'label': _tr.t('settings_size_small')},
          {'value': 'medium', 'label': _tr.t('settings_size_medium')},
          {'value': 'large',  'label': _tr.t('settings_size_large')},
        ], _size, (v) async { await _config.setSize(v); _theme.setSize(v); setState(() => _size = v); }),
        const SizedBox(height: 12),

        _sectionLabel(_tr.t('settings_contrast')),
        _segmented([
          {'value': 'normal', 'label': _tr.t('settings_contrast_normal')},
          {'value': 'high',   'label': _tr.t('settings_contrast_high')},
        ], _contrast, (v) async { await _config.setContrast(v); _theme.setContrast(v); setState(() => _contrast = v); }),
        const SizedBox(height: 28),

        _sectionLabel(_tr.t('settings_language')),
        _buildDropdown(),
        const SizedBox(height: 28),

        _sectionLabel(_tr.t('settings_export')),
        _actionBtn(_tr.t('settings_export_json'),     () => _export.exportJson()),
        const SizedBox(height: 6),
        _actionBtn(_tr.t('settings_export_csv'),      () => _export.exportCsv()),
        const SizedBox(height: 6),
        _actionBtn(_tr.t('settings_export_json_all'), () => _export.exportJson(includeDeleted: true)),
        const SizedBox(height: 6),
        _actionBtn(_tr.t('settings_export_csv_all'),  () => _export.exportCsv(includeDeleted: true)),
        const SizedBox(height: 28),

        _sectionLabel(_tr.t('settings_import')),
        _actionBtn(_tr.t('settings_import_json'), _importJson),
        const SizedBox(height: 6),
        _actionBtn(_tr.t('settings_import_csv'),  _importCsv),
        const SizedBox(height: 28),

        _sectionLabel(_tr.t('settings_db')),
        _buildDbStats(),
        const SizedBox(height: 10),


        _sectionLabel(_tr.t('settings_reset')),
        _actionBtn(_tr.t('settings_reset_btn'), _resetToDefault, destructive: true),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildDbStats() {
    final total   = _dbStats['total_log']   ?? 0;
    final active  = _dbStats['active_log']  ?? 0;
    final daily   = _dbStats['total_daily'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _theme.surface,
        border: Border.all(color: _theme.border),
        borderRadius: BorderRadius.circular(6)),
      child: Column(children: [
        _statRow(_tr.t('db_total_log'),    '$total'),
        _statRow(_tr.t('db_active_log'),   '$active'),
        _statRow(_tr.t('db_daily_values'), '$daily'),
      ]),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontFamily: 'monospace',
            fontSize: _theme.captionSize, color: _theme.inkLight)),
          Text(value, style: TextStyle(fontFamily: 'monospace',
            fontSize: _theme.captionSize, fontWeight: FontWeight.w600,
            color: _theme.ink)),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    if (_languages.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _theme.surface,
        border: Border.all(color: _theme.border),
        borderRadius: BorderRadius.circular(6)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _language,
          isExpanded: true,
          dropdownColor: _theme.surface,
          style: TextStyle(fontFamily: 'monospace',
            fontSize: _theme.bodySize, color: _theme.ink),
          items: _languages.map((l) => DropdownMenuItem<String>(
            value: l['code'],
            child: Text(l['label'] ?? l['code'] ?? ''),
          )).toList(),
          onChanged: (v) { if (v != null) _setLanguage(v); },
        ),
      ),
    );
  }

  Widget _segmented(List<Map<String, String>> options, String selected, Function(String) onSelect) {
    return Row(children: options.map((o) {
      final sel = selected == o['value'];
      return Expanded(child: GestureDetector(
        onTap: () => onSelect(o['value']!),
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? _theme.accent : _theme.surface,
            border: Border.all(color: sel ? _theme.accent : _theme.border),
            borderRadius: BorderRadius.circular(6)),
          child: Center(child: Text(o['label']!, style: TextStyle(
            fontFamily: 'monospace', fontSize: _theme.captionSize,
            color: sel ? _theme.accentText : _theme.inkLight))),
        ),
      ));
    }).toList());
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text.toUpperCase(), style: TextStyle(
      fontFamily: 'monospace', fontSize: 10,
      letterSpacing: 1.2, color: _theme.inkFaint)));

  Widget _settingsRow({required String label, required Widget trailing}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _theme.surface,
        border: Border.all(color: _theme.border), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontFamily: 'monospace',
          fontSize: _theme.bodySize, color: _theme.ink)),
        trailing,
      ]),
    );

  Widget _actionBtn(String label, VoidCallback onTap, {bool destructive = false}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: _theme.surface,
          border: Border.all(color: destructive ? _theme.destructive : _theme.border),
          borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontFamily: 'monospace',
          fontSize: _theme.bodySize,
          color: destructive ? _theme.destructive : _theme.ink)),
      ),
    );
}
