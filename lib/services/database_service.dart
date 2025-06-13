import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/session.dart';
import '../models/pee_entry.dart';
import '../models/poop_entry.dart';
import '../models/milk_entry.dart';

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
      version: 4,
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
        vitaminAD INTEGER NOT NULL,
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
        amount INTEGER NOT NULL,
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
        amount INTEGER NOT NULL,
        consistency INTEGER NOT NULL,
        color INTEGER NOT NULL,
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
        amount INTEGER NOT NULL,
        time TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      // Create new tables
      await db.execute('''
        CREATE TABLE pee_entries(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER NOT NULL,
          amount INTEGER NOT NULL,
          remarks TEXT,
          time TEXT NOT NULL,
          FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE poop_entries(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER NOT NULL,
          amount INTEGER NOT NULL,
          consistency INTEGER NOT NULL,
          color INTEGER NOT NULL,
          time TEXT NOT NULL,
          photo_path TEXT,
          has_photo INTEGER NOT NULL,
          FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE milk_entries(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER NOT NULL,
          amount INTEGER NOT NULL,
          time TEXT NOT NULL,
          FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
        )
      ''');

      // Copy existing data to new tables
      await db.execute('''
        INSERT INTO pee_entries (session_id, amount, remarks, time)
        SELECT id, pee, peeRemarks, COALESCE(peeTime, wakeUpTime)
        FROM sessions
        WHERE pee != 0
      ''');

      await db.execute('''
        INSERT INTO poop_entries (session_id, amount, consistency, color, time, photo_path, has_photo)
        SELECT id, poopAmount, poopConsistency, poopColor, COALESCE(poopTime, wakeUpTime), abnormalPoopPhotoPath, hasAbnormalPoopPhoto
        FROM sessions
        WHERE poopAmount != 0
      ''');

      await db.execute('''
        INSERT INTO milk_entries (session_id, amount, time)
        SELECT id, milkIntake, COALESCE(milkTime, wakeUpTime)
        FROM sessions
        WHERE milkIntake != 0
      ''');

      // Create temporary table for sessions
      await db.execute('CREATE TEMPORARY TABLE sessions_backup(id, wakeUpTime, vitaminAD, sleepTime, sessionPhotoPath, hasSessionPhoto, isClosed)');
      
      // Copy data to backup
      await db.execute('''
        INSERT INTO sessions_backup 
        SELECT id, wakeUpTime, vitaminAD, sleepTime, sessionPhotoPath, hasSessionPhoto, isClosed
        FROM sessions
      ''');

      // Drop old sessions table
      await db.execute('DROP TABLE sessions');

      // Create new sessions table
      await db.execute('''
        CREATE TABLE sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          wakeUpTime TEXT NOT NULL,
          vitaminAD INTEGER NOT NULL,
          sleepTime TEXT,
          sessionPhotoPath TEXT,
          hasSessionPhoto INTEGER NOT NULL,
          isClosed INTEGER NOT NULL
        )
      ''');

      // Restore data
      await db.execute('''
        INSERT INTO sessions 
        SELECT id, wakeUpTime, vitaminAD, sleepTime, sessionPhotoPath, hasSessionPhoto, isClosed
        FROM sessions_backup
      ''');

      // Drop backup
      await db.execute('DROP TABLE sessions_backup');
    }
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
    final sessionsWithEntries = await Future.wait(
      sessions.map((session) => loadSessionWithEntries(session))
    );
    
    return sessionsWithEntries;
  }

  Future<List<Session>> getSessionsInRange(DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.query(
      'sessions',
      where: 'wakeUpTime BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'wakeUpTime DESC',
    );
    
    final sessions = result.map((json) => Session.fromMap(json)).toList();
    final sessionsWithEntries = await Future.wait(
      sessions.map((session) => loadSessionWithEntries(session))
    );
    
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
    final result = await db.query(
      'pee_entries',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'time DESC'
    );
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
    final result = await db.query(
      'poop_entries',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'time DESC'
    );
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
    final result = await db.query(
      'milk_entries',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'time ASC'
    );
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

  Future<void> updateMilkEntry(MilkEntry entry) async {
    final db = await instance.database;
    await db.update(
      'milk_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
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

  // Helper method to load all entries for a session
  Future<Session> loadSessionWithEntries(Session session) async {
    if (session.id == null) return session;

    final peeEntries = await getPeeEntriesForSession(session.id!);
    final poopEntries = await getPoopEntriesForSession(session.id!);
    final milkEntries = await getMilkEntriesForSession(session.id!);

    return session.copyWith(
      peeEntries: peeEntries,
      poopEntries: poopEntries,
      milkEntries: milkEntries,
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
