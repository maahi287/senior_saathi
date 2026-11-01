
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;

    _database = await _initDB('senior_saathi.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE reminders RENAME TO reminders_old',
      );

      await _createDB(db, newVersion);

      await db.execute('''
        INSERT INTO reminders (
          id, title, details, type, dateTime, isTaken
        )
        SELECT
          CAST(id AS TEXT),
          title,
          COALESCE(details, ''),
          COALESCE(type, ''),
          dateTime,
          isTaken
        FROM reminders_old
      ''');

      await db.execute('DROP TABLE reminders_old');
    }

    if (oldVersion < 3) {
      await _createRecognizedDevicesTable(db);
    }
  }

  Future<void> _createRecognizedDevicesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recognized_devices (
        id TEXT PRIMARY KEY,
        deviceModel TEXT NOT NULL,
        manufacturer TEXT NOT NULL,
        brand TEXT NOT NULL,
        deviceType TEXT NOT NULL,
        osName TEXT NOT NULL,
        osVersion TEXT NOT NULL,
        hardware TEXT NOT NULL,
        isPhysicalDevice INTEGER NOT NULL DEFAULT 1,
        lastActive TEXT NOT NULL,
        elderCode TEXT NOT NULL DEFAULT '',
        userName TEXT NOT NULL DEFAULT '',
        userPhone TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        details TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL DEFAULT '',
        dateTime TEXT NOT NULL,
        isTaken INTEGER NOT NULL DEFAULT 0,
        scheduleType TEXT NOT NULL DEFAULT 'daily',
        selectedDays TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await _createRecognizedDevicesTable(db);
  }
  
  // Insert a new reminder
  Future<int> insertReminder(Map<String, dynamic> reminder) async {
    if (kIsWeb) return 0;
    final db = await database;
    if (db == null) return 0;
    return await db.insert(
      'reminders',
      reminder,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all reminders
  Future<List<Map<String, dynamic>>> getReminders() async {
    if (kIsWeb) return [];
    final db = await database;
    if (db == null) return [];
    return await db.query(
      'reminders',
      orderBy: 'dateTime ASC',
    );
  }

  // Update an existing reminder
  Future<int> updateReminder(
    String id,
    Map<String, dynamic> reminder,
  ) async {
    if (kIsWeb) return 0;
    final db = await database;
    if (db == null) return 0;
    return await db.update(
      'reminders',
      reminder,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete a reminder
  Future<int> deleteReminder(String id) async {
    if (kIsWeb) return 0;
    final db = await database;
    if (db == null) return 0;
    return await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =====================================================
  // RECOGNIZED DEVICES MANAGEMENT
  // =====================================================

  /// Insert or replace a recognized device
  Future<int> insertRecognizedDevice(Map<String, dynamic> device) async {
    if (kIsWeb) return 0;
    final db = await database;
    if (db == null) return 0;
    return await db.insert(
      'recognized_devices',
      device,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all recognized devices ordered by last active descending
  Future<List<Map<String, dynamic>>> getRecognizedDevices() async {
    if (kIsWeb) return [];
    final db = await database;
    if (db == null) return [];
    return await db.query(
      'recognized_devices',
      orderBy: 'lastActive DESC',
    );
  }

  /// Delete a recognized device by id
  Future<int> deleteRecognizedDevice(String id) async {
    if (kIsWeb) return 0;
    final db = await database;
    if (db == null) return 0;
    return await db.delete(
      'recognized_devices',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}