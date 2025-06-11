import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import '../models/session.dart';
import '../services/database_service.dart';
import 'dart:io';

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
      print('Using existing absolute path: $relativePath');
      return relativePath;
    }
    // Remove any leading slashes from relative path
    final cleanPath = relativePath.replaceAll(RegExp(r'^[/\\]+'), '');
    final absolutePath = path.join(photosDir, cleanPath);
    print('Constructed absolute path: $absolutePath from relative path: $relativePath');
    return absolutePath;
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
    final now = DateTime.now();
    _currentSession = Session(wakeUpTime: now);
    final session = await _db.createSession(_currentSession!);
    _currentSession = session;
    await loadSessions();
  }

  Future<void> updateCurrentSession(Session updatedSession) async {
    if (_currentSession?.id == null) return;
    await _updateSession(updatedSession);
  }

  Future<void> updateDefaultSleepTime() async {
    if (_currentSession != null && !_currentSession!.isClosed && _currentSession?.sleepTime == null) {
      await updateCurrentSession(
        _currentSession!.copyWith(sleepTime: DateTime.now()),
      );
    }
  }

  Future<void> closeCurrentSession() async {
    if (_currentSession == null) return;

    if (_currentSession?.sleepTime == null) {
      await updateCurrentSession(
        _currentSession!.copyWith(sleepTime: DateTime.now()),
      );
    }

    final closedSession = _currentSession!.copyWith(
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

  Future<List<Session>> getClosedSessionsInRange(DateTime start, DateTime end) async {
    final sessions = await _db.getSessionsInRange(start, end);
    return sessions.where((s) => s.isClosed).toList();
  }

  Future<String?> _savePhotoFile(XFile photo, String prefix) async {
    try {
      final photoDir = await _photoDirectory;
      
      // Create unique filename only, which will be our relative path
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final extension = path.extension(photo.path).toLowerCase();
      final fileName = '$prefix\_$timestamp$extension';
      
      // Full path for saving the file
      final savePath = path.join(photoDir, fileName);
      
      final bytes = await photo.readAsBytes();
      
      if (bytes.isEmpty) {
        print('Source photo is empty');
        return null;
      }

      // Write to a temporary file first
      final tempPath = '$savePath.tmp';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes, flush: true);
      
      // Add a small delay to ensure file system operations complete
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify the temp file exists and has content
      if (await tempFile.exists()) {
        final size = await tempFile.length();
        if (size > 0) {
          // Move to final location
          final destinationFile = File(savePath);
          await tempFile.rename(savePath);
          
          // Add another small delay for the file move
          await Future.delayed(const Duration(milliseconds: 100));
          
          // Final verification
          if (await destinationFile.exists()) {
            final finalSize = await destinationFile.length();
            if (finalSize > 0) {
              print('Successfully saved photo at $savePath with size $finalSize bytes');
              // Return just the filename as the relative path
              return fileName;
            }
          }
        }
      }
      
      print('Failed to verify saved photo at $savePath');
      return null;
    } catch (e) {
      print('Error saving photo file: $e');
      return null;
    }
  }

  Future<bool> _deletePhotoFile(String? path) async {
    if (path == null) return false;
    
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      print('Error deleting file $path: $e');
    }
    return false;
  }

  Future<void> _updateSession(Session updatedSession) async {
    await _db.updateSession(updatedSession);
    _currentSession = updatedSession;
    notifyListeners();
  }

  Future<void> removeSessionPhoto(Session session) async {
    if (session.sessionPhotoPath != null) {
      final absolutePath = await _getAbsolutePath(session.sessionPhotoPath!);
      final deleted = await _deletePhotoFile(absolutePath);
      if (deleted) {
        print('Successfully deleted session photo: ${session.sessionPhotoPath}');
      }
      await _updateSession(session.copyWith(
        sessionPhotoPath: null,
        hasSessionPhoto: false,
      ));
    }
  }

  Future<void> removeAbnormalPoopPhoto(Session session) async {
    if (session.abnormalPoopPhotoPath != null) {
      final absolutePath = await _getAbsolutePath(session.abnormalPoopPhotoPath!);
      final deleted = await _deletePhotoFile(absolutePath);
      if (deleted) {
        print('Successfully deleted abnormal poop photo: ${session.abnormalPoopPhotoPath}');
      }
      await _updateSession(session.copyWith(
        abnormalPoopPhotoPath: null, 
        hasAbnormalPoopPhoto: false,
      ));
    }
  }

  Future<void> saveSessionPhoto(Session session, XFile photo) async {
    try {
      final photoPath = await _savePhotoFile(photo, 'session');
      if (photoPath != null) {
        final oldPath = session.sessionPhotoPath;
        if (oldPath != null) {
          final absoluteOldPath = await _getAbsolutePath(oldPath);
          await _deletePhotoFile(absoluteOldPath);
        }
        
        final updatedSession = session.copyWith(
          sessionPhotoPath: photoPath,
          hasSessionPhoto: true,
        );
        
        await _updateSession(updatedSession);
        print('Successfully updated session with new photo: $photoPath');
      } else {
        print('Failed to save session photo');
      }
    } catch (e) {
      print('Error in saveSessionPhoto: $e');
      notifyListeners();
    }
  }

  Future<void> saveAbnormalPoopPhoto(Session session, XFile photo) async {
    try {
      final photoPath = await _savePhotoFile(photo, 'poop');
      if (photoPath != null) {
        final oldPath = session.abnormalPoopPhotoPath;
        if (oldPath != null) {
          final absoluteOldPath = await _getAbsolutePath(oldPath);
          await _deletePhotoFile(absoluteOldPath);
        }
        
        final updatedSession = session.copyWith(
          abnormalPoopPhotoPath: photoPath,
          hasAbnormalPoopPhoto: true,
        );
        
        await _updateSession(updatedSession);
        print('Successfully updated session with new abnormal poop photo: $photoPath');
      } else {
        print('Failed to save abnormal poop photo');
      }
    } catch (e) {
      print('Error in saveAbnormalPoopPhoto: $e');
      notifyListeners();
    }
  }
}
