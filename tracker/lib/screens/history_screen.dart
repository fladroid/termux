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

  List<ButtonModel>   _buttons = [];
  List<LogEntryModel> _entries = [];
  bool    _loading = true;
  _Period _period  = _Period.week;
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
  String _fmtDate(DateTime dt) => '${_p(dt.day)}.${_p(dt.month)}.${dt.year}';
  String _fmtTime(DateTime dt) => '${_p(dt.hour)}:${_p(dt.minute)}';
  String _fmtDay(DateTime dt)  {
    final name = _tr.dayName(dt.weekday);
    return name.length >= 3 ? name.substring(0, 3) : name;
  }

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
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _theme.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text('‹', style: TextStyle(fontSize: 22, color: _theme.inkLight))),
          const SizedBox(width: 10),
          // FIX: naslov lijevo
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
        ],
      ),
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

  // FIX: širine kolona dovoljno velike da stane pun tekst
  // Dan(30) + Datum(72) + Vrij(40) + Sim(22) + Delta(28) = 192 + razmaci
  // Bilješka je poseban red ispod ako postoji
  static const double _wDay   = 30;
  static const double _wDate  = 72;  // dd.mm.yyyy = 10 znakova
  static const double _wTime  = 40;  // hh:mm = 5 znakova
  static const double _wSym   = 24;
  static const double _wDelta = 32;
  static const double _gap    =  6;

  Widget _buildTableHeader() {
    return Container(
      color: _theme.surface,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _theme.border, width: 1.5))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _hCell(_wDay,   _tr.t('col_day')),
          SizedBox(width: _gap),
          _hCell(_wDate,  _tr.t('col_date')),
          SizedBox(width: _gap),
          _hCell(_wTime,  _tr.t('col_time')),
          SizedBox(width: _gap),
          _hCell(_wSym,   _tr.t('col_symbol')),
          SizedBox(width: _gap),
          _hCell(_wDelta, _tr.t('col_delta'), align: TextAlign.right),
          SizedBox(width: _gap),
          Expanded(child: _hCell(0, _tr.t('col_label'))),
        ],
      ),
    );
  }

  Widget _hCell(double w, String text, {TextAlign align = TextAlign.left}) {
    final widget = Text(text,
      style: TextStyle(
        fontFamily: 'monospace', fontSize: _theme.captionSize - 1,
        fontWeight: FontWeight.w600, color: _theme.inkFaint),
      softWrap: false,
      overflow: TextOverflow.clip,
      textAlign: align,
    );
    return w > 0 ? SizedBox(width: w, child: widget) : widget;
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
        final isText    = e.type == LogType.text;
        final isDeleted = e.deleted;

        final deltaStr = e.delta != null
            ? (e.delta! > 0 ? '+${e.delta}' : '${e.delta}')
            : (isText ? '✎' : '');

        final labelStr = isText
            ? (btn?.getLabel(_tr.language) ?? e.buttonId ?? '')
            : (e.type == LogType.settings
                ? (e.textValue ?? 'settings')
                : (btn?.getLabel(_tr.language) ?? e.buttonId ?? ''));

        Color dc = _theme.inkMedium;
        if (deltaStr.startsWith('+')) dc = _theme.positive;
        if (deltaStr.startsWith('-')) dc = _theme.destructive;

        final baseSt = TextStyle(
          fontFamily:  'monospace',
          fontSize:    _theme.captionSize,
          color:       isDeleted ? _theme.inkFaint : _theme.inkMedium,
          decoration:  isDeleted ? TextDecoration.lineThrough : TextDecoration.none,
        );

        return Container(
          color: i % 2 == 0 ? _theme.surface : _theme.background,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Glavni red
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: _wDay,
                    child: Text(_fmtDay(dt), style: baseSt,
                      softWrap: false, overflow: TextOverflow.clip)),
                  SizedBox(width: _gap),
                  SizedBox(width: _wDate,
                    child: Text(_fmtDate(dt), style: baseSt,
                      softWrap: false, overflow: TextOverflow.clip)),
                  SizedBox(width: _gap),
                  SizedBox(width: _wTime,
                    child: Text(_fmtTime(dt), style: baseSt,
                      softWrap: false, overflow: TextOverflow.clip)),
                  SizedBox(width: _gap),
                  SizedBox(width: _wSym,
                    child: Text(
                      btn?.symbol ?? (e.type == LogType.settings ? '⚙' : '?'),
                      style: baseSt.copyWith(
                        fontSize: _theme.captionSize + 2,
                        decoration: TextDecoration.none),
                      softWrap: false)),
                  SizedBox(width: _gap),
                  SizedBox(width: _wDelta,
                    child: Text(deltaStr,
                      style: baseSt.copyWith(
                        color: dc, decoration: TextDecoration.none),
                      textAlign: TextAlign.right,
                      softWrap: false)),
                  SizedBox(width: _gap),
                  Expanded(child: Text(labelStr, style: baseSt,
                    softWrap: false, overflow: TextOverflow.ellipsis)),
                ],
              ),

              // FIX: sadržaj bilješke u zasebnom redu ispod
              if (isText && e.textValue != null && e.textValue!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: 4,
                    left: _wDay + _wDate + _wTime + _wSym + _gap * 3,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _theme.accent.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _theme.accent.withOpacity(0.2)),
                    ),
                    child: Text(
                      e.textValue!,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: _theme.captionSize,
                        color: _theme.inkMedium,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _Period { week, month, range }
