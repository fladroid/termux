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
  bool    _sortDesc = true; // true = najnoviji gore
  DateTime _rangeFrom = DateTime.now().subtract(const Duration(days: 7));
  DateTime _rangeTo   = DateTime.now();

  // Kolone unutar dana: Vrijeme | Simbol | +/- | Oznaka
  static const Map<int, TableColumnWidth> _colWidths = {
    0: FlexColumnWidth(1.6),  // Vrijeme (hh:mm)
    1: FlexColumnWidth(1.0),  // Simbol
    2: FlexColumnWidth(1.2),  // +/-
    3: FlexColumnWidth(4.0),  // Oznaka
  };

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
  String _dateKey(DateTime dt)  => '${dt.year}-${_p(dt.month)}-${_p(dt.day)}';
  String _fmtDate(DateTime dt) => '${_p(dt.day)}.${_p(dt.month)}.${dt.year.toString().substring(2)}';
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
          Text(_tr.t('history_title'), style: TextStyle(
            fontFamily: 'monospace', fontSize: _theme.headerSize * 0.8,
            fontWeight: FontWeight.w600, color: _theme.ink)),
          const Spacer(),
          if (_period == _Period.range)
            Text('${_fmtDate(_rangeFrom)}--${_fmtDate(_rangeTo)}',
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
        const Spacer(),
        // Sort gumb ↓ / ↑
        GestureDetector(
          onTap: () => setState(() => _sortDesc = !_sortDesc),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _theme.surface,
              border: Border.all(color: _theme.border),
              borderRadius: BorderRadius.circular(4)),
            child: Text(_sortDesc ? '↓' : '↑', style: TextStyle(
              fontFamily: 'monospace', fontSize: _theme.captionSize,
              color: _theme.ink)),
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

  // Header uklonjen — grupiranje po danima

  Widget _hCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(text,
        style: TextStyle(
          fontFamily: 'monospace', fontSize: _theme.captionSize,
          fontWeight: FontWeight.bold, color: _theme.ink),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTable() {
    if (_entries.isEmpty) {
      return Center(child: Text(_tr.t('no_entries_period'),
        style: TextStyle(fontFamily: 'monospace',
          fontSize: _theme.captionSize, color: _theme.inkFaint)));
    }

    // Grupiranje po danu
    final Map<String, List<LogEntryModel>> byDay = {};
    for (final e in _entries) {
      final key = _dateKey(e.dateTime);
      byDay.putIfAbsent(key, () => []).add(e);
    }

    // Sortirani dani
    final days = byDay.keys.toList()
      ..sort((a, b) => _sortDesc ? b.compareTo(a) : a.compareTo(b));

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: days.map((dayKey) {
            final dayEntries = byDay[dayKey]!;
            // Sort unutar dana
            dayEntries.sort((a, b) => _sortDesc
                ? b.dateTime.compareTo(a.dateTime)
                : a.dateTime.compareTo(b.dateTime));
            final dt = dayEntries.first.dateTime;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Heading dana
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: _theme.surface,
                    border: Border(
                      bottom: BorderSide(color: _theme.accent.withValues(alpha: 0.4), width: 1.5),
                    ),
                  ),
                  child: Row(children: [
                    Text(_fmtDay(dt), style: TextStyle(
                      fontFamily: 'monospace', fontSize: _theme.captionSize,
                      fontWeight: FontWeight.bold, color: _theme.ink)),
                    const SizedBox(width: 10),
                    Text(_fmtDate(dt), style: TextStyle(
                      fontFamily: 'monospace', fontSize: _theme.captionSize,
                      fontWeight: FontWeight.bold, color: _theme.ink)),
                    const Spacer(),
                    Text('${dayEntries.length}', style: TextStyle(
                      fontFamily: 'monospace', fontSize: _theme.captionSize,
                      color: _theme.inkFaint)),
                  ]),
                ),
                // Tabela unosa za taj dan
                Table(
                  columnWidths: _colWidths,
                  border: TableBorder(
                    verticalInside: BorderSide(color: _theme.border, width: 1),
                    horizontalInside: BorderSide(color: _theme.border.withValues(alpha: 0.4), width: 0.5),
                  ),
                  children: [
                    // Header red
                    TableRow(
                      decoration: BoxDecoration(color: _theme.surface),
                      children: [
                        _hCell(_tr.t('col_time')),
                        _hCell(_tr.t('col_symbol')),
                        _hCell(_tr.t('col_delta')),
                        _hCell(_tr.t('col_label')),
                      ],
                    ),
                    ...dayEntries.asMap().entries.expand((entry) {
                    final i   = entry.key;
                    final e   = entry.value;
                    final btn = _buttonFor(e.buttonId);
                    final isText    = e.type == LogType.text;
                    final isDeleted = e.deleted;

                    final deltaStr = e.delta != null
                        ? (e.delta! > 0 ? '+${e.delta}' : '${e.delta}')
                        : (isText ? 'T' : 'S');

                    final labelStr = isText
                        ? (btn?.getLabel(_tr.language) ?? e.buttonId ?? '')
                        : (e.type == LogType.settings
                            ? (e.textValue ?? 'settings')
                            : (btn?.getLabel(_tr.language) ?? e.buttonId ?? ''));

                    Color dc = _theme.inkMedium;
                    if (deltaStr.startsWith('+')) dc = _theme.positive;
                    if (deltaStr.startsWith('-')) dc = _theme.destructive;

                    final baseSt = TextStyle(
                      fontFamily: 'monospace',
                      fontSize:   _theme.captionSize,
                      color:      isDeleted ? _theme.inkFaint : _theme.inkMedium,
                      decoration: isDeleted ? TextDecoration.lineThrough : TextDecoration.none,
                    );

                    final bgColor = i % 2 == 0 ? _theme.background : _theme.surface;

                    final mainRow = TableRow(
                      decoration: BoxDecoration(color: bgColor),
                      children: [
                        _dCell(_fmtTime(e.dateTime), baseSt),
                        _dCell(
                          btn?.symbol ?? (e.type == LogType.settings ? 'S' : '?'),
                          baseSt.copyWith(fontSize: _theme.captionSize + 2, decoration: TextDecoration.none),
                        ),
                        _dCell(deltaStr, baseSt.copyWith(color: dc, decoration: TextDecoration.none)),
                        _dCell(
                          isText && e.textValue != null && e.textValue!.isNotEmpty
                              ? e.textValue!
                              : labelStr,
                          baseSt, overflow: TextOverflow.ellipsis),
                      ],
                    );
                    return [mainRow];
                  }).toList(),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _dCell(String text, TextStyle style, {TextOverflow overflow = TextOverflow.clip}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(text, style: style, overflow: overflow, softWrap: false),
    );
  }
}

enum _Period { week, month, range }
