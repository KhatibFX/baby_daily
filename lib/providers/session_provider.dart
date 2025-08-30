import 'dart:io';

import 'package:baby_daily/models/enums/pee_enums.dart';
import 'package:baby_daily/models/enums/poop_enums.dart';
import 'package:baby_daily/models/enums/vitamin_enums.dart';
import 'package:baby_daily/shared/session_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/milk_entry.dart';
import '../models/pee_entry.dart';
import '../models/poop_entry.dart';
import '../models/session.dart';
import '../models/vitamin_entry.dart';
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
    // Update in-memory state first
    if (_currentSession?.id == session.id) {
      _currentSession = null;
    }

    _sessions.removeWhere((s) => s.id == session.id);
    notifyListeners();

    // Delete photos first
    for (final entry in session.poopEntries) {
      if (entry.hasPhoto && entry.photoPath != null) {
        await _deletePhotoFile(entry.photoPath!);
      }
    }

    if (session.hasSessionPhoto && session.sessionPhotoPath != null) {
      await _deletePhotoFile(session.sessionPhotoPath!);
    }

    // Delete from DB
    await _db.deleteSession(session.id!);
  }

  Future<void> updateCurrentSession(Session updatedSession) async {
    if (_currentSession?.id == null) return;

    // Update in-memory state first
    _currentSession = updatedSession;

    final index = _sessions.indexWhere((s) => s.id == updatedSession.id);
    if (index != -1) {
      _sessions[index] = updatedSession;
    }

    notifyListeners();

    // Update DB state
    await _db.updateSession(updatedSession);
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

  Future<bool> closeSession(Session session, DateTime sleepTime) async {
    // Check if all entries are complete
    if (!session.hasCompleteEntries) {
      return false; // Return false to indicate validation failed
    }

    final updatedSession = session.copyWith(sleepTime: sleepTime, isClosed: true);

    // Update in-memory state first
    if (_currentSession?.id == session.id) {
      _currentSession = null;
    }

    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      _sessions[index] = updatedSession;
    }

    _lastSleepTime = sleepTime;
    notifyListeners();

    // Update DB state
    await _db.updateSession(updatedSession);
    return true; // Return true to indicate success
  }

  Future<bool> closeCurrentSession() async {
    if (_currentSession == null || _currentSession!.isClosed) return false;
    if (_currentSession!.sleepTime == null) return false;

    // Check if all entries are complete
    if (!_currentSession!.hasCompleteEntries) {
      return false; // Return false to indicate validation failed
    }

    await closeSession(_currentSession!, _currentSession!.sleepTime!);
    return true; // Return true to indicate success
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

  Future<List<Session>> getAllSessions() async {
    return await _db.getAllSessions();
  }

  Future<void> restoreFromBackup(List<Session> sessions) async {
    print('Starting restore from backup...');
    print('Sessions to restore: ${sessions.length}');
    
    // Clear existing sessions from database
    await _db.clearAllSessions();
    print('Cleared existing sessions from database');

    // Note: Photos are already restored by the backup service
    // We don't need to clear the photos directory here
    // Just reset the cached photo directory path to ensure fresh lookup
    _photosDir = null;
    print('Reset cached photo directory path');

    // Insert all sessions from backup
    print('Inserting sessions from backup...');
    for (final session in sessions) {
      print('Restoring session: ${session.wakeUpTime}');
      if (session.hasSessionPhoto && session.sessionPhotoPath != null) {
        print('  - Session photo: ${session.sessionPhotoPath}');
      }
      for (final poopEntry in session.poopEntries) {
        if (poopEntry.hasPhoto && poopEntry.photoPath != null) {
          print('  - Poop entry photo: ${poopEntry.photoPath}');
        }
      }
      await _db.restoreSession(session);
    }
    print('All sessions restored');

    // Reload sessions
    await loadSessions();
    notifyListeners();
    print('Restore completed');
  }

  /// Gets all sessions for analytics that overlap with the date range
  ///
  /// Session Selection Logic:
  /// - sleepTime is after the start time OR sleepTime is null (open session)
  /// - wakeUpTime is before the end time
  ///
  /// Entry Filtering:
  /// - Only includes entries where entry.time >= start AND entry.time < end
  /// - This allows analytics to include data from open sessions when entries fall within range
  Future<List<Session>> getSessionsForAnalytics(DateTime start, DateTime end) async {
    final sessions = await _db.getSessionsForAnalytics(start, end);

    // Filter entries within each session to only include those within the date range [start, end)
    return sessions.map((session) {
      return session.copyWith(
        peeEntries: session.peeEntries
            .where((entry) => !entry.time.isBefore(start) && entry.time.isBefore(end))
            .toList(),
        poopEntries: session.poopEntries
            .where((entry) => !entry.time.isBefore(start) && entry.time.isBefore(end))
            .toList(),
        milkEntries: session.milkEntries
            .where((entry) => !entry.time.isBefore(start) && entry.time.isBefore(end))
            .toList(),
        vitaminEntries: session.vitaminEntries
            .where((entry) => !entry.time.isBefore(start) && entry.time.isBefore(end))
            .toList(),
      );
    }).toList();
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

  Future<void> saveAbnormalPoopPhoto(Session session, XFile image, {DateTime? entryTime}) async {
    final photoPath = await savePhotoOnly(image, 'poop');
    if (photoPath != null) {
      // Find the specific entry we want to update
      int entryIndex;
      if (entryTime != null) {
        entryIndex = session.poopEntries.indexWhere((e) => e.time.isAtSameMomentAs(entryTime));
        // If not found by exact time, try finding by closest time
        if (entryIndex == -1) {
          entryIndex = session.poopEntries.indexWhere((e) =>
              e.color == PoopColor.abnormal &&
              !e.hasPhoto &&
              e.time.difference(entryTime).inMinutes.abs() < 1);
        }
      } else {
        // Legacy fallback - find first abnormal entry without photo
        entryIndex =
            session.poopEntries.indexWhere((e) => e.color == PoopColor.abnormal && !e.hasPhoto);
      }

      if (entryIndex != -1) {
        final entry = session.poopEntries[entryIndex];
        final updatedEntry = entry.copyWith(
          photoPath: photoPath,
          hasPhoto: true,
        );
        final updatedEntries = List.of(session.poopEntries);
        updatedEntries[entryIndex] = updatedEntry;
        final updatedSession = session.copyWith(poopEntries: updatedEntries);
        await updateSession(updatedSession);
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

  Future<void> removeAbnormalPoopPhoto(Session session, {DateTime? entryTime}) async {
    // If entryTime is provided, find and update that specific entry
    // Otherwise find and update the most recent poop entry that has a photo
    for (int i = 0; i < session.poopEntries.length; i++) {
      var entry = session.poopEntries[i];
      if (entry.hasPhoto && entry.photoPath != null) {
        if (entryTime == null || entry.time.isAtSameMomentAs(entryTime)) {
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
    PeeAmount? amount,
    String? remarks,
    required DateTime time,
  }) async {
    final entry = PeeEntry(
      sessionId: sessionId,
      amount: amount,
      remarks: remarks,
      time: time,
    );

    // Create entry in DB
    final savedEntry = await _db.createPeeEntry(entry);

    // Update in-memory state
    if (_currentSession?.id == sessionId) {
      _currentSession!.addPeeEntry(savedEntry);
    }

    // Notify listeners after updating in-memory state but before additional DB operations
    notifyListeners();

    return savedEntry;
  }

  Future<PoopEntry> addPoopEntry({
    required int sessionId,
    PoopAmount? amount,
    PoopConsistency? consistency,
    PoopColor? color,
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

    // Create entry in DB
    final savedEntry = await _db.createPoopEntry(entry);

    // Update in-memory state
    if (_currentSession?.id == sessionId) {
      _currentSession!.addPoopEntry(savedEntry);
    }

    // Notify listeners after updating in-memory state but before additional DB operations
    notifyListeners();

    return savedEntry;
  }

  Future<MilkEntry> addMilkEntry({
    required int sessionId,
    int? amount,
    required DateTime time,
  }) async {
    final entry = MilkEntry(
      sessionId: sessionId,
      amount: amount,
      time: time,
    );

    // Create entry in DB
    final savedEntry = await _db.createMilkEntry(entry);

    // Update in-memory state
    if (_currentSession?.id == sessionId) {
      _currentSession!.addMilkEntry(savedEntry);
    }

    // Notify listeners after updating in-memory state but before additional DB operations
    notifyListeners();

    return savedEntry;
  }

  Future<VitaminEntry> addVitaminEntry({
    required int sessionId,
    required DateTime time,
    VitaminType? type,
    String? notes,
  }) async {
    final entry = VitaminEntry(
      sessionId: sessionId,
      time: time,
      type: type,
      notes: notes,
    );

    // Create entry in DB
    final savedEntry = await _db.createVitaminEntry(entry);

    // Update in-memory state
    if (_currentSession?.id == sessionId) {
      _currentSession!.addVitaminEntry(savedEntry);
    }

    // Notify listeners after updating in-memory state but before additional DB operations
    notifyListeners();

    return savedEntry;
  }

  Future<void> updateSessionWithMilkEntries(Session session) async {
    // Update in-memory state first
    if (_currentSession?.id == session.id) {
      _currentSession = session;
    }

    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      _sessions[index] = session;
    }

    // Notify listeners after updating in-memory state but before DB operations
    notifyListeners();

    // Update DB state
    await _db.updateSession(session);
    await _db.updateSessionMilkEntries(session.id!, session.milkEntries);
  }

  Future<void> updateSessionWithPeeEntries(Session session) async {
    // Update in-memory state first
    if (_currentSession?.id == session.id) {
      _currentSession = session;
    }

    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      _sessions[index] = session;
    }

    // Notify listeners after updating in-memory state but before DB operations
    notifyListeners();

    // Update DB state
    await _db.updateSession(session);
    await _db.updateSessionPeeEntries(session.id!, session.peeEntries);
  }

  Future<void> updateSessionWithPoopEntries(Session session) async {
    // Update in-memory state first
    if (_currentSession?.id == session.id) {
      _currentSession = session;
    }

    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      _sessions[index] = session;
    }

    // Notify listeners after updating in-memory state but before DB operations
    notifyListeners();

    // Update DB state
    await _db.updateSession(session);
    await _db.updateSessionPoopEntries(session.id!, session.poopEntries);
  }

  Future<void> updateSessionWithVitaminEntries(Session session) async {
    // Update in-memory state first
    if (_currentSession?.id == session.id) {
      _currentSession = session;
    }

    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      _sessions[index] = session;
    }

    // Notify listeners after updating in-memory state but before DB operations
    notifyListeners();

    // Update DB state
    await _db.updateSession(session);
    await _db.updateSessionVitaminEntries(session.id!, session.vitaminEntries);
  }

  // Deletion methods
  Future<bool> deletePeeEntry(int entryId, int sessionId) async {
    // Update in-memory state first
    bool found = false;

    if (_currentSession?.id == sessionId) {
      _currentSession!.removePeeEntry(entryId);
      found = true;
    }

    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      _sessions[index].removePeeEntry(entryId);
      found = true;
    }

    // Only notify if we found and updated the entry in memory
    if (found) {
      notifyListeners();
    }

    // Delete from DB after UI is updated
    final deleted = await _db.deletePeeEntry(entryId);
    return deleted > 0;
  }

  Future<bool> deletePoopEntry(int entryId, int sessionId, {String? photoPath}) async {
    // Delete photo file if it exists
    if (photoPath != null) {
      await _deletePhotoFile(photoPath);
    }

    // Update in-memory state first
    bool found = false;

    if (_currentSession?.id == sessionId) {
      _currentSession!.removePoopEntry(entryId);
      found = true;
    }

    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      _sessions[index].removePoopEntry(entryId);
      found = true;
    }

    // Only notify if we found and updated the entry in memory
    if (found) {
      notifyListeners();
    }

    // Delete from DB after UI is updated
    final deleted = await _db.deletePoopEntry(entryId);
    return deleted > 0;
  }

  Future<bool> deleteMilkEntry(int entryId, int sessionId) async {
    // Update in-memory state first
    bool found = false;

    if (_currentSession?.id == sessionId) {
      _currentSession!.removeMilkEntry(entryId);
      found = true;
    }

    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      _sessions[index].removeMilkEntry(entryId);
      found = true;
    }

    // Only notify if we found and updated the entry in memory
    if (found) {
      notifyListeners();
    }

    // Delete from DB after UI is updated
    final deleted = await _db.deleteMilkEntry(entryId);
    return deleted > 0;
  }

  Future<bool> deleteVitaminEntry(int entryId, int sessionId) async {
    // Update in-memory state first
    bool found = false;

    if (_currentSession?.id == sessionId) {
      _currentSession!.removeVitaminEntry(entryId);
      found = true;
    }

    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index != -1) {
      _sessions[index].removeVitaminEntry(entryId);
      found = true;
    }

    // Only notify if we found and updated the entry in memory
    if (found) {
      notifyListeners();
    }

    // Delete from DB after UI is updated
    final deleted = await _db.deleteVitaminEntry(entryId);
    return deleted > 0;
  }
}
