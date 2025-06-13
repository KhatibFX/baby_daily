import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/session.dart';

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
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        wakeUpTime TEXT NOT NULL,
        pee INTEGER NOT NULL,
        peeRemarks TEXT,
        peeTime TEXT,
        poopAmount INTEGER NOT NULL,
        poopConsistency INTEGER NOT NULL,
        poopColor INTEGER NOT NULL,
        poopTime TEXT,
        abnormalPoopPhotoPath TEXT,
        milkIntake INTEGER NOT NULL,
        milkTime TEXT,
        vitaminAD INTEGER NOT NULL,
        sleepTime TEXT,
        sessionPhotoPath TEXT,
        hasSessionPhoto INTEGER NOT NULL,
        hasAbnormalPoopPhoto INTEGER NOT NULL,
        isClosed INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE sessions ADD COLUMN hasSessionPhoto INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE sessions ADD COLUMN hasAbnormalPoopPhoto INTEGER NOT NULL DEFAULT 0');
      await db.execute('UPDATE sessions SET hasSessionPhoto = CASE WHEN sessionPhotoPath IS NOT NULL THEN 1 ELSE 0 END');
      await db.execute('UPDATE sessions SET hasAbnormalPoopPhoto = CASE WHEN abnormalPoopPhotoPath IS NOT NULL THEN 1 ELSE 0 END');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE sessions ADD COLUMN peeTime TEXT');
      await db.execute('ALTER TABLE sessions ADD COLUMN poopTime TEXT');
      await db.execute('ALTER TABLE sessions ADD COLUMN milkTime TEXT');
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
      return Session.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Session>> getAllSessions() async {
    final db = await instance.database;
    final result = await db.query('sessions', orderBy: 'wakeUpTime DESC');
    return result.map((json) => Session.fromMap(json)).toList();
  }

  Future<List<Session>> getSessionsInRange(DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.query(
      'sessions',
      where: 'wakeUpTime BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'wakeUpTime DESC',
    );
    return result.map((json) => Session.fromMap(json)).toList();
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

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
