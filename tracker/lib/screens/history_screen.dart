// lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import '../models/button_model.dart';
import '../models/entry_model.dart';
import '../services/config_service.dart';
import '../services/db_service.dart';
import '../services/translation_service.dart';
import '../services/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _config = ConfigService();
  final _db = DbService();
  final _tr = TranslationService();
  final _theme = AppTheme();

  List<ButtonModel> _buttons = [];
  Map<String, List<EntryModel>> _grouped = {};
  bool _loading = true;
  _Period _period = _Period.week;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final buttons = await _config.loadButtons();
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final entries = await _db.getEntriesForRange(_periodStart(), endOfToday);
    final grouped = <String, List<EntryModel>>{};
    for (final e in entries.reversed) {
      grouped.putIfAbsent(_dateKey(e.timestamp), () => []).add(e);
    }
    setState(() {
      _buttons = buttons;
      _grouped = grouped;
      _loading = false;
    });
  }

  DateTime _periodStart() {
    final now = DateTime.now();
    switch (_period) {
      case _Period.week:  return now.subtract(const Duration(days: 7));
      case _Period.month: return DateTime(now.year, now.month - 1, now.day);
      case _Period.year:  return DateTime(now.year - 1, now.month, now.day);
    }
  }

  String _dateKey(DateTime dt) => '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';
  String _pad(int n) => n.toString().padLeft(2, '0');
  String _formatTime(DateTime dt) => '${_pad(dt.hour)}:${_pad(dt.minute)}';

  // Format datuma za listing: "Subota, 14. mart 2026."
  String _formatFullDate(DateTime dt) => _tr.formatDate(dt);

  ButtonModel? _buttonFor(String id) {
    try { return _buttons.firstWhere((b) => b.id == id); }
    catch (_) { return null; }
  }

  Map<String, int> _countsByButton(List<EntryModel> entries) {
    final counts = <String, int>{};
    for (final e in entries) {
      counts[e.buttonId] = (counts[e.buttonId] ?? 0) + 1;
    }
    return counts;
  }

  // Parsira dateKey nazad u DateTime
  DateTime _parseKey(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildPeriodSelector(),
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
        Text(_tr.t('history_title'), style: TextStyle(
          fontFamily: 'monospace', fontSize: _theme.headerSize * 0.8,
          fontWeight: FontWeight.w600, color: _theme.ink)),
      ]),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _theme.border)),
      ),
      child: Row(
        children: _Period.values.map((p) {
          final selected = _period == p;
          return GestureDetector(
            onTap: () { setState(() => _period = p); _load(); },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? _theme.accent : _theme.surface,
                border: Border.all(
                  color: selected ? _theme.accent : _theme.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(p.label(_tr), style: TextStyle(
                fontFamily: 'monospace', fontSize: _theme.captionSize,
                color: selected ? _theme.accentText : _theme.inkLight)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent() {
    if (_grouped.isEmpty) {
      return Center(child: Text(_tr.t('no_entries_period'),
        style: TextStyle(fontFamily: 'monospace',
          fontSize: _theme.captionSize, color: _theme.inkFaint)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _grouped.length,
      itemBuilder: (ctx, i) {
        final dateKey = _grouped.keys.elementAt(i);
        return _buildDayCard(dateKey, _grouped[dateKey]!);
      },
    );
  }

  Widget _buildDayCard(String dateKey, List<EntryModel> entries) {
    final counts = _countsByButton(entries);
    final dt = _parseKey(dateKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _theme.surface,
        border: Border.all(color: _theme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatFullDate(dt), style: TextStyle(
                fontFamily: 'monospace', fontSize: _theme.captionSize,
                fontWeight: FontWeight.w600, color: _theme.ink)),
              Row(children: counts.entries.map((e) {
                final btn = _buttonFor(e.key);
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text('${btn?.symbol ?? '?'} ${e.value}',
                    style: TextStyle(fontFamily: 'monospace',
                      fontSize: _theme.captionSize, color: _theme.inkLight)),
                );
              }).toList()),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: _theme.border, height: 1),
          const SizedBox(height: 10),
          ...entries.map((e) {
            final btn = _buttonFor(e.buttonId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                Text(_formatTime(e.timestamp), style: TextStyle(
                  fontFamily: 'monospace', fontSize: _theme.captionSize,
                  color: _theme.inkLight)),
                const SizedBox(width: 12),
                Text(btn?.symbol ?? '?', style: TextStyle(
                  fontSize: _theme.symbolSize * 0.5, color: _theme.ink)),
                const SizedBox(width: 8),
                Text(btn?.getLabel(_tr.language) ?? e.buttonId,
                  style: TextStyle(fontFamily: 'monospace',
                    fontSize: _theme.captionSize, color: _theme.inkLight)),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

enum _Period {
  week, month, year;
  String label(TranslationService tr) {
    switch (this) {
      case _Period.week:  return tr.t('period_7');
      case _Period.month: return tr.t('period_30');
      case _Period.year:  return tr.t('period_365');
    }
  }
}
