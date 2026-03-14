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

  Future<ImportResult> importJson() async {
    final content = await _pickFile(extension: 'json');
    if (content == null) return ImportResult.cancelled();
    try {
      final data  = jsonDecode(content) as Map<String, dynamic>;
      final list  = data['entries'] as List<dynamic>;
      int imported = 0, skipped = 0;
      for (final item in list) {
        try {
          final e = LogEntryModel.fromMap(item as Map<String, dynamic>);
          await _db.addLog(
            type: e.type, buttonId: e.buttonId,
            delta: e.delta, textValue: e.textValue,
          );
          imported++;
        } catch (_) { skipped++; }
      }
      return ImportResult.success(imported: imported, skipped: skipped);
    } catch (e) { return ImportResult.error(message: e.toString()); }
  }

  Future<ImportResult> importCsv() async {
    final content = await _pickFile(extension: 'csv');
    if (content == null) return ImportResult.cancelled();
    try {
      final lines = content.trim().split('\n').skip(1).toList();
      int imported = 0, skipped = 0;
      for (final line in lines) {
        try {
          final c = line.trim().split(',');
          if (c.length < 4) { skipped++; continue; }
          await _db.addLog(
            type:      c[2].trim(),
            buttonId:  c[3].trim().isEmpty ? null : c[3].trim(),
            delta:     c.length > 4 && c[4].trim().isNotEmpty ? int.parse(c[4].trim()) : null,
            textValue: c.length > 5 && c[5].trim().isNotEmpty ? c[5].trim() : null,
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
