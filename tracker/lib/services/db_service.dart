// lib/services/db_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/daily_value_model.dart';
import '../models/log_entry_model.dart';

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
    final path = join(await getDatabasesPath(), 'tracker_v2.db');
    return await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE daily_values (
          id        INTEGER PRIMARY KEY AUTOINCREMENT,
          button_id TEXT    NOT NULL,
          date      TEXT    NOT NULL,
          value     INTEGER NOT NULL DEFAULT 0,
          UNIQUE(button_id, date)
        )
      ''');
      await db.execute('''
        CREATE TABLE log (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp  TEXT    NOT NULL,
          type       TEXT    NOT NULL,
          button_id  TEXT,
          delta      INTEGER,
          text_value TEXT,
          deleted    INTEGER NOT NULL DEFAULT 0
        )
      ''');
    });
  }

  // ─── DAILY VALUES ─────────────────────────────────────────

  // Dohvati vrijednost za button na određeni datum
  Future<int> getValue(String buttonId, DateTime date) async {
    final db  = await database;
    final key = DailyValueModel.dateKey(date);
    final res = await db.query('daily_values',
      where: 'button_id = ? AND date = ?',
      whereArgs: [buttonId, key]);
    if (res.isEmpty) return 0;
    return DailyValueModel.fromMap(res.first).value;
  }

  // Sve vrijednosti za određeni datum
  Future<Map<String, int>> getValuesForDate(DateTime date) async {
    final db  = await database;
    final key = DailyValueModel.dateKey(date);
    final res = await db.query('daily_values',
      where: 'date = ?', whereArgs: [key]);
    return { for (var r in res)
      DailyValueModel.fromMap(r).buttonId:
      DailyValueModel.fromMap(r).value };
  }

  // Promijeni vrijednost za button (delta = +1 ili -1)
  Future<int> changeValue(String buttonId, DateTime date, int delta) async {
    final db       = await database;
    final key      = DailyValueModel.dateKey(date);
    final current  = await getValue(buttonId, date);
    final newValue = (current + delta).clamp(0, 999);

    await db.insert(
      'daily_values',
      {'button_id': buttonId, 'date': key, 'value': newValue},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return newValue;
  }

  // Kumulativne sume po buttonu za period
  Future<Map<String, int>> getCumulativeValues({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT button_id, SUM(value) as total
      FROM daily_values
      WHERE date BETWEEN ? AND ?
      GROUP BY button_id
    ''', [DailyValueModel.dateKey(from), DailyValueModel.dateKey(to)]);
    return { for (var r in res)
      r['button_id'] as String: (r['total'] as int? ?? 0) };
  }

  // Dnevne vrijednosti za period (za report po danu)
  Future<List<DailyValueModel>> getDailyValuesForRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;
    final res = await db.query('daily_values',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [DailyValueModel.dateKey(from), DailyValueModel.dateKey(to)],
      orderBy: 'date DESC, button_id ASC');
    return res.map((r) => DailyValueModel.fromMap(r)).toList();
  }

  // ─── LOG ──────────────────────────────────────────────────

  Future<LogEntryModel> addLog({
    required String type,
    String?  buttonId,
    int?     delta,
    String?  textValue,
  }) async {
    final db    = await database;
    final entry = LogEntryModel(
      timestamp: DateTime.now().toIso8601String(),
      type:      type,
      buttonId:  buttonId,
      delta:     delta,
      textValue: textValue,
    );
    final id = await db.insert('log', entry.toMap());
    return LogEntryModel.fromMap({...entry.toMap(), 'id': id});
  }

  Future<void> softDeleteLog(int id) async {
    final db = await database;
    await db.update('log', {'deleted': 1},
      where: 'id = ?', whereArgs: [id]);
  }

  // Log za period — aktivni unosi
  Future<List<LogEntryModel>> getLogForRange({
    required DateTime from,
    required DateTime to,
    bool includeDeleted = false,
  }) async {
    final db    = await database;
    final where = includeDeleted
        ? 'timestamp BETWEEN ? AND ?'
        : 'timestamp BETWEEN ? AND ? AND deleted = 0';
    final res = await db.query('log',
      where: where,
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'timestamp DESC');
    return res.map((r) => LogEntryModel.fromMap(r)).toList();
  }

  // Svi log unosi — za export
  Future<List<LogEntryModel>> getAllLog({bool includeDeleted = false}) async {
    final db    = await database;
    final where = includeDeleted ? null : 'deleted = 0';
    final res   = await db.query('log',
      where: where, orderBy: 'timestamp ASC');
    return res.map((r) => LogEntryModel.fromMap(r)).toList();
  }

  // Statistika baze
  Future<Map<String, dynamic>> getDbStats() async {
    final db = await database;
    final totalLog     = (await db.rawQuery('SELECT COUNT(*) as c FROM log'))[0]['c'] as int;
    final activeLog    = (await db.rawQuery('SELECT COUNT(*) as c FROM log WHERE deleted = 0'))[0]['c'] as int;
    final deletedLog   = totalLog - activeLog;
    final totalDaily   = (await db.rawQuery('SELECT COUNT(*) as c FROM daily_values'))[0]['c'] as int;
    return {
      'total_log':    totalLog,
      'active_log':   activeLog,
      'deleted_log':  deletedLog,
      'total_daily':  totalDaily,
    };
  }

  // Fizicko brisanje soft-deleted log unosa
  Future<int> cleanDeleted() async {
    final db = await database;
    return await db.delete('log', where: 'deleted = 1');
  }
}
