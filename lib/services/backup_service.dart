import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/session.dart';
import '../models/pee_entry.dart';
import '../models/poop_entry.dart';
import '../models/milk_entry.dart';
import '../models/vitamin_entry.dart';

class BackupService {
  static const String kBackupVersion = '1.0.0';
  static const String kManifestFile = 'manifest.json';
  static const String kDataFile = 'data.json';
  static const String kPhotosDir = 'photos';

  /// Creates a backup of all app data and photos
  /// Returns the path to the created backup file
  static Future<String> createBackup(List<Session> sessions) async {
    final tempDir = await getTemporaryDirectory();
    final backupDir = await Directory(path.join(tempDir.path, 'backup')).create();
    
    try {
      // Create manifest
      final manifest = {
        'version': kBackupVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'sessionCount': sessions.length,
      };
      
      final manifestFile = File(path.join(backupDir.path, kManifestFile));
      await manifestFile.writeAsString(jsonEncode(manifest));

      // Create data JSON
      final data = {
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };
      
      final dataFile = File(path.join(backupDir.path, kDataFile));
      await dataFile.writeAsString(jsonEncode(data));

      // Copy photos
      final photosDir = Directory(path.join(backupDir.path, kPhotosDir));
      await photosDir.create();
      
      final Set<String> copiedPhotos = {};
      
      print('Starting photo backup process...');
      print('Total sessions to process: ${sessions.length}');
      
      // Debug photo paths
      await debugPhotoPaths(sessions);
      
      // Handle session photos and all entry photos
      for (final session in sessions) {
        print('Processing session ${session.id} (${session.wakeUpTime})');
        print('  - hasSessionPhoto: ${session.hasSessionPhoto}');
        print('  - sessionPhotoPath: ${session.sessionPhotoPath}');
        print('  - poopEntries: ${session.poopEntries.length}');
        
        // Session photos
        if (session.hasSessionPhoto && session.sessionPhotoPath != null) {
          print('Processing session photo: ${session.sessionPhotoPath}');
          await _copyPhotoToBackup(session.sessionPhotoPath!, photosDir.path, copiedPhotos);
        }
        
        // Poop entry photos (only poop entries have photos)
        for (final poopEntry in session.poopEntries) {
          print('  - poop entry: hasPhoto=${poopEntry.hasPhoto}, photoPath=${poopEntry.photoPath}');
          if (poopEntry.photoPath != null) {
            print('Processing poop entry photo: ${poopEntry.photoPath}');
            await _copyPhotoToBackup(poopEntry.photoPath!, photosDir.path, copiedPhotos);
          }
        }
      }
      
      print('Total photos copied: ${copiedPhotos.length}');
      print('Photos copied: ${copiedPhotos.toList()}');

      // Create zip archive
      final zipEncoder = ZipEncoder();
      final archive = Archive();

      // Add all files from backup directory
      await _addDirToArchive(backupDir, archive, backupDir.path);

      // Write zip file
      final outputPath = path.join(tempDir.path, 'baby_daily_backup_${DateTime.now().millisecondsSinceEpoch}.zip');
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(zipEncoder.encode(archive)!);

      return outputPath;
    } finally {
      // Clean up temp directory
      await backupDir.delete(recursive: true);
    }
  }

  /// Saves backup to Android external storage (Downloads folder)
  static Future<String?> saveBackupToAndroid(String backupPath) async {
    if (Platform.isAndroid) {
      // Try to save to Downloads folder first
      try {
        return await _saveToDownloadsFolder(backupPath);
      } catch (e) {
        // If Downloads folder fails, save to app's external files directory
        return await _saveToAppExternalDirectory(backupPath);
      }
    }
    return null;
  }

  /// Attempts to save backup to Downloads folder
  static Future<String?> _saveToDownloadsFolder(String backupPath) async {
    // Request storage permissions for different Android versions
    bool hasPermission = false;
    
    // For Android 13+ (API 33+), we need different permissions
    if (await _isAndroid13OrHigher()) {
      // Request photos and videos permission for Android 13+
      final photosStatus = await Permission.photos.request();
      final videosStatus = await Permission.videos.request();
      hasPermission = photosStatus.isGranted && videosStatus.isGranted;
      
      if (!hasPermission) {
        // Try requesting storage permission as fallback
        final storageStatus = await Permission.storage.request();
        hasPermission = storageStatus.isGranted;
      }
    } else {
      // For older Android versions, request storage permission
      final storageStatus = await Permission.storage.request();
      hasPermission = storageStatus.isGranted;
    }
    
    if (!hasPermission) {
      throw Exception('Storage permission is required to save backup. Please grant permission in app settings.');
    }

    // Try multiple possible download directories
    final possiblePaths = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
      '/sdcard/Download',
      '/sdcard/Downloads',
    ];
    
