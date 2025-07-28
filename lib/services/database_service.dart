import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/milk_entry.dart';
import '../models/pee_entry.dart';
import '../models/poop_entry.dart';
import '../models/session.dart';
import '../models/vitamin_entry.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('baby_daily.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 10, // Upgraded version for setting null vitamin types to AD
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create sessions table with only core fields
    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        wakeUpTime TEXT NOT NULL,
        sleepTime TEXT,
        sessionPhotoPath TEXT,
        hasSessionPhoto INTEGER NOT NULL,
        isClosed INTEGER NOT NULL
      )
    ''');

    // Create pee_entries table
    await db.execute('''
      CREATE TABLE pee_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        amount TEXT,
        remarks TEXT,
        time TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');

    // Create poop_entries table
    await db.execute('''
      CREATE TABLE poop_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        amount TEXT,
        consistency TEXT,
        color TEXT,
        time TEXT NOT NULL,
        photo_path TEXT,
        has_photo INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');

    // Create milk_entries table
    await db.execute('''
      CREATE TABLE milk_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        amount INTEGER,
        time TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');

    // Create vitamin_entries table
    await db.execute('''
      CREATE TABLE vitamin_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        time TEXT NOT NULL,
        type TEXT,
        notes TEXT,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // All users have been migrated to version 10
    // Future migrations can be added here as needed

    // Example for future migrations:
    // if (oldVersion < 11) {
    //   // Add new migration logic here
    // }
  }

  Future<Session> createSession(Session session) async {
    final db = await instance.database;
    final id = await db.insert('sessions', session.toMap());
    return session.copyWith(id: id);
  }

  Future<Session?> getSession(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final session = Session.fromMap(maps.first);
      return loadSessionWithEntries(session);
    }
    return null;
  }

  Future<List<Session>> getAllSessions() async {
    final db = await instance.database;
    final result = await db.query('sessions', orderBy: 'wakeUpTime DESC');

    final sessions = result.map((json) => Session.fromMap(json)).toList();
    final sessionsWithEntries =
        await Future.wait(sessions.map((session) => loadSessionWithEntries(session)));

    return sessionsWithEntries;
  }

  /// Gets all sessions that overlap with the date range for analytics
  /// Includes sessions where:
  /// - sleepTime is after the start time OR sleepTime is null (open session)
  /// - wakeUpTime is before the end time
  Future<List<Session>> getSessionsForAnalytics(DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.query(
      'sessions',
      where: '(sleepTime IS NULL OR sleepTime > ?) AND wakeUpTime < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'wakeUpTime DESC',
    );

    final sessions = result.map((json) => Session.fromMap(json)).toList();
    final sessionsWithEntries =
        await Future.wait(sessions.map((session) => loadSessionWithEntries(session)));

    return sessionsWithEntries;
  }

  Future<int> updateSession(Session session) async {
    final db = await instance.database;
    return db.update(
      'sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<int> deleteSession(int id) async {
    final db = await instance.database;
    return await db.delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Pee Entry Methods
  Future<PeeEntry> createPeeEntry(PeeEntry entry) async {
    final db = await instance.database;
    final id = await db.insert('pee_entries', entry.toMap());
    return entry.copyWith(id: id);
  }

  Future<List<PeeEntry>> getPeeEntriesForSession(int sessionId) async {
    final db = await instance.database;
    final result = await db.query('pee_entries',
        where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'time DESC');
    return result.map((json) => PeeEntry.fromMap(json)).toList();
  }

  Future<int> deletePeeEntry(int id) async {
    final db = await instance.database;
    return await db.delete(
      'pee_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSessionPeeEntries(int sessionId, List<PeeEntry> entries) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Delete all existing entries
      await txn.delete(
        'pee_entries',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      // Insert new entries
      for (final entry in entries) {
        await txn.insert('pee_entries', entry.toMap());
      }
    });
  }

  // Poop Entry Methods
  Future<PoopEntry> createPoopEntry(PoopEntry entry) async {
    final db = await instance.database;
    final id = await db.insert('poop_entries', entry.toMap());
    return entry.copyWith(id: id);
  }

  Future<List<PoopEntry>> getPoopEntriesForSession(int sessionId) async {
    final db = await instance.database;
    final result = await db.query('poop_entries',
        where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'time DESC');
    return result.map((json) => PoopEntry.fromMap(json)).toList();
  }

  Future<int> deletePoopEntry(int id) async {
    final db = await instance.database;
    return await db.delete(
      'poop_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSessionPoopEntries(int sessionId, List<PoopEntry> entries) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Delete all existing entries
      await txn.delete(
        'poop_entries',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      // Insert new entries
      for (final entry in entries) {
        await txn.insert('poop_entries', entry.toMap());
      }
    });
  }

  // Milk Entry Methods
  Future<MilkEntry> createMilkEntry(MilkEntry entry) async {
    final db = await instance.database;
    final id = await db.insert('milk_entries', entry.toMap());
    return entry.copyWith(id: id);
  }

  Future<List<MilkEntry>> getMilkEntriesForSession(int sessionId) async {
    final db = await instance.database;
    final result = await db.query('milk_entries',
        where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'time ASC');
    return result.map((json) => MilkEntry.fromMap(json)).toList();
  }

  Future<int> deleteMilkEntry(int id) async {
    final db = await instance.database;
    return await db.delete(
      'milk_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSessionMilkEntries(int sessionId, List<MilkEntry> entries) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Delete all existing entries
      await txn.delete(
        'milk_entries',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      // Insert new entries
      for (final entry in entries) {
        await txn.insert('milk_entries', entry.toMap());
      }
    });
  }

  // Vitamin Entry Methods
  Future<VitaminEntry> createVitaminEntry(VitaminEntry entry) async {
    final db = await instance.database;
    final id = await db.insert('vitamin_entries', entry.toMap());
    return entry.copyWith(id: id);
  }

  Future<List<VitaminEntry>> getVitaminEntriesForSession(int sessionId) async {
    final db = await instance.database;
    final result = await db.query('vitamin_entries',
        where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'time ASC');
    return result.map((json) => VitaminEntry.fromMap(json)).toList();
  }

  Future<int> deleteVitaminEntry(int id) async {
    final db = await instance.database;
    return await db.delete(
      'vitamin_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSessionVitaminEntries(int sessionId, List<VitaminEntry> entries) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Delete all existing entries
      await txn.delete(
        'vitamin_entries',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      // Insert new entries
      for (final entry in entries) {
        await txn.insert('vitamin_entries', entry.toMap());
      }
    });
  }

  /// Clears all data from the database
  Future<void> clearAllSessions() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Delete all entries from all tables
      await txn.delete('vitamin_entries');
      await txn.delete('milk_entries');
      await txn.delete('poop_entries');
      await txn.delete('pee_entries');
      await txn.delete('sessions');
    });
  }

  Future<void> restoreSession(Session session) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Insert session
      final sessionId = await txn.insert('sessions', {
        'wakeUpTime': session.wakeUpTime.toIso8601String(),
        'sleepTime': session.sleepTime?.toIso8601String(),
        'sessionPhotoPath': session.sessionPhotoPath,
        'hasSessionPhoto': session.hasSessionPhoto ? 1 : 0,
        'isClosed': session.isClosed ? 1 : 0,
      });

      // Insert pee entries
      for (final entry in session.peeEntries) {
        await txn.insert('pee_entries', {
          'session_id': sessionId,
          'amount': entry.amount?.index,
          'remarks': entry.remarks,
          'time': entry.time.toIso8601String(),
        });
      }

      // Insert poop entries
      for (final entry in session.poopEntries) {
        await txn.insert('poop_entries', {
          'session_id': sessionId,
          'amount': entry.amount?.index,
          'consistency': entry.consistency?.index,
          'color': entry.color?.index,
          'time': entry.time.toIso8601String(),
          'photo_path': entry.photoPath,
          'has_photo': entry.hasPhoto ? 1 : 0,
        });
      }

      // Insert milk entries
      for (final entry in session.milkEntries) {
        await txn.insert('milk_entries', {
          'session_id': sessionId,
          'amount': entry.amount,
          'time': entry.time.toIso8601String(),
        });
      }

      // Insert vitamin entries
      for (final entry in session.vitaminEntries) {
        await txn.insert('vitamin_entries', {
          'session_id': sessionId,
          'time': entry.time.toIso8601String(),
          'type': entry.type?.name,
          'notes': entry.notes,
        });
      }
    });
  }

  Future<Session> loadSessionWithEntries(Session session) async {
    if (session.id == null) return session;

    final peeEntries = await getPeeEntriesForSession(session.id!);
    final poopEntries = await getPoopEntriesForSession(session.id!);
    final milkEntries = await getMilkEntriesForSession(session.id!);
    final vitaminEntries = await getVitaminEntriesForSession(session.id!);

    return session.copyWith(
      peeEntries: peeEntries,
      poopEntries: poopEntries,
      milkEntries: milkEntries,
      vitaminEntries: vitaminEntries,
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
