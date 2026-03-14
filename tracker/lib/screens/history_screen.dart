// lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import '../models/button_model.dart';
import '../models/log_entry_model.dart';
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
  final _db     = DbService();
  final _tr     = TranslationService();
  final _theme  = AppTheme();

  List<ButtonModel>  _buttons = [];
  List<LogEntryModel> _entries = [];
  bool  _loading = true;
  _Period _period = _Period.week;
  DateTime _rangeFrom = DateTime.now().subtract(const Duration(days: 7));
  DateTime _rangeTo   = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final buttons = await _config.loadButtons();
    final now     = DateTime.now();

    List<LogEntryModel> entries;
    if (_period == _Period.range) {
      final from = DateTime(_rangeFrom.year, _rangeFrom.month, _rangeFrom.day);
      final to   = DateTime(_rangeTo.year, _rangeTo.month, _rangeTo.day, 23, 59, 59);
      entries = await _db.getLogForRange(from: from, to: to, includeDeleted: true);
    } else {
      final days = _period == _Period.week ? 7 : 30;
      final from = DateTime(now.year, now.month, now.day - days);
      final to   = DateTime(now.year, now.month, now.day, 23, 59, 59);
      entries = await _db.getLogForRange(from: from, to: to);
    }

    setState(() { _buttons = buttons; _entries = entries; _loading = false; });
  }

  Future<void> _pickRange() async {
    final now  = DateTime.now();
    final from = await showDatePicker(
      context: context,
      initialDate: _rangeFrom,
      firstDate: DateTime(now.year - 5),
      lastDate:  DateTime(now.year + 2),
      helpText:  _tr.t('range_from'),
    );
    if (from == null || !mounted) return;
    final to = await showDatePicker(
      context: context,
      initialDate: _rangeTo.isBefore(from) ? from : _rangeTo,
      firstDate: from,
      lastDate:  DateTime(now.year + 2),
      helpText:  _tr.t('range_to'),
    );
    if (to == null || !mounted) return;
    setState(() { _rangeFrom = from; _rangeTo = to; _period = _Period.range; });
    _load();
  }

  ButtonModel? _buttonFor(String? id) {
    if (id == null) return null;
    try { return _buttons.firstWhere((b) => b.id == id); }
    catch (_) { return null; }
  }

  String _p(int n)  => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime dt) => '${_p(dt.day)}.${_p(dt.month)}.${dt.year.toString().substring(2)}';
  String _fmtTime(DateTime dt) => '${_p(dt.hour)}:${_p(dt.minute)}';
  String _fmtDay(DateTime dt)  => _tr.dayName(dt.weekday).substring(0, 3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.background,
      body: SafeArea(child: Column(children: [
        _buildTopBar(),
        _buildPeriodSelector(),
        _buildTableHeader(),
        _loading
            ? const Expanded(child: Center(child: CircularProgressIndicator()))
            : Expanded(child: _buildTable()),
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
        Text(_tr.t('history_title'), style: TextStyle(
          fontFamily: 'monospace', fontSize: _theme.headerSize * 0.8,
          fontWeight: FontWeight.w600, color: _theme.ink)),
        const Spacer(),
        if (_period == _Period.range)
          Text('${_fmtDate(_rangeFrom)} – ${_fmtDate(_rangeTo)}',
            style: TextStyle(fontFamily: 'monospace',
              fontSize: _theme.captionSize, color: _theme.inkLight)),
        const SizedBox(width: 8),
        Text('${_entries.length} ${_tr.t(_entries.length == 1 ? "entry" : "entries")}',
          style: TextStyle(fontFamily: 'monospace',
            fontSize: _theme.captionSize, color: _theme.inkFaint)),
      ]),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _theme.border))),
      child: Row(children: [
        _periodBtn(_Period.week,  _tr.t('period_7')),
        const SizedBox(width: 8),
        _periodBtn(_Period.month, _tr.t('period_30')),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _pickRange,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _period == _Period.range ? _theme.accent : _theme.surface,
              border: Border.all(color: _period == _Period.range ? _theme.accent : _theme.border),
              borderRadius: BorderRadius.circular(4)),
            child: Text(_tr.t('period_range'), style: TextStyle(
              fontFamily: 'monospace', fontSize: _theme.captionSize,
              color: _period == _Period.range ? _theme.accentText : _theme.inkLight)),
          ),
        ),
      ]),
    );
  }

  Widget _periodBtn(_Period p, String label) {
    final sel = _period == p;
    return GestureDetector(
      onTap: () { setState(() => _period = p); _load(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _theme.accent : _theme.surface,
          border: Border.all(color: sel ? _theme.accent : _theme.border),
          borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: TextStyle(
          fontFamily: 'monospace', fontSize: _theme.captionSize,
          color: sel ? _theme.accentText : _theme.inkLight)),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: _theme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _theme.border, width: 1.5))),
      child: _tableRow(
        day: _tr.t('col_day'), date: _tr.t('col_date'),
        time: _tr.t('col_time'), symbol: _tr.t('col_symbol'),
        label: _tr.t('col_label'), delta: _tr.t('col_delta'),
        isHeader: true, deleted: false),
    );
  }

  Widget _buildTable() {
    if (_entries.isEmpty) {
      return Center(child: Text(_tr.t('no_entries_period'),
        style: TextStyle(fontFamily: 'monospace',
          fontSize: _theme.captionSize, color: _theme.inkFaint)));
    }
    return ListView.builder(
      itemCount: _entries.length,
      itemBuilder: (ctx, i) {
        final e   = _entries[i];
        final btn = _buttonFor(e.buttonId);
        final dt  = e.dateTime;
        return Container(
          color: i % 2 == 0 ? _theme.surface : _theme.background,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: _tableRow(
            day:    _fmtDay(dt),
            date:   _fmtDate(dt),
            time:   _fmtTime(dt),
            symbol: btn?.symbol ?? (e.type == LogType.settings ? '⚙' : '?'),
            label:  e.type == LogType.settings
                ? (e.textValue ?? 'settings')
                : (btn?.getLabel(_tr.language) ?? e.buttonId ?? ''),
            delta:   e.delta != null
                ? (e.delta! > 0 ? '+${e.delta}' : '${e.delta}')
                : (e.textValue != null ? '✎' : ''),
            isHeader: false,
            deleted:  e.deleted,
          ),
        );
      },
    );
  }

  Widget _tableRow({
    required String day, date, time, symbol, label, delta,
    required bool isHeader, required bool deleted,
  }) {
    final base = TextStyle(
      fontFamily:  'monospace',
      fontSize:    isHeader ? _theme.captionSize - 1 : _theme.captionSize,
      fontWeight:  isHeader ? FontWeight.w600 : FontWeight.normal,
      color:       isHeader ? _theme.inkFaint : deleted ? _theme.inkFaint : _theme.inkMedium,
      decoration:  deleted && !isHeader ? TextDecoration.lineThrough : TextDecoration.none,
    );
    Color deltaColor = _theme.inkFaint;
    if (!isHeader && delta.startsWith('+')) deltaColor = _theme.positive;
    if (!isHeader && delta.startsWith('-')) deltaColor = _theme.destructive;

    return Row(children: [
      SizedBox(width: 32, child: Text(day,    style: base, overflow: TextOverflow.clip)),
      SizedBox(width: 60, child: Text(date,   style: base, overflow: TextOverflow.clip)),
      SizedBox(width: 42, child: Text(time,   style: base, overflow: TextOverflow.clip)),
      SizedBox(width: 26, child: Text(symbol, style: isHeader ? base : base.copyWith(
        fontSize: _theme.captionSize + 2, decoration: TextDecoration.none))),
      Expanded(           child: Text(label,  style: base, overflow: TextOverflow.ellipsis)),
      SizedBox(width: 24, child: Text(delta,
        style: base.copyWith(color: deltaColor, decoration: TextDecoration.none),
        textAlign: TextAlign.right)),
    ]);
  }
}

enum _Period { week, month, range }
