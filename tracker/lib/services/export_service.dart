// lib/services/export_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/entry_model.dart';
import 'db_service.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final DbService _db = DbService();

  Future<void> exportJson({bool includeDeleted = false}) async {
    final entries = includeDeleted ? await _db.getAll() : await _db.getAllActive();
    final data = {
      'exported_at': DateTime.now().toIso8601String(),
      'include_deleted': includeDeleted,
      'entries': entries.map((e) => e.toJson(includeDeleted: includeDeleted)).toList(),
    };
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    await _shareFile(content: jsonString, filename: _filename('tracker_export', 'json'));
  }

  Future<void> exportCsv({bool includeDeleted = false}) async {
    final entries = includeDeleted ? await _db.getAll() : await _db.getAllActive();
    final buffer = StringBuffer();
    if (includeDeleted) {
      buffer.writeln('id,button_id,timestamp,deleted');
    } else {
      buffer.writeln('id,button_id,timestamp');
    }
    for (final e in entries) {
      if (includeDeleted) {
        buffer.writeln('${e.id},${e.buttonId},${e.timestamp.toIso8601String()},${e.deleted ? 1 : 0}');
      } else {
        buffer.writeln('${e.id},${e.buttonId},${e.timestamp.toIso8601String()}');
      }
    }
    await _shareFile(content: buffer.toString(), filename: _filename('tracker_export', 'csv'));
  }

  Future<ImportResult> importJson() async {
    final content = await _pickFile(extension: 'json');
    if (content == null) return ImportResult.cancelled();
    try {
      final data = jsonDecode(content) as Map<String, dynamic>;
      final list = data['entries'] as List<dynamic>;
      int imported = 0, skipped = 0;
      for (final item in list) {
        try {
          final entry = EntryModel.fromMap(item as Map<String, dynamic>);
          await _db.insert(entry.buttonId);
          imported++;
        } catch (_) { skipped++; }
      }
      return ImportResult.success(imported: imported, skipped: skipped);
    } catch (e) {
      return ImportResult.error(message: e.toString());
    }
  }

  Future<ImportResult> importCsv() async {
    final content = await _pickFile(extension: 'csv');
    if (content == null) return ImportResult.cancelled();
    try {
      final lines = content.trim().split('\n');
      if (lines.isEmpty) return ImportResult.error(message: 'Empty file');
      final dataLines = lines.skip(1).toList();
      int imported = 0, skipped = 0;
      for (final line in dataLines) {
        try {
          final cols = line.trim().split(',');
          if (cols.length < 3) { skipped++; continue; }
          await _db.insert(cols[1].trim());
          imported++;
        } catch (_) { skipped++; }
      }
      return ImportResult.success(imported: imported, skipped: skipped);
    } catch (e) {
      return ImportResult.error(message: e.toString());
    }
  }

  Future<void> _shareFile({required String content, required String filename}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)], subject: filename);
  }

  Future<String?> _pickFile({required String extension}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [extension],
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    return await File(path).readAsString();
  }

  String _filename(String base, String ext) {
    final now = DateTime.now();
    final stamp = '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}';
    return '${base}_$stamp.$ext';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

class ImportResult {
  final bool success;
  final bool cancelled;
  final int imported;
  final int skipped;
  final String? errorMessage;

  ImportResult._({
    required this.success,
    required this.cancelled,
    this.imported = 0,
    this.skipped = 0,
    this.errorMessage,
  });

  factory ImportResult.success({required int imported, required int skipped}) =>
      ImportResult._(success: true, cancelled: false, imported: imported, skipped: skipped);
  factory ImportResult.cancelled() =>
      ImportResult._(success: false, cancelled: true);
  factory ImportResult.error({required String message}) =>
      ImportResult._(success: false, cancelled: false, errorMessage: message);
}
