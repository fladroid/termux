// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/button_model.dart';
import '../models/entry_model.dart';
import '../services/config_service.dart';
import '../services/db_service.dart';
import '../services/translation_service.dart';
import '../services/app_theme.dart';
import '../widgets/symbol_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _config = ConfigService();
  final _db = DbService();
  final _tr = TranslationService();
  final _theme = AppTheme();

  List<ButtonModel> _buttons = [];
  List<EntryModel> _todayEntries = [];
  bool _showLabels = true;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;

  final Set<String> _warnedDates = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final buttons = await _config.loadButtons();
    final showLabels = await _config.getShowLabels();
    final entries = await _db.getEntriesForDate(_selectedDate);
    setState(() {
      _buttons = buttons;
      _showLabels = showLabels;
      _todayEntries = entries;
      _loading = false;
    });
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  String _dateKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';

  // Vraca true ako je dozvoljeno nastaviti s klikom
  Future<bool> _checkDateWarning(DateTime dt) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(dt.year, dt.month, dt.day);
    final diff = selected.difference(today).inDays;

    if (diff == 0) return true;

    final key = _dateKey(dt);
    if (_warnedDates.contains(key)) return true;

    final isPast = diff < 0;
    final title = isPast ? _tr.t('past_warning_title') : _tr.t('future_warning_title');
    final body  = isPast ? _tr.t('past_warning_body')  : _tr.t('future_warning_body');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tr.t('warning_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tr.t('warning_ok')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _warnedDates.add(key);
      return true;
    }
    return false;
  }

  Future<void> _handleTap(ButtonModel button) async {
    final allowed = await _checkDateWarning(_selectedDate);
    if (!allowed) return;

    // FIX: insert s ispravnim datumom (ne nužno danas)
    final now = DateTime.now();
    final selected = _selectedDate;
    final timestamp = DateTime(
      selected.year, selected.month, selected.day,
      now.hour, now.minute, now.second,
    );
    await _db.insertAt(button.id, timestamp);
    final entries = await _db.getEntriesForDate(_selectedDate);
    setState(() => _todayEntries = entries);
  }

  Future<void> _handleLongPress(ButtonModel button) async {
    final last = _todayEntries.where((e) => e.buttonId == button.id).lastOrNull;
    if (last == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tr.t('undo_title')),
        content: Text('${button.symbol} — ${_formatTime(last.timestamp)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_tr.t('undo_no'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),  child: Text(_tr.t('undo_yes'))),
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

  // FIX: subtitle za Danas/Jucer/Sutra uvijek prikazuje puni datum
  String _headerMain(DateTime dt) => _tr.formatHeaderMain(dt);
  String _headerSub(DateTime dt)  => _tr.formatDate(dt);

  // FIX: subtitle prikazujemo za Danas, Jucer i Sutra
  bool _showSub(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(dt.year, dt.month, dt.day);
    final diff = selected.difference(today).inDays;
    return diff >= -1 && diff <= 1;
  }

  Future<bool> _onWillPop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tr.t('exit_title')),
        content: Text(_tr.t('exit_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tr.t('exit_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tr.t('exit_ok')),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: _theme.background,
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
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _theme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_headerMain(_selectedDate), style: TextStyle(
                fontFamily: 'monospace',
                fontSize: _theme.headerSize,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: _theme.ink,
              )),
              // FIX: datum ispod za Danas, Jucer i Sutra
              if (_showSub(_selectedDate))
                Text(_headerSub(_selectedDate), style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: _theme.captionSize,
                  color: _theme.inkLight,
                )),
              Text(
                '${_todayEntries.length} ${_tr.t(_todayEntries.length == 1 ? 'entry' : 'entries')}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: _theme.captionSize,
                  color: _theme.inkLight,
                ),
              ),
            ],
          ),
          // FIX: samo navigacija gore, bez dupliranog settings gumba
          Row(children: [
            _navButton('‹', () => _changeDate(-1)),
            const SizedBox(width: 8),
            _navButton('›', () => _changeDate(1)),
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
          border: Border.all(color: _theme.inkFaint),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(child: Text(label,
          style: TextStyle(fontSize: 16, color: _theme.inkLight))),
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
            language: _tr.language,
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
      return Text(_tr.t('no_entries'), style: TextStyle(
        fontFamily: 'monospace', fontSize: _theme.captionSize,
        color: _theme.inkFaint));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_tr.t('log'), style: TextStyle(
          fontFamily: 'monospace', fontSize: _theme.captionSize,
          letterSpacing: 1.2, color: _theme.inkFaint)),
        const SizedBox(height: 10),
        ..._todayEntries.reversed.map((e) {
          final btn = _buttons.firstWhere(
            (b) => b.id == e.buttonId,
            orElse: () => ButtonModel(id: e.buttonId, symbol: '?', labels: {}),
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Text(_formatTime(e.timestamp), style: TextStyle(
                fontFamily: 'monospace', fontSize: _theme.captionSize,
                color: _theme.inkLight)),
              const SizedBox(width: 12),
              Text(btn.symbol, style: TextStyle(
                fontSize: _theme.symbolSize * 0.5, color: _theme.ink)),
              const SizedBox(width: 8),
              Text(btn.getLabel(_tr.language), style: TextStyle(
                fontFamily: 'monospace', fontSize: _theme.captionSize,
                color: _theme.inkLight)),
            ]),
          );
        }),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _theme.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(children: [
        _bottomBtn('◉', _tr.t('nav_today'), true, () {
          setState(() => _selectedDate = DateTime.now());
          _load();
        }),
        _bottomBtn('◫', _tr.t('nav_history'), false,
          () => Navigator.pushNamed(context, '/history').then((_) => _load())),
        _bottomBtn('↗', _tr.t('nav_export'), false,
          () => Navigator.pushNamed(context, '/settings')),
        _bottomBtn('⚙', _tr.t('nav_settings'), false,
          () => Navigator.pushNamed(context, '/settings').then((_) => _load())),
      ]),
    );
  }

  Widget _bottomBtn(String icon, String label, bool active, VoidCallback onTap) {
    final color = active ? _theme.accent : _theme.inkFaint;
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
