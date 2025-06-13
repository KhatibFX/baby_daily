import 'dart:io';

import 'package:baby_daily/shared/session_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/milk_entry.dart';
import '../models/pee_entry.dart';
import '../models/poop_entry.dart';
import '../models/session.dart';
import '../services/database_service.dart';

class SessionProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  Session? _currentSession;
  List<Session> _sessions = [];
  DateTime? _lastSleepTime;
  String? _photosDir;

  Session? get currentSession => _currentSession;

  List<Session> get sessions => _sessions;

  DateTime? get lastSleepTime => _lastSleepTime;

  /// Public getter for photo directory, used by UI
  Future<String> get photoDirectory => _photoDirectory;

  Future<String> get _photoDirectory async {
    if (_photosDir != null) return _photosDir!;

    final appDir = await getApplicationSupportDirectory();
    _photosDir = path.join(appDir.path, 'photos');

    final dir = Directory(_photosDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      if (!await dir.exists()) {
        print('Failed to create photos directory at $_photosDir');
        final docDir = await getApplicationDocumentsDirectory();
        _photosDir = path.join(docDir.path, 'photos');
        final fallbackDir = Directory(_photosDir!);
        await fallbackDir.create(recursive: true);
      }
    }
    return _photosDir!;
  }

  String _getRelativePath(String absolutePath) {
    final photosDir = _photosDir;
    if (photosDir == null || !absolutePath.startsWith(photosDir)) {
      return absolutePath;
    }
    return absolutePath.substring(photosDir.length + 1);
  }

  Future<String> _getAbsolutePath(String relativePath) async {
    final photosDir = await _photoDirectory;
    // If already absolute path containing photosDir, return as is
    if (path.isAbsolute(relativePath) && relativePath.startsWith(photosDir)) {
      return relativePath;
    }
    // Remove any leading slashes from relative path
    final cleanPath = relativePath.replaceAll(RegExp(r'^[/\\]+'), '');
    return path.join(photosDir, cleanPath);
  }

  Future<void> _deletePhotoFile(String photoPath) async {
    final absolutePath = await _getAbsolutePath(photoPath);
    final file = File(absolutePath);
    if (await file.exists()) {
      await file.delete();
      print('Successfully deleted photo: $photoPath');
    }
  }

  Future<void> loadSessions() async {
    _sessions = await _db.getAllSessions();
    if (_sessions.isNotEmpty) {
      _lastSleepTime = _sessions.first.sleepTime;

      final unclosedSession = _sessions.firstWhere(
        (session) => !session.isClosed,
        orElse: () => _sessions.first,
      );

      if (!unclosedSession.isClosed) {
        _currentSession = unclosedSession;
      }
    }
    notifyListeners();
  }

  Future<void> createNewSession() async {
    final now = truncateToMinute(DateTime.now());
    _currentSession = Session(wakeUpTime: now);
    final session = await _db.createSession(_currentSession!);
    _currentSession = session;
    await loadSessions();
  }

  Future<void> deleteSession(Session session) async {
    // Delete all photos associated with poop entries
    for (final entry in session.poopEntries) {
      if (entry.hasPhoto && entry.photoPath != null) {
        await _deletePhotoFile(entry.photoPath!);
      }
    }

    // Delete the session photo if it exists
    if (session.hasSessionPhoto && session.sessionPhotoPath != null) {
      await _deletePhotoFile(session.sessionPhotoPath!);
    }

    await _db.deleteSession(session.id!);

    // Reload sessions
    await loadSessions();
  }

  Future<void> updateCurrentSession(Session updatedSession) async {
    if (_currentSession?.id == null) return;
    await _db.updateSession(updatedSession);
    _currentSession = updatedSession;
    notifyListeners();
  }

  Future<void> updateDefaultSleepTime() async {
    if (_currentSession != null &&
        !_currentSession!.isClosed &&
        _currentSession?.sleepTime == null) {
      await updateCurrentSession(
        _currentSession!.copyWith(sleepTime: DateTime.now()),
      );
    }
  }

  Future<void> closeSession(Session session, DateTime sleepTime) async {
    final updatedSession = session.copyWith(sleepTime: sleepTime, isClosed: true);
    await _db.updateSession(updatedSession);
    _lastSleepTime = sleepTime;
    _currentSession = null;
    await loadSessions();
  }

  Future<void> closeCurrentSession() async {
    if (_currentSession == null || _currentSession!.isClosed) return;
    if (_currentSession!.sleepTime == null) return;

    await closeSession(_currentSession!, _currentSession!.sleepTime!);
  }

  Future<List<Session>> getSessionsInRange(DateTime start, DateTime end) async {
    return await _db.getSessionsInRange(start, end);
  }

  Future<void> updateSession(Session session) async {
    if (session.id != null) {
      // For existing sessions, always use update
      await _db.updateSession(session);
      // If this is the current session, update it
      if (_currentSession?.id == session.id) {
        _currentSession = session;
      }
      // Refresh the sessions list
      await loadSessions();
      notifyListeners();
    }
  }

  Future<List<Session>> getClosedSessionsInRange(DateTime start, DateTime end) async {
    final sessions = await _db.getSessionsInRange(start, end);
    return sessions.where((s) => s.isClosed).toList();
  }

  Future<String?> takePoopPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      final String photoFileName = 'poop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final photosDir = await _photoDirectory;
      final String photoPath = path.join(photosDir, photoFileName);

      // Move the temporary file to a permanent location
      await File(image.path).copy(photoPath);
      await File(image.path).delete();

      return _getRelativePath(photoPath);
    }
    return null;
  }

  Future<String?> takeSessionPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      final String photoFileName = 'session_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final photosDir = await _photoDirectory;
      final String photoPath = path.join(photosDir, photoFileName);

      // Move the temporary file to a permanent location
      await File(image.path).copy(photoPath);
      await File(image.path).delete();

      return _getRelativePath(photoPath);
    }
    return null;
  }

  Future<String?> savePhotoOnly(XFile image, String prefix) async {
    final String photoFileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final photosDir = await _photoDirectory;
    final String photoPath = path.join(photosDir, photoFileName);

    await File(image.path).copy(photoPath);
    await File(image.path).delete();

    return _getRelativePath(photoPath);
  }

  Future<void> saveSessionPhoto(Session session, XFile image) async {
    final photoPath = await savePhotoOnly(image, 'session');
    if (photoPath != null) {
      final updatedSession = session.copyWith(
        sessionPhotoPath: photoPath,
        hasSessionPhoto: true,
      );
      await updateSession(updatedSession);
    }
  }

  Future<void> saveAbnormalPoopPhoto(Session session, XFile image) async {
    final photoPath = await savePhotoOnly(image, 'poop');
    if (photoPath != null) {
      // Update the most recent poop entry that has abnormal color
      for (int i = 0; i < session.poopEntries.length; i++) {
        var entry = session.poopEntries[i];
        if (entry.color == PoopColor.abnormal && !entry.hasPhoto) {
          final updatedEntry = entry.copyWith(
            photoPath: photoPath,
            hasPhoto: true,
          );
          final updatedEntries = List.of(session.poopEntries);
          updatedEntries[i] = updatedEntry;
          final updatedSession = session.copyWith(poopEntries: updatedEntries);
          await updateSession(updatedSession);
          break;
        }
      }
    }
  }

  Future<void> deletePhotoOnly(String photoPath) async {
    await _deletePhotoFile(photoPath);
  }

  Future<void> removeSessionPhoto(Session session) async {
    if (session.sessionPhotoPath != null) {
      await _deletePhotoFile(session.sessionPhotoPath!);
      final updatedSession = session.copyWith(
        sessionPhotoPath: null,
        hasSessionPhoto: false,
      );
      await updateSession(updatedSession);
    }
  }

  Future<void> removeAbnormalPoopPhoto(Session session) async {
    // Find and update the most recent poop entry that has a photo
    for (int i = 0; i < session.poopEntries.length; i++) {
      var entry = session.poopEntries[i];
      if (entry.hasPhoto && entry.photoPath != null) {
        await _deletePhotoFile(entry.photoPath!);
        final updatedEntry = entry.copyWith(
          photoPath: null,
          hasPhoto: false,
        );
        final updatedEntries = List.of(session.poopEntries);
        updatedEntries[i] = updatedEntry;
        final updatedSession = session.copyWith(poopEntries: updatedEntries);
        await updateSession(updatedSession);
        break;
      }
    }
  }

  // Get the session that occurred before the given session
  Session? getPreviousSession(Session session) {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1 && index < _sessions.length - 1) {
      return _sessions[index + 1]; // Sessions are ordered by wakeUpTime DESC
    }
    return null;
  }

  // Get the session that occurred after the given session
  Session? getNextSession(Session session) {
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index > 0) {
      return _sessions[index - 1]; // Sessions are ordered by wakeUpTime DESC
    }
    return null;
  }

  // Entry Management Methods
  Future<PeeEntry> addPeeEntry({
    required int sessionId,
    required PeeAmount amount,
    String? remarks,
    required DateTime time,
  }) async {
    final entry = PeeEntry(
      sessionId: sessionId,
      amount: amount,
      remarks: remarks,
      time: time,
    );

    final savedEntry = await _db.createPeeEntry(entry);
    if (_currentSession?.id == sessionId) {
      _currentSession!.addPeeEntry(savedEntry);
      notifyListeners();
    }
    await loadSessions(); // Refresh the session list
    return savedEntry;
  }

  Future<PoopEntry> addPoopEntry({
    required int sessionId,
    required PoopAmount amount,
    required PoopConsistency consistency,
    required PoopColor color,
    required DateTime time,
    String? photoPath,
    bool hasPhoto = false,
  }) async {
    final entry = PoopEntry(
      sessionId: sessionId,
      amount: amount,
      consistency: consistency,
      color: color,
      time: time,
      photoPath: photoPath,
      hasPhoto: hasPhoto,
    );

    final savedEntry = await _db.createPoopEntry(entry);
    if (_currentSession?.id == sessionId) {
      _currentSession!.addPoopEntry(savedEntry);
      notifyListeners();
    }
    await loadSessions(); // Refresh the session list
    return savedEntry;
  }

  Future<MilkEntry> addMilkEntry({
    required int sessionId,
    required int amount,
    required DateTime time,
  }) async {
    final entry = MilkEntry(
      sessionId: sessionId,
      amount: amount,
      time: time,
    );

    final savedEntry = await _db.createMilkEntry(entry);
    if (_currentSession?.id == sessionId) {
      _currentSession!.addMilkEntry(savedEntry);
      notifyListeners();
    }
    await loadSessions(); // Refresh the session list
    return savedEntry;
  }

  Future<void> updateSessionWithMilkEntries(Session session) async {
    // First update the main session
    await _db.updateSession(session);

    // Update milk entries in a transaction
    await _db.updateSessionMilkEntries(session.id!, session.milkEntries);

    // Update state if this is the current session
    if (_currentSession?.id == session.id) {
      _currentSession = await _db.loadSessionWithEntries(session);
      notifyListeners();
    }

    await loadSessions();
  }

  Future<void> updateSessionWithPeeEntries(Session session) async {
    // First update the main session
    await _db.updateSession(session);

    // Update pee entries in a transaction
    await _db.updateSessionPeeEntries(session.id!, session.peeEntries);

    // Update state if this is the current session
    if (_currentSession?.id == session.id) {
      _currentSession = await _db.loadSessionWithEntries(session);
      notifyListeners();
    }

    await loadSessions();
  }

  Future<void> updateSessionWithPoopEntries(Session session) async {
    // First update the main session
    await _db.updateSession(session);

    // Update poop entries in a transaction
    await _db.updateSessionPoopEntries(session.id!, session.poopEntries);

    // Update state if this is the current session
    if (_currentSession?.id == session.id) {
      _currentSession = await _db.loadSessionWithEntries(session);
      notifyListeners();
    }

    await loadSessions();
  }

  // Milk Entry Methods

  // Deletion methods
  Future<bool> deletePeeEntry(int entryId, int sessionId) async {
    final deleted = await _db.deletePeeEntry(entryId);
    if (deleted > 0) {
      if (_currentSession?.id == sessionId) {
        _currentSession!.removePeeEntry(entryId);
        notifyListeners();
      }
      await loadSessions();
      return true;
    }
    return false;
  }

  Future<bool> deletePoopEntry(int entryId, int sessionId, {String? photoPath}) async {
    if (photoPath != null) {
      await _deletePhotoFile(photoPath);
    }

    final deleted = await _db.deletePoopEntry(entryId);
    if (deleted > 0) {
      if (_currentSession?.id == sessionId) {
        _currentSession!.removePoopEntry(entryId);
        notifyListeners();
      }
      await loadSessions();
      return true;
    }
    return false;
  }

  Future<bool> deleteMilkEntry(int entryId, int sessionId) async {
    final deleted = await _db.deleteMilkEntry(entryId);
    if (deleted > 0) {
      if (_currentSession?.id == sessionId) {
        _currentSession!.removeMilkEntry(entryId);
        notifyListeners();
      }
      await loadSessions();
      return true;
    }
    return false;
  }
}
