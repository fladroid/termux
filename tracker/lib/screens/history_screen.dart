// lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import '../models/button_model.dart';
import '../models/entry_model.dart';
import '../services/config_service.dart';
import '../services/db_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _config = ConfigService();
  final _db = DbService();

  List<ButtonModel> _buttons = [];
  Map<String, List<EntryModel>> _grouped = {};
  String _language = 'en';
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
    final language = await _config.getLanguage();
    final entries = await _db.getEntriesForRange(_periodStart(), DateTime.now());
    final grouped = <String, List<EntryModel>>{};
    for (final e in entries.reversed) {
      grouped.putIfAbsent(_dateKey(e.timestamp), () => []).add(e);
    }
    setState(() {
      _buttons = buttons;
      _language = language;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDDD8CE))),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text('‹', style: TextStyle(fontSize: 22, color: Color(0xFF6B6560))),
        ),
        const SizedBox(width: 16),
        const Text('History', style: TextStyle(
          fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDDD8CE))),
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
                color: selected ? const Color(0xFF2D5A27) : const Color(0xFFFAF7F2),
                border: Border.all(
                  color: selected ? const Color(0xFF2D5A27) : const Color(0xFFDDD8CE)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(p.label, style: TextStyle(
                fontFamily: 'monospace', fontSize: 11,
                color: selected ? Colors.white : const Color(0xFF6B6560))),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent() {
    if (_grouped.isEmpty) {
      return const Center(child: Text('No entries.',
        style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFC8C0B4))));
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2),
        border: Border.all(color: const Color(0xFFDDD8CE)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateKey, style: const TextStyle(
                fontFamily: 'monospace', fontSize: 12,
                fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
              Row(children: counts.entries.map((e) {
                final btn = _buttonFor(e.key);
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text('${btn?.symbol ?? '?'} ${e.value}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF6B6560))),
                );
              }).toList()),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFFDDD8CE), height: 1),
          const SizedBox(height: 10),
          ...entries.map((e) {
            final btn = _buttonFor(e.buttonId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(children: [
                Text(_formatTime(e.timestamp),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF6B6560))),
                const SizedBox(width: 12),
                Text(btn?.symbol ?? '?', style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(btn?.getLabel(_language) ?? e.buttonId,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF6B6560))),
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
  String get label {
    switch (this) {
      case _Period.week:  return '7 days';
      case _Period.month: return '30 days';
      case _Period.year:  return '365 days';
    }
  }
}
