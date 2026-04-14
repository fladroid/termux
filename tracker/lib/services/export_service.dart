// lib/services/export_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/log_entry_model.dart';
import 'db_service.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final _db = DbService();

  Future<void> exportJson({bool includeDeleted = false}) async {
    final entries = await _db.getAllLog(includeDeleted: includeDeleted);
    final data = {
      'exported_at':    DateTime.now().toIso8601String(),
      'include_deleted': includeDeleted,
      'entries': entries.map((e) => e.toJson(includeDeleted: includeDeleted)).toList(),
    };
    await _shareFile(
      content:  const JsonEncoder.withIndent('  ').convert(data),
      filename: _filename('tracker_export', 'json'),
    );
  }

  Future<void> exportCsv({bool includeDeleted = false}) async {
    final entries = await _db.getAllLog(includeDeleted: includeDeleted);
    final buf = StringBuffer();
    buf.writeln(includeDeleted
        ? 'id,timestamp,type,button_id,delta,text_value,deleted'
        : 'id,timestamp,type,button_id,delta,text_value');
    for (final e in entries) {
      if (includeDeleted) {
        buf.writeln('${e.id},${e.timestamp},${e.type},${e.buttonId ?? ''},${e.delta ?? ''},${e.textValue ?? ''},${e.deleted ? 1 : 0}');
      } else {
        buf.writeln('${e.id},${e.timestamp},${e.type},${e.buttonId ?? ''},${e.delta ?? ''},${e.textValue ?? ''}');
      }
    }
    await _shareFile(
      content:  buf.toString(),
      filename: _filename('tracker_export', 'csv'),
    );
  }

  // Import JSON — restore semantika:
  // Za svaki dan koji postoji u fajlu: brisi stare podatke, upisuj nove.
  // Dani kojih nema u fajlu ostaju netaknuti.
  Future<ImportResult> importJson() async {
    final String? content;
    try {
      content = await _pickFile(extension: 'json');
    } catch (e) {
      return ImportResult.error(message: 'File picker error: ${e.toString()}');
    }
    if (content == null) return ImportResult.cancelled();
    try {
      final data  = jsonDecode(content) as Map<String, dynamic>;
      final list  = data['entries'] as List<dynamic>;
      final Map<String, Map<String, int>> dailyTotals = {};
      final Set<String> importDates = {};
      final List<LogEntryModel> entries = [];
      for (final item in list) {
        try {
          final e = LogEntryModel.fromMap(item as Map<String, dynamic>);
          final date = e.timestamp.length >= 10 ? e.timestamp.substring(0, 10) : '';
          if (date.isNotEmpty) importDates.add(date);
          entries.add(e);
          if (e.type == 'counter' && e.buttonId != null && e.delta != null && date.isNotEmpty) {
            dailyTotals.putIfAbsent(e.buttonId!, () => {})[date] =
                (dailyTotals[e.buttonId]?[date] ?? 0) + e.delta!;
          }
        } catch (_) {}
      }
      // Obrisi stare podatke za importovane dane, upisati nove
      await _db.rebuildDailyValues(dailyTotals, importDates.toList());
      int imported = 0, skipped = 0;
      for (final e in entries) {
        try {
          await _db.addLog(
            type: e.type, buttonId: e.buttonId,
            delta: e.delta, textValue: e.textValue,
            timestamp: DateTime.tryParse(e.timestamp),
          );
          imported++;
        } catch (_) { skipped++; }
      }
      return ImportResult.success(imported: imported, skipped: skipped);
    } catch (e) { return ImportResult.error(message: e.toString()); }
  }

  // Import CSV — ista restore semantika kao importJson
  Future<ImportResult> importCsv() async {
    final String? content;
    try {
      content = await _pickFile(extension: 'csv');
    } catch (e) {
      return ImportResult.error(message: 'File picker error: ${e.toString()}');
    }
    if (content == null) return ImportResult.cancelled();
    try {
      final lines = content.trim().split('\n').skip(1).toList();
      final Map<String, Map<String, int>> dailyTotals = {};
      final Set<String> importDates = {};
      final List<Map<String, dynamic>> entries = [];
      for (final line in lines) {
        try {
          final c = line.trim().split(',');
          if (c.length < 4) continue;
          final type      = c[2].trim();
          final buttonId  = c[3].trim().isEmpty ? null : c[3].trim();
          final delta     = c.length > 4 && c[4].trim().isNotEmpty ? int.tryParse(c[4].trim()) : null;
          final textValue = c.length > 5 && c[5].trim().isNotEmpty ? c[5].trim() : null;
          final timestamp = c[1].trim();
          final date      = timestamp.length >= 10 ? timestamp.substring(0, 10) : '';
          if (date.isNotEmpty) importDates.add(date);
          entries.add({'type': type, 'buttonId': buttonId, 'delta': delta,
                       'textValue': textValue, 'timestamp': timestamp});
          if (type == 'counter' && buttonId != null && delta != null && date.isNotEmpty) {
            dailyTotals.putIfAbsent(buttonId, () => {})[date] =
                (dailyTotals[buttonId]?[date] ?? 0) + delta;
          }
        } catch (_) {}
      }
      // Obrisi stare podatke za importovane dane, upisati nove
      await _db.rebuildDailyValues(dailyTotals, importDates.toList());
      int imported = 0, skipped = 0;
      for (final e in entries) {
        try {
          await _db.addLog(
            type: e['type'], buttonId: e['buttonId'],
            delta: e['delta'], textValue: e['textValue'],
            timestamp: DateTime.tryParse(e['timestamp']),
          );
          imported++;
        } catch (_) { skipped++; }
      }
      return ImportResult.success(imported: imported, skipped: skipped);
    } catch (e) { return ImportResult.error(message: e.toString()); }
  }

  Future<void> _shareFile({required String content, required String filename}) async {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)], subject: filename);
  }

  Future<String?> _pickFile({required String extension}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: [extension]);
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    return await File(path).readAsString();
  }

  String _filename(String base, String ext) {
    final n = DateTime.now();
    return '${base}_${n.year}${_p(n.month)}${_p(n.day)}_${_p(n.hour)}${_p(n.minute)}.$ext';
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}

class ImportResult {
  final bool success, cancelled;
  final int imported, skipped;
  final String? errorMessage;

  ImportResult._({required this.success, required this.cancelled,
    this.imported = 0, this.skipped = 0, this.errorMessage});

  factory ImportResult.success({required int imported, required int skipped}) =>
      ImportResult._(success: true,  cancelled: false, imported: imported, skipped: skipped);
  factory ImportResult.cancelled() =>
      ImportResult._(success: false, cancelled: true);
  factory ImportResult.error({required String message}) =>
      ImportResult._(success: false, cancelled: false, errorMessage: message);
}
