import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;

import '../providers/session_provider.dart';
import '../services/backup_service.dart';

class BackupRestoreScreen extends StatelessWidget {
  const BackupRestoreScreen({super.key});

  Future<void> _createAndShareBackup(BuildContext context) async {
    try {
      final provider = Provider.of<SessionProvider>(context, listen: false);
      final sessions = await provider.getAllSessions();

      if (sessions.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No data to backup'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show progress dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Creating backup...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final backupPath = await BackupService.createBackup(sessions);

      // Close progress dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show options dialog
      if (context.mounted) {
        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Backup Created'),
            content: const Text('Your backup has been created successfully. What would you like to do with it?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('share'),
                child: const Text('Share'),
              ),
              if (Platform.isAndroid)
                TextButton(
                  onPressed: () => Navigator.of(context).pop('save'),
                  child: const Text('Save to Downloads'),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('cancel'),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

        if (action == 'share') {
          await SharePlus.instance.share(ShareParams(
            files: [XFile(backupPath)],
            subject: 'Baby Daily Backup',
          ));
        } else if (action == 'save' && Platform.isAndroid) {
          try {
            final savedPath = await BackupService.saveBackupToAndroid(backupPath);
            if (savedPath != null && context.mounted) {
              final fileName = path.basename(savedPath);
              final isDownloads = savedPath.contains('Download') || savedPath.contains('Downloads');
              final location = isDownloads ? 'Downloads folder' : 'app backup folder';
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Backup saved to $location: $fileName'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'OK',
                    onPressed: () {},
                  ),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              final errorMessage = e.toString();
              if (errorMessage.contains('permission')) {
                // Show permission guidance dialog
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Permission Required'),
                    content: const Text(
                      'To save backups to your device, the app needs storage permission. '
                      'Please go to your device settings and grant storage permission to this app.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to save to Downloads: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 4),
                  ),
                );
              }
            }
          }
        }
      }

      // Clean up temp file
      try {
        await File(backupPath).delete();
      } catch (e) {
        // Ignore cleanup errors
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create backup: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreFromBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null && context.mounted) {
        final file = result.files.single;
        final provider = Provider.of<SessionProvider>(context, listen: false);

        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Restore'),
            content: const Text('This will replace all current data with the backup data. '
                'This action cannot be undone. Are you sure you want to continue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('Restore'),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          // Show progress dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Restoring backup...'),
                    ],
                  ),
                ),
              ),
            ),
          );

          // Restore the backup
          final sessions = await BackupService.restoreBackup(file.path!);

          // Close progress dialog
          if (context.mounted) {
            Navigator.of(context).pop();
          }

          // Update provider with restored sessions
          await provider.restoreFromBackup(sessions);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Backup restored successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore backup: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Backup & Restore'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backup',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Create a backup of all your data including photos. '
                      'The backup can be shared or saved for later use.',
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _createAndShareBackup(context),
                      icon: Icon(Icons.backup),
                      label: Text('Create Backup'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Restore',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Restore your data from a backup file. '
                      'Warning: This will replace all current data.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _restoreFromBackup(context),
                      icon: Icon(Icons.restore),
                      label: Text('Restore from Backup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
