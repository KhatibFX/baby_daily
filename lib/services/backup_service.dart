import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import '../models/session.dart';
import '../models/pee_entry.dart';
import '../models/poop_entry.dart';
import '../models/milk_entry.dart';

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
      
      // Handle session photos
      for (final session in sessions) {
        if (session.hasSessionPhoto && session.sessionPhotoPath != null) {
          await _copyPhotoToBackup(session.sessionPhotoPath!, photosDir.path, copiedPhotos);
        }
        
        // Handle poop photos
        for (final poopEntry in session.poopEntries) {
          if (poopEntry.photoPath != null) {
            await _copyPhotoToBackup(poopEntry.photoPath!, photosDir.path, copiedPhotos);
          }
        }
      }

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

      // Copy photos to photos directory
      final appDir = await getApplicationSupportDirectory();
      final photosDir = path.join(appDir.path, 'photos');
      final photosDirObj = Directory(photosDir);
      if (!await photosDirObj.exists()) {
        await photosDirObj.create(recursive: true);
      }
      
      final photosSourceDir = Directory(path.join(extractDir.path, kPhotosDir));
      if (await photosSourceDir.exists()) {
        await for (final photo in photosSourceDir.list()) {
          if (photo is File) {
            final newPath = path.join(photosDir, path.basename(photo.path));
            await photo.copy(newPath);
          }
        }
      }

      return sessions;
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
      final appDir = await getApplicationDocumentsDirectory();
      final sourceFile = File(path.join(appDir.path, photoPath));
      if (await sourceFile.exists()) {
        final targetPath = path.join(backupPhotosDir, fileName);
        await sourceFile.copy(targetPath);
        copiedPhotos.add(fileName);
      }
    }
  }
}
