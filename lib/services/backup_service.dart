import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/milk_entry.dart';
import '../models/pee_entry.dart';
import '../models/poop_entry.dart';
import '../models/session.dart';
import '../models/vitamin_entry.dart';
import 'settings_service.dart';

// Progress callback type
typedef BackupProgressCallback = void Function(String message, double progress);

/// Backup analysis result
class BackupInfo {
  final int totalPhotos;
  final int totalChunks;
  final List<String> allPhotoPaths;
  final List<List<String>> chunkPhotoPaths;

  BackupInfo({
    required this.totalPhotos,
    required this.totalChunks,
    required this.allPhotoPaths,
    required this.chunkPhotoPaths,
  });
}

class BackupService {
  static const String kBackupVersion = '1.0.0';
  static const String kManifestFile = 'manifest.json';
  static const String kDataFile = 'data.json';
  static const String kPhotosDir = 'photos';

  /// Creates a backup of all app data and photos
  /// Returns the path to the created backup file
  static Future<String> createBackup(
    List<Session> sessions, {
    bool includePhotos = true,
    BackupProgressCallback? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final backupDir = await Directory(path.join(tempDir.path, 'backup')).create();

    try {
      onProgress?.call('Preparing backup...', 0.0);

      // Create manifest
      final manifest = {
        'version': kBackupVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'sessionCount': sessions.length,
        'includePhotos': includePhotos,
        'isChunked': false, // Will be updated if chunked
        'totalChunks': 1, // Will be updated if chunked
      };

      final manifestFile = File(path.join(backupDir.path, kManifestFile));
      await manifestFile.writeAsString(jsonEncode(manifest));

      onProgress?.call('Creating data backup...', 0.05);

      // Create data JSON
      final data = {
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

      final dataFile = File(path.join(backupDir.path, kDataFile));
      await dataFile.writeAsString(jsonEncode(data));

      if (includePhotos) {
        onProgress?.call('Analyzing photos and calculating chunks...', 0.1);

        // First pass: Count all photos and calculate chunks
        final backupInfo = await _analyzeBackupRequirements(sessions);
        final totalPhotos = backupInfo.totalPhotos;
        final totalChunks = backupInfo.totalChunks;
        final chunkingThreshold = SettingsService.instance.chunkingThreshold;

        print(
            'Backup analysis: $totalPhotos photos, $totalChunks chunks (threshold: $chunkingThreshold)');

        if (totalChunks > 1) {
          onProgress?.call('Large backup detected, creating $totalChunks chunks...', 0.15);
          return await _createChunkedBackup(sessions, backupInfo, onProgress);
        } else {
          // Single backup file
          return await _createSingleBackup(sessions, backupInfo, backupDir, onProgress);
        }
      } else {
        onProgress?.call('Creating final backup file...', 0.8);

        // Create zip archive with minimal memory usage
        final outputPath = path.join(
            tempDir.path, 'baby_daily_backup_${DateTime.now().millisecondsSinceEpoch}.zip');
        await _createZipArchiveMinimalMemory(backupDir, outputPath, onProgress);

        onProgress?.call('Backup completed!', 1.0);
        return outputPath;
      }
    } finally {
      // Clean up temp directory
      await backupDir.delete(recursive: true);
    }
  }

  /// Analyzes backup requirements and calculates chunk distribution
  static Future<BackupInfo> _analyzeBackupRequirements(List<Session> sessions) async {
    // Collect all photo paths
    final List<String> allPhotoPaths = [];

    for (final session in sessions) {
      // Session photos
      if (session.hasSessionPhoto && session.sessionPhotoPath != null) {
        allPhotoPaths.add(session.sessionPhotoPath!);
      }

      // Poop entry photos (only poop entries have photos)
      for (final poopEntry in session.poopEntries) {
        if (poopEntry.photoPath != null) {
          allPhotoPaths.add(poopEntry.photoPath!);
        }
      }
    }

    final totalPhotos = allPhotoPaths.length;
    final chunkingThreshold = SettingsService.instance.chunkingThreshold;
    final totalChunks =
        totalPhotos > chunkingThreshold ? (totalPhotos / chunkingThreshold).ceil() : 1;

    // Calculate chunk distribution
    final List<List<String>> chunkPhotoPaths = [];

    if (totalChunks > 1) {
      for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
        final startIndex = chunkIndex * chunkingThreshold;
        final endIndex = (startIndex + chunkingThreshold < totalPhotos)
            ? startIndex + chunkingThreshold
            : totalPhotos;

        final chunkPhotos = allPhotoPaths.sublist(startIndex, endIndex);
        chunkPhotoPaths.add(chunkPhotos);
      }
    } else {
      chunkPhotoPaths.add(allPhotoPaths);
    }

    return BackupInfo(
      totalPhotos: totalPhotos,
      totalChunks: totalChunks,
      allPhotoPaths: allPhotoPaths,
      chunkPhotoPaths: chunkPhotoPaths,
    );
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
      throw Exception(
          'Storage permission is required to save backup. Please grant permission in app settings.');
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
  static Future<List<Session>> restoreBackup(
    String backupPath, {
    BackupProgressCallback? onProgress,
    List<String>? chunkPaths, // Optional chunk paths for chunked backups
  }) async {
    onProgress?.call('Reading backup file...', 0.0);

    // Check if this is a chunked backup by looking at the file extension
    if (backupPath.endsWith('.json')) {
      return await _restoreChunkedBackup(backupPath, onProgress, chunkPaths);
    } else {
      return await _restoreSingleBackup(backupPath, onProgress);
    }
  }

  /// Restores data from a single backup file
  static Future<List<Session>> _restoreSingleBackup(
      String backupPath, BackupProgressCallback? onProgress) async {
    final tempDir = await getTemporaryDirectory();
    final extractDir = await Directory(path.join(tempDir.path, 'restore')).create();

    try {
      onProgress?.call('Extracting backup...', 0.1);

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

      onProgress?.call('Verifying backup...', 0.2);

      // Verify manifest
      final manifestFile = File(path.join(extractDir.path, kManifestFile));
      final manifest = jsonDecode(await manifestFile.readAsString());

      if (manifest['version'] != kBackupVersion) {
        throw Exception('Incompatible backup version: ${manifest['version']}');
      }

      onProgress?.call('Reading session data...', 0.3);

      // Read data
      final dataFile = File(path.join(extractDir.path, kDataFile));
      final data = jsonDecode(await dataFile.readAsString());

      final List<Session> sessions =
          (data['sessions'] as List).map((s) => Session.fromJson(s)).toList();

      if (manifest['includePhotos'] == true) {
        onProgress?.call('Restoring photos...', 0.4);

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
              print('Restored photo: ${path.basename(photo.path)} -> $newPath');

              // Update progress
              final progress = 0.4 + (0.4 * photoCount / (await photosSourceDir.list().length));
              onProgress?.call('Restored $photoCount photos...', progress);
            }
          }
          print('Total photos restored: $photoCount');
        } else {
          print('No photos directory found in backup');
        }

        onProgress?.call('Updating photo paths...', 0.8);

        // Update photo paths in sessions to point to new location
        print('Updating photo paths in sessions...');
        for (final session in sessions) {
          // Update session photo path - store just the filename
          if (session.sessionPhotoPath != null) {
            final fileName = path.basename(session.sessionPhotoPath!);
            print('Session photo path: ${session.sessionPhotoPath} -> $fileName');
            session.sessionPhotoPath = fileName; // Just the filename, not the full path
            session.hasSessionPhoto = true; // Ensure the flag is set
          }

          // Update poop entry photo paths by creating new instances
          final updatedPoopEntries = <PoopEntry>[];
          for (final poopEntry in session.poopEntries) {
            if (poopEntry.photoPath != null) {
              final fileName = path.basename(poopEntry.photoPath!);
              print('Poop entry photo path: ${poopEntry.photoPath} -> $fileName');
              final updatedEntry = poopEntry.copyWith(
                photoPath: fileName, // Just the filename, not the full path
                hasPhoto: true, // Ensure the flag is set
              );
              updatedPoopEntries.add(updatedEntry);
            } else {
              updatedPoopEntries.add(poopEntry);
            }
          }
          session.poopEntries.clear();
          session.poopEntries.addAll(updatedPoopEntries);
        }

        print('Photo path updates completed');
      }

      onProgress?.call('Preparing sessions for database...', 0.9);

      // Reset session IDs to null so they get new IDs when inserted
      // This ensures proper database relationships
      final updatedSessions = <Session>[];
      for (final session in sessions) {
        // Create new session with null ID
        final updatedSession = Session(
          id: null,
          // Reset ID so it gets a new one
          wakeUpTime: session.wakeUpTime,
          sleepTime: session.sleepTime,
          sessionPhotoPath: session.sessionPhotoPath,
          hasSessionPhoto: session.hasSessionPhoto,
          isClosed: session.isClosed,
        );

        // Create new entries with null IDs
        for (final entry in session.peeEntries) {
          final updatedEntry = PeeEntry(
            id: null,
            // Reset ID
            sessionId: 0,
            // Will be updated when session is inserted
            amount: entry.amount,
            remarks: entry.remarks,
            time: entry.time,
          );
          updatedSession.addPeeEntry(updatedEntry);
        }

        for (final entry in session.poopEntries) {
          final updatedEntry = PoopEntry(
            id: null,
            // Reset ID
            sessionId: 0,
            // Will be updated when session is inserted
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
            id: null,
            // Reset ID
            sessionId: 0,
            // Will be updated when session is inserted
            time: entry.time,
            type: entry.type,
            notes: entry.notes,
          );
          updatedSession.addVitaminEntry(updatedEntry);
        }

        updatedSessions.add(updatedSession);
      }

      onProgress?.call('Restore completed!', 1.0);

      // Debug: Check if photos were restored correctly
      await debugRestoredPhotos(updatedSessions);

      return updatedSessions;
    } finally {
      // Clean up temp directory
      await extractDir.delete(recursive: true);
    }
  }

  /// Restores data from a chunked backup
  static Future<List<Session>> _restoreChunkedBackup(
      String indexPath, BackupProgressCallback? onProgress, List<String>? chunkPaths) async {
    onProgress?.call('Reading chunked backup index...', 0.0);

    // Read the index file
    final indexData = jsonDecode(await File(indexPath).readAsString());

    if (indexData['isChunked'] != true) {
      throw Exception('Not a valid chunked backup index file');
    }

    final totalChunks = indexData['totalChunks'] as int;
    final chunks = indexData['chunks'] as List;

    onProgress?.call('Found $totalChunks backup chunks', 0.1);

    // Use provided chunkPaths if available, otherwise find them
    final List<String> actualChunkPaths;
    if (chunkPaths != null && chunkPaths.length == totalChunks) {
      actualChunkPaths = chunkPaths;
      print('Using provided chunk paths for restoration.');
    } else {
      actualChunkPaths = [];
      final indexDir = path.dirname(indexPath);
      for (final chunk in chunks) {
        final chunkFileName = chunk['filename'] as String;
        final chunkPath = path.join(indexDir, chunkFileName);
        if (await File(chunkPath).exists()) {
          actualChunkPaths.add(chunkPath);
        } else {
          throw Exception('Chunk file not found: $chunkFileName');
        }
      }
      print('Found ${actualChunkPaths.length} chunk files from index.');
    }

    // Set up photos directory for restoration
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

    // Process chunks one by one
    final List<Session> allSessions = [];
    final Set<String> restoredPhotos = <String>{};
    
    for (int chunkIndex = 0; chunkIndex < actualChunkPaths.length; chunkIndex++) {
      final chunkPath = actualChunkPaths[chunkIndex];
      
      onProgress?.call('Processing chunk ${chunkIndex + 1}/$totalChunks...', 0.2 + (0.6 * chunkIndex / totalChunks));
      
      // Extract chunk to temporary directory
      final tempDir = await getTemporaryDirectory();
      final extractDir = await Directory(path.join(tempDir.path, 'chunk_$chunkIndex')).create();
      
      try {
        // Extract chunk
        final chunkBytes = await File(chunkPath).readAsBytes();
        final chunkArchive = ZipDecoder().decodeBytes(chunkBytes);
        
        for (final file in chunkArchive) {
          if (file.isFile) {
            final data = file.content as List<int>;
            final filePath = path.join(extractDir.path, file.name);
            await File(filePath).create(recursive: true);
            await File(filePath).writeAsBytes(data);
          }
        }
        
        // Verify manifest
        final manifestFile = File(path.join(extractDir.path, kManifestFile));
        if (await manifestFile.exists()) {
          final manifest = jsonDecode(await manifestFile.readAsString());
          if (manifest['version'] != kBackupVersion) {
            throw Exception('Incompatible backup version: ${manifest['version']}');
          }
        }
        
        // Read sessions from this chunk
        final dataFile = File(path.join(extractDir.path, kDataFile));
        if (await dataFile.exists()) {
          final data = jsonDecode(await dataFile.readAsString());
          final List<Session> chunkSessions = (data['sessions'] as List)
              .map((s) => Session.fromJson(s))
              .toList();
          
          // For the first chunk, use all sessions
          // For subsequent chunks, we only need to update photo paths
          if (chunkIndex == 0) {
            allSessions.addAll(chunkSessions);
          }
        }
        
        // Extract photos from this chunk
        final photosSourceDir = Directory(path.join(extractDir.path, kPhotosDir));
        if (await photosSourceDir.exists()) {
          await for (final photo in photosSourceDir.list()) {
            if (photo is File) {
              final photoFileName = path.basename(photo.path);
              
              // Only copy if not already restored (avoid duplicates)
              if (!restoredPhotos.contains(photoFileName)) {
                final newPath = path.join(photosDir, photoFileName);
                await photo.copy(newPath);
                restoredPhotos.add(photoFileName);
                print('Restored photo from chunk ${chunkIndex + 1}: $photoFileName');
              }
            }
          }
        }
        
      } finally {
        // Clean up temporary extraction directory
        await extractDir.delete(recursive: true);
      }
    }
    
    onProgress?.call('Updating photo paths...', 0.8);
    
    // Update photo paths in all sessions to point to new location
    print('Updating photo paths in sessions...');
    for (final session in allSessions) {
      // Update session photo path - store just the filename
      if (session.sessionPhotoPath != null) {
        final fileName = path.basename(session.sessionPhotoPath!);
        print('Session photo path: ${session.sessionPhotoPath} -> $fileName');
        session.sessionPhotoPath = fileName; // Just the filename, not the full path
        session.hasSessionPhoto = true; // Ensure the flag is set
      }
      
      // Update poop entry photo paths by creating new instances
      final updatedPoopEntries = <PoopEntry>[];
      for (final poopEntry in session.poopEntries) {
        if (poopEntry.photoPath != null) {
          final fileName = path.basename(poopEntry.photoPath!);
          print('Poop entry photo path: ${poopEntry.photoPath} -> $fileName');
          final updatedEntry = poopEntry.copyWith(
            photoPath: fileName, // Just the filename, not the full path
            hasPhoto: true, // Ensure the flag is set
          );
          updatedPoopEntries.add(updatedEntry);
        } else {
          updatedPoopEntries.add(poopEntry);
        }
      }
      session.poopEntries.clear();
      session.poopEntries.addAll(updatedPoopEntries);
    }
    
    print('Photo path updates completed');
    print('Total photos restored: ${restoredPhotos.length}');
    print('Total sessions: ${allSessions.length}');

    onProgress?.call('Preparing sessions for database...', 0.9);

    // Reset session IDs to null so they get new IDs when inserted
    // This ensures proper database relationships
    final updatedSessions = <Session>[];
    for (final session in allSessions) {
      // Create new session with null ID
      final updatedSession = Session(
        id: null, // Reset ID so it gets a new one
        wakeUpTime: session.wakeUpTime,
        sleepTime: session.sleepTime,
        sessionPhotoPath: session.sessionPhotoPath,
        hasSessionPhoto: session.hasSessionPhoto || session.sessionPhotoPath != null,
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
          hasPhoto: entry.hasPhoto || entry.photoPath != null,
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

    onProgress?.call('Restore completed!', 1.0);
    
    // Debug: Check if photos were restored correctly
    await debugRestoredPhotos(updatedSessions);
    
    return updatedSessions;
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

  /// Creates a ZIP archive using minimal memory to prevent out of memory errors
  static Future<void> _createZipArchiveMinimalMemory(
      Directory backupDir, String outputPath, BackupProgressCallback? onProgress) async {
    print('Creating ZIP archive with minimal memory...');
    final zipEncoder = ZipEncoder();
    final archive = Archive();

    int fileCount = 0;
    final files = await backupDir.list(recursive: true).toList();
    final totalFiles = files.length;

    for (final entity in files) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: backupDir.path);

        // Read file in chunks to minimize memory usage
        final fileSize = await entity.length();
        List<int> fileBytes;

        if (fileSize > 512 * 1024) {
          // If file is larger than 512KB
          // Read large files in smaller chunks
          final stream = entity.openRead();
          final chunks = <int>[];
          await for (final chunk in stream) {
            chunks.addAll(chunk);
            // Allow other operations to proceed
            await Future.delayed(Duration(milliseconds: 1));
          }
          fileBytes = chunks;
        } else {
          // Read small files normally
          fileBytes = await entity.readAsBytes();
        }

        final archiveFile = ArchiveFile(relativePath, fileBytes.length, fileBytes);
        archive.addFile(archiveFile);

        fileCount++;
        print(
            'Added file $fileCount/$totalFiles to archive: $relativePath (${fileBytes.length} bytes)');

        // Update progress for ZIP creation
        final zipProgress = 0.8 + (0.15 * fileCount / totalFiles);
        onProgress?.call('Adding file $fileCount/$totalFiles to archive...', zipProgress);

        // Small delay to prevent UI lag
        if (fileCount % 5 == 0) {
          await Future.delayed(Duration(milliseconds: 10));
        }
      }
    }

    print('Writing ZIP archive to: $outputPath');
    onProgress?.call('Writing final backup file...', 0.95);

    final outputFile = File(outputPath);
    final zipBytes = zipEncoder.encode(archive);
    if (zipBytes != null) {
      await outputFile.writeAsBytes(zipBytes);
      print('ZIP archive created successfully: ${zipBytes.length} bytes');
    } else {
      throw Exception('Failed to create ZIP archive');
    }
  }

  /// Copies a photo to the backup directory if it hasn't been copied already
  static Future<void> _copyPhotoToBackup(
      String photoPath, String backupPhotosDir, Set<String> copiedPhotos) async {
    final fileName = path.basename(photoPath);
    if (!copiedPhotos.contains(fileName)) {
      // Get the app's photo directory (where photos are actually stored)
      final appSupportDir = await getApplicationSupportDirectory();
      final photosDir = path.join(appSupportDir.path, 'photos');

      // The photoPath is typically just a filename (e.g., "session_1234567890.jpg")
      // So we need to look for it in the photos directory
      final possiblePaths = [
        path.join(photosDir, photoPath),
        // photoPath as filename in photos directory
        path.join(photosDir, fileName),
        // Just the filename in photos directory
        photoPath,
        // Try as absolute path (in case it's already absolute)
        path.join((await getApplicationDocumentsDirectory()).path, 'photos', photoPath),
        // Fallback location
      ];

      bool photoFound = false;
      for (final possiblePath in possiblePaths) {
        final sourceFile = File(possiblePath);
        if (await sourceFile.exists()) {
          final targetPath = path.join(backupPhotosDir, fileName);

          // Use streaming copy for all files to minimize memory usage
          final fileSize = await sourceFile.length();
          if (fileSize > 256 * 1024) {
            // If file is larger than 256KB
            // Stream copy for large files
            final targetFile = File(targetPath);
            final sink = targetFile.openWrite();
            await sourceFile.openRead().pipe(sink);
            await sink.close();
            print('Stream copied large photo: $possiblePath -> $targetPath (${fileSize} bytes)');
          } else {
            // Regular copy for small files
            await sourceFile.copy(targetPath);
            print('Copied photo: $possiblePath -> $targetPath (${fileSize} bytes)');
          }

          copiedPhotos.add(fileName);
          photoFound = true;
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

  /// Debug method to check photo restoration after backup restore
  static Future<void> debugRestoredPhotos(List<Session> sessions) async {
    print('=== DEBUGGING RESTORED PHOTOS ===');

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

    print('Restored sessions with photos:');
    for (final session in sessions) {
      if (session.hasSessionPhoto && session.sessionPhotoPath != null) {
        print('  Session ${session.id}: ${session.sessionPhotoPath}');
        final fullPath = path.join(photosDir, session.sessionPhotoPath!);
        final file = File(fullPath);
        print('    Full path: $fullPath');
        print('    Exists: ${await file.exists()}');
        if (await file.exists()) {
          final fileSize = await file.length();
          print('    File size: $fileSize bytes');
        }
      }

      for (final poopEntry in session.poopEntries) {
        if (poopEntry.hasPhoto && poopEntry.photoPath != null) {
          print('  Poop entry: ${poopEntry.photoPath}');
          final fullPath = path.join(photosDir, poopEntry.photoPath!);
          final file = File(fullPath);
          print('    Full path: $fullPath');
          print('    Exists: ${await file.exists()}');
          if (await file.exists()) {
            final fileSize = await file.length();
            print('    File size: $fileSize bytes');
          }
        }
      }
    }
    print('=== END DEBUGGING RESTORED PHOTOS ===');
  }

  /// Creates a single backup file with all photos
  static Future<String> _createSingleBackup(
    List<Session> sessions,
    BackupInfo backupInfo,
    Directory backupDir,
    BackupProgressCallback? onProgress,
  ) async {
    onProgress?.call('Copying photos...', 0.2);

    // Copy photos one at a time to minimize memory usage
    final photosDir = Directory(path.join(backupDir.path, kPhotosDir));
    await photosDir.create();

    final Set<String> copiedPhotos = {};

    // Process photos one at a time to minimize memory usage
    for (int i = 0; i < backupInfo.allPhotoPaths.length; i++) {
      final photoPath = backupInfo.allPhotoPaths[i];

      // Process single photo
      await _copyPhotoToBackup(photoPath, photosDir.path, copiedPhotos);

      // Update progress based on total chunks (even for single backup, treat as 1 chunk)
      final progress = 0.2 + (0.6 * (i + 1) / backupInfo.allPhotoPaths.length);
      onProgress?.call('Copying photo ${i + 1}/${backupInfo.allPhotoPaths.length}...', progress);

      // Force garbage collection and delay after every photo
      await Future.delayed(Duration(milliseconds: 200));
    }

    onProgress?.call('Creating final backup file...', 0.8);

    // Create zip archive with minimal memory usage
    final outputPath = path.join(
        backupDir.parent.path, 'baby_daily_backup_${DateTime.now().millisecondsSinceEpoch}.zip');
    await _createZipArchiveMinimalMemory(backupDir, outputPath, onProgress);

    onProgress?.call('Backup completed!', 1.0);
    return outputPath;
  }

  /// Creates multiple backup chunks for large photo collections
  static Future<String> _createChunkedBackup(
    List<Session> sessions,
    BackupInfo backupInfo,
    BackupProgressCallback? onProgress,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final totalChunks = backupInfo.totalChunks;

    onProgress?.call('Creating $totalChunks backup chunks...', 0.2);

    // Create chunks
    final List<String> chunkPaths = [];

    for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
      final chunkPhotos = backupInfo.chunkPhotoPaths[chunkIndex];

      onProgress?.call('Creating chunk ${chunkIndex + 1}/$totalChunks...',
          0.2 + (0.6 * chunkIndex / totalChunks));

      // Create chunk backup
      final chunkPath = await _createBackupChunk(
        sessions,
        chunkPhotos,
        chunkIndex,
        totalChunks,
        timestamp,
        onProgress,
      );

      chunkPaths.add(chunkPath);
    }

    onProgress?.call('Creating chunk index file...', 0.8);

    // Create index file that lists all chunks
    final indexPath = await _createChunkIndex(chunkPaths, timestamp);

    onProgress?.call('Chunked backup completed!', 1.0);

    // Return the index file path - the chunks are separate files
    return indexPath;
  }

  /// Creates a single backup chunk
  static Future<String> _createBackupChunk(
    List<Session> sessions,
    List<String> chunkPhotoPaths,
    int chunkIndex,
    int totalChunks,
    int timestamp,
    BackupProgressCallback? onProgress,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final chunkDir = await Directory(path.join(tempDir.path, 'backup_chunk_$chunkIndex')).create();

    try {
      // Create manifest for this chunk
      final manifest = {
        'version': kBackupVersion,
        'timestamp': DateTime.now().toIso8601String(),
        'sessionCount': sessions.length,
        'includePhotos': true,
        'isChunked': true,
        'chunkIndex': chunkIndex,
        'totalChunks': totalChunks,
        'photoCount': chunkPhotoPaths.length,
        'backupTimestamp': timestamp,
      };

      final manifestFile = File(path.join(chunkDir.path, kManifestFile));
      await manifestFile.writeAsString(jsonEncode(manifest));

      // Create data JSON (same for all chunks)
      final data = {
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

      final dataFile = File(path.join(chunkDir.path, kDataFile));
      await dataFile.writeAsString(jsonEncode(data));

      // Copy photos for this chunk
      final photosDir = Directory(path.join(chunkDir.path, kPhotosDir));
      await photosDir.create();

      final Set<String> copiedPhotos = {};

      for (int i = 0; i < chunkPhotoPaths.length; i++) {
        final photoPath = chunkPhotoPaths[i];
        await _copyPhotoToBackup(photoPath, photosDir.path, copiedPhotos);

        // Update progress within chunk - this chunk represents 0.6/totalChunks of total progress
        final chunkStartProgress = 0.2 + (0.6 * chunkIndex / totalChunks);
        final chunkEndProgress = 0.2 + (0.6 * (chunkIndex + 1) / totalChunks);
        final progressWithinChunk = (i + 1) / chunkPhotoPaths.length;
        final totalProgress =
            chunkStartProgress + (chunkEndProgress - chunkStartProgress) * progressWithinChunk;

        onProgress?.call(
            'Chunk ${chunkIndex + 1}: Photo ${i + 1}/${chunkPhotoPaths.length}...', totalProgress);

        await Future.delayed(Duration(milliseconds: 200));
      }

      // Create chunk zip file
      final chunkPath = path.join(tempDir.path,
          'baby_daily_backup_chunk_${chunkIndex + 1}_of_${totalChunks}_$timestamp.zip');
      await _createZipArchiveMinimalMemory(chunkDir, chunkPath, null);

      return chunkPath;
    } finally {
      await chunkDir.delete(recursive: true);
    }
  }

  /// Creates an index file for chunked backups
  static Future<String> _createChunkIndex(List<String> chunkPaths, int timestamp) async {
    final tempDir = await getTemporaryDirectory();

    final index = {
      'version': kBackupVersion,
      'timestamp': DateTime.now().toIso8601String(),
      'isChunked': true,
      'totalChunks': chunkPaths.length,
      'backupTimestamp': timestamp,
      'chunks': chunkPaths
          .map((chunkPath) => {
                'path': chunkPath,
                'filename': chunkPath.split('/').last,
              })
          .toList(),
    };

    final indexPath = path.join(tempDir.path, 'baby_daily_backup_index_$timestamp.json');
    final indexFile = File(indexPath);
    await indexFile.writeAsString(jsonEncode(index));

    return indexPath;
  }
}
