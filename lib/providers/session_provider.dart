import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../services/database_service.dart';

class SessionProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  Session? _currentSession;
  List<Session> _sessions = [];
  DateTime? _lastSleepTime;

  Session? get currentSession => _currentSession;
  List<Session> get sessions => _sessions;
  DateTime? get lastSleepTime => _lastSleepTime;

  Future<void> loadSessions() async {
    _sessions = await _db.getAllSessions();
    if (_sessions.isNotEmpty) {
      _lastSleepTime = _sessions.first.sleepTime;
    }
    notifyListeners();
  }

  Future<void> createNewSession() async {
    final now = DateTime.now();
    _currentSession = Session(wakeUpTime: now);
    final session = await _db.createSession(_currentSession!);
    _currentSession = session;
    await loadSessions();
  }

  Future<void> updateCurrentSession(Session updatedSession) async {
    if (_currentSession?.id == null) return;
    
    await _db.updateSession(updatedSession);
    _currentSession = updatedSession;
    await loadSessions();
  }

  Future<void> closeCurrentSession() async {
    if (_currentSession == null) return;

    final closedSession = _currentSession!.copyWith(
      sleepTime: DateTime.now(),
      isClosed: true,
    );
    await _db.updateSession(closedSession);
    _currentSession = null;
    await loadSessions();
  }

  Future<List<Session>> getSessionsInRange(DateTime start, DateTime end) async {
    return await _db.getSessionsInRange(start, end);
  }

  Future<void> updateSession(Session session) async {
    await _db.updateSession(session);
    await loadSessions();
  }
}
