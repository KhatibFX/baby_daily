import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/enums/pee_enums.dart';
import '../models/enums/poop_enums.dart';
import '../models/enums/vitamin_enums.dart';
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
      version: 9, // Upgraded version for converting enums to text
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
    if (oldVersion < 5) {
      // Add vitamin_entries table if upgrading from version 4
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
    if (oldVersion < 6) {
      // Migrate legacy vitaminAD to vitamin_entries
      final sessions = await db.query('sessions', where: 'vitaminAD = ?', whereArgs: [1]);
      for (final session in sessions) {
        final sessionId = session['id'] as int;
        final wakeUpTime = session['wakeUpTime'] as String;
        // Find first milk entry time for this session
        final milkEntries = await db.query(
          'milk_entries',
          where: 'session_id = ?',
          whereArgs: [sessionId],
          orderBy: 'time ASC',
          limit: 1,
        );
        String vitaminTime = wakeUpTime;
        if (milkEntries.isNotEmpty) {
          vitaminTime = milkEntries.first['time'] as String;
        }
        // Insert vitamin entry (type=0 for AD, notes='')
        await db.insert('vitamin_entries', {
          'session_id': sessionId,
          'time': vitaminTime,
          'type': 'ad',
          'notes': null,
        });
      }
    }
    if (oldVersion < 7) {
      // Migrate pee and poop entries due to removal of 'na' from enums
      // First we need to recreate tables to allow NULL amounts since SQLite doesn't support dropping constraints

      await db.transaction((txn) async {
        // Recreate pee_entries table with nullable amount
        await txn.execute('ALTER TABLE pee_entries RENAME TO pee_entries_old');
        await txn.execute('''
          CREATE TABLE pee_entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            amount INTEGER,
            remarks TEXT,
            time TEXT NOT NULL,
            FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
          )
        ''');

        // Copy data from old table to new table
        await txn.execute('''
          INSERT INTO pee_entries (id, session_id, amount, remarks, time)
          SELECT id, session_id, amount, remarks, time FROM pee_entries_old
        ''');

        // Update the auto increment sequence to continue from the highest ID
        final peeResult = await txn.rawQuery('SELECT MAX(id) as max_id FROM pee_entries');
        final peeMaxId = peeResult.first['max_id'] as int?;
        if (peeMaxId != null) {
          await txn.execute('''
            UPDATE sqlite_sequence 
            SET seq = ? 
            WHERE name = 'pee_entries'
          ''', [peeMaxId]);
        }

        // Drop old table
        await txn.execute('DROP TABLE pee_entries_old');

        // Recreate poop_entries table with nullable amount, consistency, and color
        await txn.execute('ALTER TABLE poop_entries RENAME TO poop_entries_old');
        await txn.execute('''
          CREATE TABLE poop_entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            amount INTEGER,
            consistency INTEGER,
            color INTEGER,
            time TEXT NOT NULL,
            photo_path TEXT,
            has_photo INTEGER NOT NULL,
            FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
          )
        ''');

        // Copy data from old table to new table
        await txn.execute('''
          INSERT INTO poop_entries (id, session_id, amount, consistency, color, time, photo_path, has_photo)
          SELECT id, session_id, amount, consistency, color, time, photo_path, has_photo FROM poop_entries_old
        ''');

        // Update the auto increment sequence to continue from the highest ID
        final poopResult = await txn.rawQuery('SELECT MAX(id) as max_id FROM poop_entries');
        final poopMaxId = poopResult.first['max_id'] as int?;
        if (poopMaxId != null) {
          await txn.execute('''
            UPDATE sqlite_sequence 
            SET seq = ? 
            WHERE name = 'poop_entries'
          ''', [poopMaxId]);
        }

        // Drop old table
        await txn.execute('DROP TABLE poop_entries_old');

        // Now perform the enum migration
        // OLD: PeeAmount { na=0, small=1, medium=2, large=3, xlarge=4 }
        // NEW: PeeAmount { small=0, medium=1, large=2, xlarge=3 }
        // OLD: PoopAmount { na=0, small=1, medium=2, large=3, blowout=4 }
        // NEW: PoopAmount { small=0, medium=1, large=2, blowout=3 }

        // Migrate pee entries
        // Set amount = NULL where amount = 0 (was na)
        await txn.update(
          'pee_entries',
          {'amount': null},
          where: 'amount = ?',
          whereArgs: [0],
        );

        // Decrease all other pee amounts by 1 to adjust for removed na
        await txn.rawUpdate('''
          UPDATE pee_entries 
          SET amount = amount - 1 
          WHERE amount IS NOT NULL AND amount > 0
        ''');

        // Migrate poop entries
        // Set amount = NULL where amount = 0 (was na)
        await txn.update(
          'poop_entries',
          {'amount': null},
          where: 'amount = ?',
          whereArgs: [0],
        );

        // Decrease all other poop amounts by 1 to adjust for removed na
        await txn.rawUpdate('''
          UPDATE poop_entries 
          SET amount = amount - 1 
          WHERE amount IS NOT NULL AND amount > 0
        ''');

        // For poop entries, also set consistency and color to NULL where they were previously required
        // This ensures that old entries that had 'na' amount also have their other fields set to NULL
        // so they show as incomplete entries that need to be completed by the user
        await txn.rawUpdate('''
          UPDATE poop_entries 
          SET consistency = NULL, color = NULL 
          WHERE amount IS NULL
        ''');

        // Recreate milk_entries table with nullable amount
        await txn.execute('ALTER TABLE milk_entries RENAME TO milk_entries_old');
        await txn.execute('''
          CREATE TABLE milk_entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            amount INTEGER,
            time TEXT NOT NULL,
            FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
          )
        ''');

        // Copy data from old table to new table, setting amount=0 to NULL
        await txn.execute('''
          INSERT INTO milk_entries (id, session_id, amount, time)
          SELECT id, session_id, CASE WHEN amount = 0 THEN NULL ELSE amount END, time FROM milk_entries_old
        ''');

        // Update the auto increment sequence to continue from the highest ID
        final milkResult = await txn.rawQuery('SELECT MAX(id) as max_id FROM milk_entries');
        final milkMaxId = milkResult.first['max_id'] as int?;
        if (milkMaxId != null) {
          await txn.execute('''
            UPDATE sqlite_sequence 
            SET seq = ? 
            WHERE name = 'milk_entries'
          ''', [milkMaxId]);
        }

        // Drop old table
        await txn.execute('DROP TABLE milk_entries_old');

        // Recreate vitamin_entries table with nullable type (stored as TEXT)
        await txn.execute('ALTER TABLE vitamin_entries RENAME TO vitamin_entries_old');
        await txn.execute('''
          CREATE TABLE vitamin_entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            time TEXT NOT NULL,
            type TEXT,
            notes TEXT,
            FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
          )
        ''');

        // Copy data from old table to new table, converting integer type to string
        await txn.execute('''
          INSERT INTO vitamin_entries (id, session_id, time, type, notes)
          SELECT id, session_id, time, 
                 CASE WHEN type = 0 THEN '${VitaminType.ad.name}' WHEN type = 1 THEN '${VitaminType.other.name}' ELSE NULL END, 
                 notes FROM vitamin_entries_old
        ''');

        // Update the auto increment sequence to continue from the highest ID
        final vitaminResult = await txn.rawQuery('SELECT MAX(id) as max_id FROM vitamin_entries');
        final vitaminMaxId = vitaminResult.first['max_id'] as int?;
        if (vitaminMaxId != null) {
          await txn.execute('''
            UPDATE sqlite_sequence 
            SET seq = ? 
            WHERE name = 'vitamin_entries'
          ''', [vitaminMaxId]);
        }

        // Drop old table
        await txn.execute('DROP TABLE vitamin_entries_old');
      });
    }
    if (oldVersion < 8) {
      // Remove vitaminAD column from sessions table as it's now handled by vitamin_entries
      await db.transaction((txn) async {
        // Recreate sessions table without vitaminAD column
        await txn.execute('ALTER TABLE sessions RENAME TO sessions_old');
        await txn.execute('''
          CREATE TABLE sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            wakeUpTime TEXT NOT NULL,
            sleepTime TEXT,
            sessionPhotoPath TEXT,
            hasSessionPhoto INTEGER NOT NULL,
            isClosed INTEGER NOT NULL
          )
        ''');

        // Copy data from old table to new table (excluding vitaminAD)
        await txn.execute('''
          INSERT INTO sessions (id, wakeUpTime, sleepTime, sessionPhotoPath, hasSessionPhoto, isClosed)
          SELECT id, wakeUpTime, sleepTime, sessionPhotoPath, hasSessionPhoto, isClosed FROM sessions_old
        ''');

        // Update the auto increment sequence to continue from the highest ID
        final result = await txn.rawQuery('SELECT MAX(id) as max_id FROM sessions');
        final maxId = result.first['max_id'] as int?;
        if (maxId != null) {
          await txn.execute('''
            UPDATE sqlite_sequence 
            SET seq = ? 
            WHERE name = 'sessions'
          ''', [maxId]);
        }

        // Drop old table
        await txn.execute('DROP TABLE sessions_old');
      });
    }
    if (oldVersion < 9) {
      // Convert enum columns from INTEGER to TEXT storage
      await db.transaction((txn) async {
        // Convert pee_entries amount from integer to text
        await txn.execute('ALTER TABLE pee_entries RENAME TO pee_entries_old');
        await txn.execute('''
          CREATE TABLE pee_entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            amount TEXT,
            remarks TEXT,
            time TEXT NOT NULL,
            FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
          )
        ''');

        // Copy data, converting integer enum values to text
        await txn.execute('''
          INSERT INTO pee_entries (id, session_id, amount, remarks, time)
          SELECT id, session_id, 
            CASE 
              WHEN amount IS NULL THEN NULL
              WHEN amount = 0 THEN '${PeeAmount.small.name}'
              WHEN amount = 1 THEN '${PeeAmount.medium.name}'
              WHEN amount = 2 THEN '${PeeAmount.large.name}'
              WHEN amount = 3 THEN '${PeeAmount.xlarge.name}'
              ELSE NULL
            END,
            remarks, time FROM pee_entries_old
        ''');

        // Update sequence
        final peeResult = await txn.rawQuery('SELECT MAX(id) as max_id FROM pee_entries');
        final peeMaxId = peeResult.first['max_id'] as int?;
        if (peeMaxId != null) {
          await txn.execute('''
            UPDATE sqlite_sequence 
            SET seq = ? 
            WHERE name = 'pee_entries'
          ''', [peeMaxId]);
        }

        await txn.execute('DROP TABLE pee_entries_old');

        // Convert poop_entries amount, consistency, color from integer to text
        await txn.execute('ALTER TABLE poop_entries RENAME TO poop_entries_old');
        await txn.execute('''
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

        // Copy data, converting integer enum values to text
        await txn.execute('''
          INSERT INTO poop_entries (id, session_id, amount, consistency, color, time, photo_path, has_photo)
          SELECT id, session_id, 
            CASE 
              WHEN amount IS NULL THEN NULL
              WHEN amount = 0 THEN '${PoopAmount.small.name}'
              WHEN amount = 1 THEN '${PoopAmount.medium.name}'
              WHEN amount = 2 THEN '${PoopAmount.large.name}'
              WHEN amount = 3 THEN '${PoopAmount.blowout.name}'
              ELSE NULL
            END,
            CASE 
              WHEN consistency IS NULL THEN NULL
              WHEN consistency = 0 THEN '${PoopConsistency.normal.name}'
              WHEN consistency = 1 THEN '${PoopConsistency.dry.name}'
              WHEN consistency = 2 THEN '${PoopConsistency.liquid.name}'
              WHEN consistency = 3 THEN '${PoopConsistency.diarrhea.name}'
              ELSE NULL
            END,
            CASE 
              WHEN color IS NULL THEN NULL
              WHEN color = 0 THEN '${PoopColor.green.name}'
              WHEN color = 1 THEN '${PoopColor.yellow.name}'
              WHEN color = 2 THEN '${PoopColor.yellowGreen.name}'
              WHEN color = 3 THEN '${PoopColor.abnormal.name}'
              ELSE NULL
            END,
            time, photo_path, has_photo FROM poop_entries_old
        ''');

        // Update sequence
        final poopResult = await txn.rawQuery('SELECT MAX(id) as max_id FROM poop_entries');
        final poopMaxId = poopResult.first['max_id'] as int?;
        if (poopMaxId != null) {
          await txn.execute('''
            UPDATE sqlite_sequence 
            SET seq = ? 
            WHERE name = 'poop_entries'
          ''', [poopMaxId]);
        }

        await txn.execute('DROP TABLE poop_entries_old');
      });
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
    final sessionsWithEntries =
        await Future.wait(sessions.map((session) => loadSessionWithEntries(session)));

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
