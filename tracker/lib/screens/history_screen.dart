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
  final _config  = ConfigService();
  final _db      = DbService();
  final _tr      = TranslationService();
  final _theme   = AppTheme();

  List<ButtonModel>   _buttons = [];
  List<LogEntryModel> _entries = [];
  bool     _loading = true;
  _Period  _period  = _Period.week;
  DateTime _rangeFrom = DateTime.now().subtract(const Duration(days: 7));
  DateTime _rangeTo   = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final buttons = await _config.loadButtons();
    final now     = DateTime.now();

    DateTime from, to;
    if (_period == _Period.range) {
      from = DateTime(_rangeFrom.year, _rangeFrom.month, _rangeFrom.day, 0, 0, 0);
      to   = DateTime(_rangeTo.year,   _rangeTo.month,   _rangeTo.day,  23, 59, 59);
    } else {
      final days = _period == _Period.week ? 7 : 30;
      from = DateTime(now.year, now.month, now.day, 0, 0, 0)
          .subtract(Duration(days: days));
      to   = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }

    final entries = await _db.getLogForRange(
      from: from, to: to,
      includeDeleted: _period == _Period.range,
    );

    setState(() { _buttons = buttons; _entries = entries; _loading = false; });
  }

  Future<void> _pickRange() async {
    final now  = DateTime.now();
    final from = await showDatePicker(
      context: context,
      initialDate: _rangeFrom,
      firstDate:   DateTime(now.year - 5),
      lastDate:    DateTime(now.year + 2),
      helpText:    _tr.t('range_from'),
    );
    if (from == null || !mounted) return;
    final to = await showDatePicker(
      context: context,
      initialDate: _rangeTo.isBefore(from) ? from : _rangeTo,
      firstDate:   from,
      lastDate:    DateTime(now.year + 2),
      helpText:    _tr.t('range_to'),
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

  String _p(int n)             => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime dt) => '${_p(dt.day)}.${_p(dt.month)}.${dt.year.toString().substring(2)}';
  String _fmtTime(DateTime dt) => '${_p(dt.hour)}:${_p(dt.minute)}';
  String _fmtDay(DateTime dt)  {
    final name = _tr.dayName(dt.weekday);
    return name.length >= 3 ? name.substring(0, 3) : name;
  }

  // Kolone — točno definirane širine u pikselima
  // Dan: 28, Datum: 52, Vrij: 38, Sim: 22, Labela: 70, +/-: 24
  // Ukupno: 28+52+38+22+70+24 + razmaci(5x4=20) = 254px — stane na svaki ekran
  static const double _wDay    = 28;
  static const double _wDate   = 52;
  static const double _wTime   = 38;
  static const double _wSym    = 22;
  static const double _wLabel  = 70;
  static const double _wDelta  = 24;
  static const double _gap     =  4;

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
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _theme.border))),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text('‹', style: TextStyle(fontSize: 22, color: _theme.inkLight))),
        const SizedBox(width: 12),
        // Naslov lijevo poravnan
        Text(_tr.t('history_title'), style: TextStyle(
          fontFamily: 'monospace', fontSize: _theme.headerSize * 0.8,
          fontWeight: FontWeight.w600, color: _theme.ink)),
        const Spacer(),
        if (_period == _Period.range)
          Text('${_fmtDate(_rangeFrom)}–${_fmtDate(_rangeTo)}',
            style: TextStyle(fontFamily: 'monospace',
              fontSize: _theme.captionSize, color: _theme.inkLight)),
        const SizedBox(width: 6),
        Text('${_entries.length}',
          style: TextStyle(fontFamily: 'monospace',
            fontSize: _theme.captionSize, color: _theme.inkFaint)),
      ]),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _theme.border))),
      child: Row(children: [
        _periodBtn(_Period.week,  _tr.t('period_7')),
        const SizedBox(width: 6),
        _periodBtn(_Period.month, _tr.t('period_30')),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _pickRange,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _period == _Period.range ? _theme.accent : _theme.surface,
              border: Border.all(
                color: _period == _Period.range ? _theme.accent : _theme.border),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _theme.border, width: 1.5))),
      child: _tableRow(
        day:    _tr.t('col_day'),
        date:   _tr.t('col_date'),
        time:   _tr.t('col_time'),
        symbol: _tr.t('col_symbol'),
        label:  _tr.t('col_label'),
        delta:  _tr.t('col_delta'),
        isHeader: true,
        deleted:  false,
      ),
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
        final deltaStr = e.delta != null
            ? (e.delta! > 0 ? '+${e.delta}' : '${e.delta}')
            : (e.textValue != null ? '✎' : '');

        return Container(
          color: i % 2 == 0 ? _theme.surface : _theme.background,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: _tableRow(
            day:    _fmtDay(dt),
            date:   _fmtDate(dt),
            time:   _fmtTime(dt),
            symbol: btn?.symbol ?? (e.type == LogType.settings ? '⚙' : '?'),
            label:  e.type == LogType.settings
                ? (e.textValue ?? 'settings')
                : (btn?.getLabel(_tr.language) ?? e.buttonId ?? ''),
            delta:    deltaStr,
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
    final fs  = isHeader ? _theme.captionSize - 1 : _theme.captionSize;
    final col = isHeader ? _theme.inkFaint
        : deleted ? _theme.inkFaint : _theme.inkMedium;
    final deco = deleted && !isHeader
        ? TextDecoration.lineThrough : TextDecoration.none;

    // Sve kolone lijevo poravnane, fiksnih širina, bez prelamanja
    TextStyle st({Color? c, double? size, bool noStrike = false}) => TextStyle(
      fontFamily:  'monospace',
      fontSize:    size ?? fs,
      fontWeight:  isHeader ? FontWeight.w600 : FontWeight.normal,
      color:       c ?? col,
      decoration:  noStrike ? TextDecoration.none : deco,
    );

    Color dc = col;
    if (!isHeader) {
      if (delta.startsWith('+')) dc = _theme.positive;
      if (delta.startsWith('-')) dc = _theme.destructive;
    }

    Widget cell(double w, String text, {TextStyle? style, TextAlign align = TextAlign.left}) =>
        SizedBox(
          width: w,
          child: Text(text,
            style: style ?? st(),
            overflow: TextOverflow.clip,
            softWrap: false,      // NIKAD ne prelama u novi red
            textAlign: align,
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        cell(_wDay,   day),
        SizedBox(width: _gap),
        cell(_wDate,  date),
        SizedBox(width: _gap),
        cell(_wTime,  time),
        SizedBox(width: _gap),
        cell(_wSym,   symbol, style: st(size: isHeader ? fs : fs + 2, noStrike: true)),
        SizedBox(width: _gap),
        cell(_wLabel, label),
        SizedBox(width: _gap),
        cell(_wDelta, delta, style: st(c: dc, noStrike: true), align: TextAlign.right),
      ],
    );
  }
}

enum _Period { week, month, range }
