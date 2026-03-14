// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import '../services/config_service.dart';
import '../services/export_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _config = ConfigService();
  final _export = ExportService();

  String _language = 'en';
  bool _showLabels = true;
  bool _loading = true;

  static const List<Map<String, String>> _languages = [
    {'code': 'en',     'label': 'English'},
    {'code': 'sr-lat', 'label': 'Srpski (latinica)'},
    {'code': 'sr-cyr', 'label': 'Српски (ћирилица)'},
    {'code': 'hr',     'label': 'Hrvatski'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final language = await _config.getLanguage();
    final showLabels = await _config.getShowLabels();
    setState(() { _language = language; _showLabels = showLabels; _loading = false; });
  }

  Future<void> _setLanguage(String lang) async {
    await _config.setLanguage(lang);
    setState(() => _language = lang);
  }

  Future<void> _setShowLabels(bool value) async {
    await _config.setShowLabels(value);
    setState(() => _showLabels = value);
  }

  Future<void> _resetToDefault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to default?'),
        content: const Text('All settings return to factory values. Entries are not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirm == true) { await _config.resetToDefault(); await _load(); }
  }

  Future<void> _importJson() async {
    final result = await _export.importJson();
    if (!mounted || result.cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: result.success
          ? Text('Imported ${result.imported}, skipped ${result.skipped}')
          : Text('Error: ${result.errorMessage}'),
    ));
  }

  Future<void> _importCsv() async {
    final result = await _export.importCsv();
    if (!mounted || result.cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: result.success
          ? Text('Imported ${result.imported}, skipped ${result.skipped}')
          : Text('Error: ${result.errorMessage}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDDD8CE))),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text('‹', style: TextStyle(fontSize: 22, color: Color(0xFF6B6560))),
        ),
        const SizedBox(width: 16),
        const Text('Settings', style: TextStyle(
          fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Display'),
          _settingsRow(label: 'Show labels',
            trailing: Switch(value: _showLabels, onChanged: _setShowLabels,
              activeColor: const Color(0xFF2D5A27))),
          const SizedBox(height: 28),
          _sectionLabel('Language'),
          ..._languages.map((lang) {
            final selected = _language == lang['code'];
            return GestureDetector(
              onTap: () => _setLanguage(lang['code']!),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF2D5A27) : const Color(0xFFFAF7F2),
                  border: Border.all(
                    color: selected ? const Color(0xFF2D5A27) : const Color(0xFFDDD8CE)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(lang['label']!, style: TextStyle(
                      fontFamily: 'monospace', fontSize: 13,
                      color: selected ? Colors.white : const Color(0xFF1A1A1A))),
                    if (selected)
                      const Text('✓', style: TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 28),
          _sectionLabel('Export'),
          _actionButton('Export JSON', () => _export.exportJson()),
          const SizedBox(height: 6),
          _actionButton('Export CSV', () => _export.exportCsv()),
          const SizedBox(height: 6),
          _actionButton('Export JSON (include deleted)', () => _export.exportJson(includeDeleted: true)),
          const SizedBox(height: 6),
          _actionButton('Export CSV (include deleted)', () => _export.exportCsv(includeDeleted: true)),
          const SizedBox(height: 28),
          _sectionLabel('Import'),
          _actionButton('Import JSON', _importJson),
          const SizedBox(height: 6),
          _actionButton('Import CSV', _importCsv),
          const SizedBox(height: 28),
          _sectionLabel('Reset'),
          _actionButton('Reset to default', _resetToDefault, destructive: true),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text.toUpperCase(), style: const TextStyle(
        fontFamily: 'monospace', fontSize: 10,
        letterSpacing: 1.2, color: Color(0xFFC8C0B4))),
    );
  }

  Widget _settingsRow({required String label, required Widget trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        border: Border.all(color: const Color(0xFFDDD8CE)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
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
          color: const Color(0xFFFAF7F2),
          border: Border.all(
            color: destructive ? const Color(0xFF8B2020) : const Color(0xFFDDD8CE)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(
          fontFamily: 'monospace', fontSize: 13,
          color: destructive ? const Color(0xFF8B2020) : const Color(0xFF1A1A1A))),
      ),
    );
  }
}
