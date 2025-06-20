import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/session_provider.dart';
import '../services/backup_service.dart';

class BackupRestoreScreen extends StatelessWidget {
  Future<void> _createAndShareBackup(BuildContext context) async {
    try {
      final provider = Provider.of<SessionProvider>(context, listen: false);
      final sessions = await provider.getAllSessions();

      final backupPath = await BackupService.createBackup(sessions);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(backupPath)],
        subject: 'Baby Daily Backup',
      ));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create backup: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restoreFromBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null) {
        final file = result.files.single;
        final provider = Provider.of<SessionProvider>(context, listen: false);

        // Show confirmation dialog
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirm Restore'),
            content: Text('This will replace all current data with the backup data. '
                'This action cannot be undone. Are you sure you want to continue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: Text('Restore'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          // Show progress dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(
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
          Navigator.of(context).pop();

          // Update provider with restored sessions
          await provider.restoreFromBackup(sessions);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup restored successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore backup: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
