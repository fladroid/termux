// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../models/button_model.dart';
import '../models/entry_model.dart';
import '../services/config_service.dart';
import '../services/db_service.dart';
import '../widgets/symbol_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _config = ConfigService();
  final _db = DbService();

  List<ButtonModel> _buttons = [];
  List<EntryModel> _todayEntries = [];
  String _language = 'en';
  bool _showLabels = true;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final buttons = await _config.loadButtons();
    final language = await _config.getLanguage();
    final showLabels = await _config.getShowLabels();
    final entries = await _db.getEntriesForDate(_selectedDate);
    setState(() {
      _buttons = buttons;
      _language = language;
      _showLabels = showLabels;
      _todayEntries = entries;
      _loading = false;
    });
  }

  Future<void> _handleTap(ButtonModel button) async {
    await _db.insert(button.id);
    final entries = await _db.getEntriesForDate(_selectedDate);
    setState(() => _todayEntries = entries);
  }

  Future<void> _handleLongPress(ButtonModel button) async {
    final last = _todayEntries.where((e) => e.buttonId == button.id).lastOrNull;
    if (last == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undo last entry?'),
        content: Text('${button.symbol} — ${_formatTime(last.timestamp)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
    if (confirm == true && last.id != null) {
      await _db.softDelete(last.id!);
      final entries = await _db.getEntriesForDate(_selectedDate);
      setState(() => _todayEntries = entries);
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _loading = true;
    });
    _load();
  }

  int _countForButton(String buttonId) =>
      _todayEntries.where((e) => e.buttonId == buttonId).length;

  bool _isActive(String buttonId) => _countForButton(buttonId) > 0;

  String _formatTime(DateTime dt) => '${_pad(dt.hour)}:${_pad(dt.minute)}';
  String _pad(int n) => n.toString().padLeft(2, '0');

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(dt.year, dt.month, dt.day);
    final diff = selected.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(),
            ),
            _buildBottomBar(),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatDate(_selectedDate),
                style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 22,
                  fontWeight: FontWeight.w600, letterSpacing: -0.5,
                )),
              Text('${_todayEntries.length} entries',
                style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12,
                  color: Color(0xFF6B6560),
                )),
            ],
          ),
          Row(children: [
            _navButton('‹', () => _changeDate(-1)),
            const SizedBox(width: 8),
            _navButton('›', () => _changeDate(1)),
            const SizedBox(width: 8),
            _navButton('⚙', () => Navigator.pushNamed(context, '/settings').then((_) => _load())),
          ]),
        ],
      ),
    );
  }

  Widget _navButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFC8C0B4)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(label,
            style: const TextStyle(fontSize: 16, color: Color(0xFF6B6560))),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGrid(),
          const SizedBox(height: 28),
          _buildLog(),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemCount: _buttons.length,
      itemBuilder: (ctx, i) {
        final btn = _buttons[i];
        return GestureDetector(
          onLongPress: () => _handleLongPress(btn),
          child: SymbolButton(
            button: btn,
            language: _language,
            showLabel: _showLabels,
            todayCount: _countForButton(btn.id),
            isActive: _isActive(btn.id),
            onTap: () => _handleTap(btn),
          ),
        );
      },
    );
  }

  Widget _buildLog() {
    if (_todayEntries.isEmpty) {
      return const Text('No entries yet.',
        style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFC8C0B4)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LOG',
          style: TextStyle(fontFamily: 'monospace', fontSize: 10,
            letterSpacing: 1.2, color: Color(0xFFC8C0B4))),
        const SizedBox(height: 10),
        ..._todayEntries.reversed.map((e) {
          final btn = _buttons.firstWhere(
            (b) => b.id == e.buttonId,
            orElse: () => ButtonModel(id: e.buttonId, symbol: '?', labels: {}),
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Text(_formatTime(e.timestamp),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF6B6560))),
              const SizedBox(width: 12),
              Text(btn.symbol, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(btn.getLabel(_language),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF6B6560))),
            ]),
          );
        }),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFDDD8CE))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(children: [
        _bottomBtn('◉', 'Today', true, () {
          setState(() => _selectedDate = DateTime.now());
          _load();
        }),
        _bottomBtn('◫', 'History', false,
          () => Navigator.pushNamed(context, '/history').then((_) => _load())),
        _bottomBtn('↗', 'Export', false,
          () => Navigator.pushNamed(context, '/settings')),
        _bottomBtn('⚙', 'Settings', false,
          () => Navigator.pushNamed(context, '/settings').then((_) => _load())),
      ]),
    );
  }

  Widget _bottomBtn(String icon, String label, bool active, VoidCallback onTap) {
    final color = active ? const Color(0xFF2D5A27) : const Color(0xFFC8C0B4);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: TextStyle(fontSize: 18, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              fontFamily: 'monospace', fontSize: 8,
              letterSpacing: 1.0, color: color)),
          ],
        ),
      ),
    );
  }
}
