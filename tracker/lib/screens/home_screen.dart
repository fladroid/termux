// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../models/button_model.dart';
import '../models/log_entry_model.dart';
import '../services/config_service.dart';
import '../services/db_service.dart';
import '../services/translation_service.dart';
import '../services/app_theme.dart';
import '../widgets/counter_button.dart';
import '../widgets/text_button_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _config = ConfigService();
  final _db     = DbService();
  final _tr     = TranslationService();
  final _theme  = AppTheme();

  List<ButtonModel>  _buttons    = [];
  Map<String, int>   _values     = {};
  Map<String, String> _textValues = {};
  bool               _showLabels = true;
  DateTime           _selectedDate = DateTime.now();
  bool               _loading    = true;
  final Set<String>  _warnedDates = {};
  List<Map<String, String>> _languages = [];
  String             _currentLang = 'en';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final buttons     = await _config.loadButtons();
    final showLabels  = await _config.getShowLabels();
    final values      = await _db.getValuesForDate(_selectedDate);
    final textValues  = await _db.getTextValuesForDate(_selectedDate);
    final languages   = await _config.loadLanguages();
    final currentLang = await _config.getLanguage();
    setState(() {
      _buttons    = buttons;
      _showLabels = showLabels;
      _values     = values;
      _textValues = textValues;
      _languages  = languages;
      _currentLang = currentLang;
      _loading    = false;
    });
  }

  String _dateKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';

  bool _isToday(DateTime dt) {
    final n = DateTime.now();
    return dt.year == n.year && dt.month == n.month && dt.day == n.day;
  }

  Future<bool> _checkDateWarning(DateTime dt) async {
    if (_isToday(dt)) return true;
    final key = _dateKey(dt);
    if (_warnedDates.contains(key)) return true;
    final isPast = dt.isBefore(DateTime.now());
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   Text(_tr.t(isPast ? 'past_warning_title' : 'future_warning_title')),
        content: Text(_tr.t(isPast ? 'past_warning_body'  : 'future_warning_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_tr.t('warning_cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),  child: Text(_tr.t('warning_ok'))),
        ],
      ),
    );
    if (confirm == true) { _warnedDates.add(key); return true; }
    return false;
  }

  Future<void> _handleChange(ButtonModel button, int delta) async {
    final allowed = await _checkDateWarning(_selectedDate);
    if (!allowed) return;
    final current = _values[button.id] ?? 0;
    if (delta < 0 && current <= 0) return;
    final newValue = await _db.changeValue(button.id, _selectedDate, delta);
    await _db.addLog(type: LogType.counter, buttonId: button.id, delta: delta, timestamp: _selectedDate);
    setState(() => _values[button.id] = newValue);
  }

  Future<void> _handleTextSave(ButtonModel button, String text) async {
    final allowed = await _checkDateWarning(_selectedDate);
    if (!allowed) return;
    await _db.saveTextValue(button.id, _selectedDate, text, timestamp: _selectedDate);
    setState(() => _textValues[button.id] = text);
  }

  Future<void> _handleReset() async {
    // Provjeri ima li uopće što resetovati
    final hasValues = _values.values.any((v) => v > 0) ||
        _textValues.values.any((v) => v.isNotEmpty);
    if (!hasValues) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   Text(_tr.t('reset_day_title')),
        content: Text(_tr.t('reset_day_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_tr.t('warning_cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tr.t('reset_day_ok'),
              style: TextStyle(color: _theme.destructive))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final counterIds = _buttons.where((b) => b.isCounter).map((b) => b.id).toList();
    final textIds    = _buttons.where((b) => b.isText).map((b) => b.id).toList();

    await _db.resetDayToZero(
      date:          _selectedDate,
      counterIds:    counterIds,
      textIds:       textIds,
      currentValues: _values,
    );

    setState(() {
      for (final id in counterIds) { _values[id] = 0; }
      for (final id in textIds)    { _textValues[id] = ''; }
    });
  }

  void _changeDate(int days) {
    setState(() { _selectedDate = _selectedDate.add(Duration(days: days)); _loading = true; });
    _load();
  }

  Future<bool> _onWillPop() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   Text(_tr.t('exit_title')),
        content: Text(_tr.t('exit_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_tr.t('exit_cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),  child: Text(_tr.t('exit_ok'))),
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
        body: SafeArea(child: Column(children: [
          _buildTopBar(),
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildContent()),
          _buildBottomBar(),
        ])),
      ),
    );
  }

  Widget _buildTopBar() {
    final showSub = _tr.isRelativeDay(_selectedDate);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _theme.border))),
      child: Column(children: [
        // Gornji red: Tracker v2.6 + jezik dropdown
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tracker v2.9.3', style: TextStyle(
              fontFamily: 'monospace', fontSize: _theme.captionSize,
              fontWeight: FontWeight.w600, color: _theme.inkFaint,
              letterSpacing: 1.2)),
            if (_languages.isNotEmpty)
              _buildLangDropdown(),
          ],
        ),
        const SizedBox(height: 6),
        // Donji red: datum + nav strelice
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_tr.formatHeaderMain(_selectedDate), style: TextStyle(
                fontFamily: 'monospace', fontSize: _theme.headerSize,
                fontWeight: FontWeight.w600, color: _theme.ink)),
              if (showSub)
                Text(_tr.formatDate(_selectedDate), style: TextStyle(
                  fontFamily: 'monospace', fontSize: _theme.captionSize,
                  color: _theme.inkLight)),
              const SizedBox(height: 4),
              _resetBtn(),
            ]),
            Row(children: [
              _navBtn('‹', () => _changeDate(-1)),
              const SizedBox(width: 8),
              _navBtn('›', () => _changeDate(1)),
            ]),
          ],
        ),
      ]),
    );
  }

  Widget _buildLangDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _theme.surface,
        border: Border.all(color: _theme.border),
        borderRadius: BorderRadius.circular(4)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _currentLang,
          isDense: true,
          dropdownColor: _theme.surface,
          style: TextStyle(fontFamily: 'monospace',
            fontSize: _theme.captionSize, color: _theme.ink),
          items: _languages.map((l) => DropdownMenuItem<String>(
            value: l['code'],
            child: Text(l['label'] ?? l['code'] ?? ''),
          )).toList(),
          onChanged: (v) async {
            if (v == null) return;
            await _config.setLanguage(v);
            setState(() => _currentLang = v);
            _load();
          },
        ),
      ),
    );
  }

  Widget _navBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: _theme.inkFaint),
          borderRadius: BorderRadius.circular(4)),
        child: Center(child: Text(label,
          style: TextStyle(fontSize: 16, color: _theme.inkLight))),
      ),
    );
  }

  Widget _resetBtn() {
    return GestureDetector(
      onTap: _handleReset,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: _theme.destructive.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(4)),
        child: Text(_tr.t('reset_day_btn'),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: _theme.captionSize - 1,
            color: _theme.destructive)),
      ),
    );
  }

  Widget _buildContent() {
    // Odijeli counter od text buttona
    final counters = _buttons.where((b) => b.isCounter).toList();
    final texts    = _buttons.where((b) => b.isText).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Counter grid
          if (counters.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: counters.length,
              itemBuilder: (ctx, i) {
                final btn = counters[i];
                return CounterButton(
                  button:    btn,
                  value:     _values[btn.id] ?? 0,
                  showLabel: _showLabels,
                  onPlus:    () => _handleChange(btn,  1),
                  onMinus:   () => _handleChange(btn, -1),
                );
              },
            ),

          // Text containeri ispod countera
          if (texts.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...texts.map((btn) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButtonWidget(
                button:    btn,
                savedText: _textValues[btn.id],
                showLabel: _showLabels,
                onSave:    (text) => _handleTextSave(btn, text),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _theme.border))),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(children: [
        _bottomBtn('◉', _tr.t('nav_today'), true, () {
          setState(() => _selectedDate = DateTime.now());
          _load();
        }),
        _bottomBtn('◫', _tr.t('nav_history'), false,
          () => Navigator.pushNamed(context, '/history')),
        _bottomBtn('📊', _tr.t('nav_report'), false,
          () => Navigator.pushNamed(context, '/report')),
        _bottomBtn('↗', _tr.t('nav_export'), false,
          () => Navigator.pushNamed(context, '/settings')),
        _bottomBtn('⚙', _tr.t('nav_settings'), false,
          () => Navigator.pushNamed(context, '/settings').then((_) => _load())),
      ]),
    );
  }

  Widget _bottomBtn(String icon, String label, bool active, VoidCallback onTap) {
    final color = active ? _theme.accent : _theme.inkFaint;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: TextStyle(fontSize: 16, color: color)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontFamily: 'monospace',
          fontSize: 7, letterSpacing: 0.8, color: color),
          overflow: TextOverflow.ellipsis),
      ]),
    ));
  }
}
