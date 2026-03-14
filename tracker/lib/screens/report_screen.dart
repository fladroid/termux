// lib/screens/report_screen.dart

import 'package:flutter/material.dart';
import '../models/button_model.dart';
import '../services/config_service.dart';
import '../services/db_service.dart';
import '../services/translation_service.dart';
import '../services/app_theme.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _config = ConfigService();
  final _db     = DbService();
  final _tr     = TranslationService();
  final _theme  = AppTheme();

  List<ButtonModel>  _buttons   = [];
  Map<String, int>   _cumulative = {};
  bool  _loading = true;
  _RPeriod _period = _RPeriod.week;
  DateTime _rangeFrom = DateTime.now().subtract(const Duration(days: 7));
  DateTime _rangeTo   = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final buttons = await _config.loadButtons();
    final now     = DateTime.now();

    DateTime from, to;
    if (_period == _RPeriod.range) {
      from = _rangeFrom;
      to   = _rangeTo;
    } else {
      final days = _period == _RPeriod.week ? 7 : 30;
      from = DateTime(now.year, now.month, now.day - days);
      to   = now;
    }

    final cumulative = await _db.getCumulativeValues(from: from, to: to);
    setState(() { _buttons = buttons; _cumulative = cumulative; _loading = false; });
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
      initialDate: _rangeTo,
      firstDate: from,
      lastDate:  DateTime(now.year + 2),
      helpText:  _tr.t('range_to'),
    );
    if (to == null || !mounted) return;
    setState(() { _rangeFrom = from; _rangeTo = to; _period = _RPeriod.range; });
    _load();
  }

  String _p(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime dt) => '${_p(dt.day)}.${_p(dt.month)}.${dt.year.toString().substring(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.background,
      body: SafeArea(child: Column(children: [
        _buildTopBar(),
        _buildPeriodSelector(),
        _loading
            ? const Expanded(child: Center(child: CircularProgressIndicator()))
            : Expanded(child: _buildContent()),
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
        Text(_tr.t('report_title'), style: TextStyle(
          fontFamily: 'monospace', fontSize: _theme.headerSize * 0.8,
          fontWeight: FontWeight.w600, color: _theme.ink)),
        const Spacer(),
        if (_period == _RPeriod.range)
          Text('${_fmtDate(_rangeFrom)} – ${_fmtDate(_rangeTo)}',
            style: TextStyle(fontFamily: 'monospace',
              fontSize: _theme.captionSize, color: _theme.inkLight)),
      ]),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _theme.border))),
      child: Row(children: [
        _periodBtn(_RPeriod.week,  _tr.t('period_7')),
        const SizedBox(width: 8),
        _periodBtn(_RPeriod.month, _tr.t('period_30')),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _pickRange,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _period == _RPeriod.range ? _theme.accent : _theme.surface,
              border: Border.all(color: _period == _RPeriod.range ? _theme.accent : _theme.border),
              borderRadius: BorderRadius.circular(4)),
            child: Text(_tr.t('period_range'), style: TextStyle(
              fontFamily: 'monospace', fontSize: _theme.captionSize,
              color: _period == _RPeriod.range ? _theme.accentText : _theme.inkLight)),
          ),
        ),
      ]),
    );
  }

  Widget _periodBtn(_RPeriod p, String label) {
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

  Widget _buildContent() {
    if (_buttons.isEmpty) {
      return Center(child: Text(_tr.t('no_entries_period'),
        style: TextStyle(fontFamily: 'monospace',
          fontSize: _theme.captionSize, color: _theme.inkFaint)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _buttons.length,
      itemBuilder: (ctx, i) {
        final btn   = _buttons[i];
        final total = _cumulative[btn.id] ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:  _theme.surface,
            border: Border.all(color: total > 0 ? _theme.accent : _theme.border),
            borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Text(btn.symbol, style: TextStyle(fontSize: _theme.symbolSize)),
            const SizedBox(width: 16),
            Expanded(child: Text(btn.getLabel(_tr.language), style: TextStyle(
              fontFamily: 'monospace', fontSize: _theme.bodySize, color: _theme.ink))),
            Text('$total', style: TextStyle(
              fontFamily: 'monospace',
              fontSize: _theme.headerSize,
              fontWeight: FontWeight.w600,
              color: total > 0 ? _theme.accent : _theme.inkFaint)),
          ]),
        );
      },
    );
  }
}

enum _RPeriod { week, month, range }