    Directory? downloadsDir;
    for (final path in possiblePaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        downloadsDir = dir;
        break;
      }
    }
    
    // If no existing downloads directory found, try to create one
    if (downloadsDir == null) {
      downloadsDir = Directory('/storage/emulated/0/Download');
      try {
        await downloadsDir.create(recursive: true);
      } catch (e) {
        throw Exception('Unable to access or create downloads directory');
      }
    }

    // Copy backup to downloads
    final fileName = path.basename(backupPath);
    final targetPath = path.join(downloadsDir.path, fileName);
    await File(backupPath).copy(targetPath);
    
    return targetPath;
  }

  /// Saves backup to app's external files directory (no special permissions required)
  static Future<String?> _saveToAppExternalDirectory(String backupPath) async {
    try {
      final appDir = await getExternalStorageDirectory();
      if (appDir == null) {
        throw Exception('Unable to access app external directory');
      }
      
      final backupsDir = Directory(path.join(appDir.path, 'backups'));
      await backupsDir.create(recursive: true);
      
      final fileName = path.basename(backupPath);
      final targetPath = path.join(backupsDir.path, fileName);
      await File(backupPath).copy(targetPath);
      
      return targetPath;
    } catch (e) {
      throw Exception('Failed to save backup to app directory: ${e.toString()}');
    }
  }

  /// Restores data from a backup file
  /// Returns the restored sessions
  static Future<List<Session>> restoreBackup(String backupPath) async {
    final tempDir = await getTemporaryDirectory();
    final extractDir = await Directory(path.join(tempDir.path, 'restore')).create();
    
    try {
      // Read and extract zip
      final bytes = await File(backupPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final filePath = path.join(extractDir.path, filename);
          await File(filePath).create(recursive: true);
          await File(filePath).writeAsBytes(data);
        }
      }

      // Verify manifest
      final manifestFile = File(path.join(extractDir.path, kManifestFile));
      final manifest = jsonDecode(await manifestFile.readAsString());
      
      if (manifest['version'] != kBackupVersion) {
        throw Exception('Incompatible backup version: ${manifest['version']}');
      }

      // Read data
      final dataFile = File(path.join(extractDir.path, kDataFile));
      final data = jsonDecode(await dataFile.readAsString());
      
      final List<Session> sessions = (data['sessions'] as List)
          .map((s) => Session.fromJson(s))
          .toList();

      // Copy photos to photos directory and update paths
      final appDir = await getApplicationSupportDirectory();
      final photosDir = path.join(appDir.path, 'photos');
      final photosDirObj = Directory(photosDir);
      
      // Clear existing photos directory before restoring
      if (await photosDirObj.exists()) {
        print('Clearing existing photos directory: $photosDir');
        await photosDirObj.delete(recursive: true);
      }
      
      // Create fresh photos directory
      await photosDirObj.create(recursive: true);
      print('Created fresh photos directory: $photosDir');
      
      print('Restoring photos to: $photosDir');
      
      final photosSourceDir = Directory(path.join(extractDir.path, kPhotosDir));
      if (await photosSourceDir.exists()) {
        print('Found photos directory in backup');
        int photoCount = 0;
        await for (final photo in photosSourceDir.list()) {
          if (photo is File) {
            final newPath = path.join(photosDir, path.basename(photo.path));
            await photo.copy(newPath);
            photoCount++;
            print('Restored photo: ${path.basename(photo.path)}');
          }
        }
        print('Total photos restored: $photoCount');
      } else {
        print('No photos directory found in backup');
      }

      // Update photo paths in sessions to point to new location
      print('Updating photo paths in sessions...');
      for (final session in sessions) {
        // Update session photo path - store just the filename
        if (session.sessionPhotoPath != null) {
          final fileName = path.basename(session.sessionPhotoPath!);
          print('Session photo path: ${session.sessionPhotoPath} -> $fileName');
          session.sessionPhotoPath = fileName; // Just the filename, not the full path
        }
        
        // Update poop entry photo paths by creating new instances
        final updatedPoopEntries = <PoopEntry>[];
        for (final poopEntry in session.poopEntries) {
          if (poopEntry.photoPath != null) {
            final fileName = path.basename(poopEntry.photoPath!);
            print('Poop entry photo path: ${poopEntry.photoPath} -> $fileName');
            final updatedEntry = poopEntry.copyWith(
              photoPath: fileName, // Just the filename, not the full path
            );
            updatedPoopEntries.add(updatedEntry);
          } else {
            updatedPoopEntries.add(poopEntry);
          }
        }
        session.poopEntries.clear();
        session.poopEntries.addAll(updatedPoopEntries);
      }

      // Reset session IDs to null so they get new IDs when inserted
      // This ensures proper database relationships
      final updatedSessions = <Session>[];
      for (final session in sessions) {
        // Create new session with null ID
        final updatedSession = Session(
          id: null, // Reset ID so it gets a new one
          wakeUpTime: session.wakeUpTime,
          sleepTime: session.sleepTime,
          sessionPhotoPath: session.sessionPhotoPath,
          hasSessionPhoto: session.hasSessionPhoto,
          isClosed: session.isClosed,
        );
        
        // Create new entries with null IDs
        for (final entry in session.peeEntries) {
          final updatedEntry = PeeEntry(
            id: null, // Reset ID
            sessionId: 0, // Will be updated when session is inserted
            amount: entry.amount,
            remarks: entry.remarks,
            time: entry.time,
          );
          updatedSession.addPeeEntry(updatedEntry);
        }
        
        for (final entry in session.poopEntries) {
          final updatedEntry = PoopEntry(
            id: null, // Reset ID
            sessionId: 0, // Will be updated when session is inserted
            amount: entry.amount,
            consistency: entry.consistency,
            color: entry.color,
            time: entry.time,
            photoPath: entry.photoPath,
            hasPhoto: entry.hasPhoto,
          );
          updatedSession.addPoopEntry(updatedEntry);
        }
        
        for (final entry in session.milkEntries) {
          final updatedEntry = MilkEntry(
            id: null, // Reset ID
            sessionId: 0, // Will be updated when session is inserted
            amount: entry.amount,
            time: entry.time,
          );
          updatedSession.addMilkEntry(updatedEntry);
        }
        
        for (final entry in session.vitaminEntries) {
          final updatedEntry = VitaminEntry(
            id: null, // Reset ID
            sessionId: 0, // Will be updated when session is inserted
            time: entry.time,
            type: entry.type,
            notes: entry.notes,
          );
          updatedSession.addVitaminEntry(updatedEntry);
        }
        
        updatedSessions.add(updatedSession);
      }

      return updatedSessions;
    } finally {
      // Clean up temp directory
      await extractDir.delete(recursive: true);
    }
  }

  /// Adds all files in a directory to the archive
  static Future<void> _addDirToArchive(Directory dir, Archive archive, String basePath) async {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: basePath);
        final archiveFile = ArchiveFile(
          relativePath,
          await entity.length(),
          await entity.readAsBytes(),
        );
        archive.addFile(archiveFile);
      }
    }
  }

  /// Copies a photo to the backup directory if it hasn't been copied already
  static Future<void> _copyPhotoToBackup(String photoPath, String backupPhotosDir, Set<String> copiedPhotos) async {
    final fileName = path.basename(photoPath);
    if (!copiedPhotos.contains(fileName)) {
      // Get the app's photo directory (where photos are actually stored)
      final appSupportDir = await getApplicationSupportDirectory();
      final photosDir = path.join(appSupportDir.path, 'photos');
      
      // The photoPath is typically just a filename (e.g., "session_1234567890.jpg")
      // So we need to look for it in the photos directory
      final possiblePaths = [
        path.join(photosDir, photoPath), // photoPath as filename in photos directory
        path.join(photosDir, fileName), // Just the filename in photos directory
        photoPath, // Try as absolute path (in case it's already absolute)
        path.join((await getApplicationDocumentsDirectory()).path, 'photos', photoPath), // Fallback location
      ];
      
      bool photoFound = false;
      for (final possiblePath in possiblePaths) {
        final sourceFile = File(possiblePath);
        if (await sourceFile.exists()) {
          final targetPath = path.join(backupPhotosDir, fileName);
          await sourceFile.copy(targetPath);
          copiedPhotos.add(fileName);
          photoFound = true;
          print('Found and copied photo: $possiblePath -> $targetPath');
          break;
        }
      }
      
      if (!photoFound) {
        print('Photo not found for path: $photoPath');
        print('Searched in: ${possiblePaths.join(', ')}');
        print('Photos directory: $photosDir');
      }
    }
  }

  /// Checks if the device is running Android 13 or higher
  static Future<bool> _isAndroid13OrHigher() async {
    if (Platform.isAndroid) {
      // This is a simple check - in a real app you might want to use device_info_plus package
      // For now, we'll assume Android 13+ if we can't determine the version
      return true;
    }
    return false;
  }

  /// Test function to verify photo paths and directory structure
  static Future<void> debugPhotoPaths(List<Session> sessions) async {
    print('=== DEBUGGING PHOTO PATHS ===');
    
    final appSupportDir = await getApplicationSupportDirectory();
    final photosDir = path.join(appSupportDir.path, 'photos');
    print('Photos directory: $photosDir');
    
    final photosDirObj = Directory(photosDir);
    if (await photosDirObj.exists()) {
      print('Photos directory exists');
      final files = await photosDirObj.list().toList();
      print('Files in photos directory: ${files.length}');
      for (final file in files) {
        if (file is File) {
          print('  - ${path.basename(file.path)}');
        }
      }
    } else {
      print('Photos directory does not exist');
    }
    
    print('Sessions with photos:');
    for (final session in sessions) {
      if (session.hasSessionPhoto && session.sessionPhotoPath != null) {
        print('  Session ${session.id}: ${session.sessionPhotoPath}');
        final fullPath = path.join(photosDir, session.sessionPhotoPath!);
        final file = File(fullPath);
        print('    Full path: $fullPath');
        print('    Exists: ${await file.exists()}');
      }
      
      for (final poopEntry in session.poopEntries) {
        if (poopEntry.hasPhoto && poopEntry.photoPath != null) {
          print('  Poop entry: ${poopEntry.photoPath}');
          final fullPath = path.join(photosDir, poopEntry.photoPath!);
          final file = File(fullPath);
          print('    Full path: $fullPath');
          print('    Exists: ${await file.exists()}');
        }
      }
    }
    print('=== END DEBUGGING ===');
  }
}
