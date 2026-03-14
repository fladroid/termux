// lib/services/db_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/entry_model.dart';

class DbService {
  static final DbService _instance = DbService._internal();
  factory DbService() => _instance;
  DbService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tracker.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            button_id TEXT    NOT NULL,
            timestamp TEXT    NOT NULL,
            deleted   INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<EntryModel> insertAt(String buttonId, DateTime timestamp) async {
    final entry = EntryModel(
      buttonId: buttonId,
      timestamp: timestamp,
    );
    final db = await database;
    final id = await db.insert('entries', entry.toMap());
    return entry.copyWith(id: id);
  }

  Future<EntryModel> insert(String buttonId) async {
    final entry = EntryModel(
      buttonId: buttonId,
      timestamp: DateTime.now(),
    );
    final db = await database;
    final id = await db.insert('entries', entry.toMap());
    return entry.copyWith(id: id);
  }

  Future<void> softDelete(int id) async {
    final db = await database;
    await db.update(
      'entries',
      {'deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<EntryModel>> getEntriesForDate(DateTime date) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    final maps = await db.query(
      'entries',
      where: 'timestamp BETWEEN ? AND ? AND deleted = 0',
      whereArgs: [start, end],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => EntryModel.fromMap(m)).toList();
  }

  Future<List<EntryModel>> getEntriesForRange(DateTime from, DateTime to) async {
    final db = await database;
    final maps = await db.query(
      'entries',
      where: 'timestamp BETWEEN ? AND ? AND deleted = 0',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => EntryModel.fromMap(m)).toList();
  }

  Future<Map<String, int>> countByButton({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT button_id, COUNT(*) as count
      FROM entries
      WHERE timestamp BETWEEN ? AND ?
      AND deleted = 0
      GROUP BY button_id
    ''', [from.toIso8601String(), to.toIso8601String()]);
    return {
      for (var row in maps)
        row['button_id'] as String: row['count'] as int
    };
  }

  Future<List<EntryModel>> getAllActive() async {
    final db = await database;
    final maps = await db.query(
      'entries',
      where: 'deleted = 0',
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => EntryModel.fromMap(m)).toList();
  }

  Future<List<EntryModel>> getAll() async {
    final db = await database;
    final maps = await db.query('entries', orderBy: 'timestamp ASC');
    return maps.map((m) => EntryModel.fromMap(m)).toList();
  }
}
