import 'dart:io';
import 'dart:convert'; // Added for jsonDecode
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;

import '../providers/session_provider.dart';
import '../services/backup_service.dart';
import '../services/settings_service.dart';
import '../models/session.dart';

// Progress callback type for the dialog
typedef ProgressUpdateCallback = void Function(String message, double progress);

class _BackupProgressDialog extends StatefulWidget {
  final bool includePhotos;
  final List<Session> sessions;

  const _BackupProgressDialog({
    required this.includePhotos,
    required this.sessions,
  });

  @override
  State<_BackupProgressDialog> createState() => _BackupProgressDialogState();
}

class _BackupProgressDialogState extends State<_BackupProgressDialog> {
  String _message = 'Preparing backup...';
  double _progress = 0.0;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Start the backup process
    _startBackup();
  }

  Future<void> _startBackup() async {
    try {
      final backupPath = await BackupService.createBackup(
        widget.sessions,
        includePhotos: widget.includePhotos,
        onProgress: (message, progress) {
          if (mounted) {
            setState(() {
              _message = message;
              _progress = progress;
            });
          }
        },
      );

      if (mounted) {
        // Close dialog and return the backup path
        Navigator.of(context).pop(backupPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
        // Wait a moment then close with error
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Backup Failed',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                widget.includePhotos ? 'Creating backup with photos...' : 'Creating data backup...',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                _message,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final SettingsService _settingsService = SettingsService.instance;
  int _chunkingThreshold = 50;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settingsService.initialize();
    setState(() {
      _chunkingThreshold = _settingsService.chunkingThreshold;
      _isLoading = false;
    });
  }

  Future<void> _updateChunkingThreshold(int value) async {
    setState(() {
      _chunkingThreshold = value;
    });
    await _settingsService.setChunkingThreshold(value);
  }

  Widget _buildPresetButton(int value, String label) {
    return Expanded(
      child: TextButton(
        onPressed: () => _updateChunkingThreshold(value),
        style: TextButton.styleFrom(
          foregroundColor: _chunkingThreshold == value ? Theme.of(context).colorScheme.primary : null,
        ),
        child: Text(label),
      ),
    );
  }

  Future<void> _createBackup(BuildContext context) async {
    final provider = Provider.of<SessionProvider>(context, listen: false);
    final sessions = provider.sessions;

    if (sessions.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sessions to backup')),
        );
      }
      return;
    }

    // Ask user if they want to include photos
    bool? includePhotos;
    if (context.mounted) {
      includePhotos = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Include Photos?'),
          content: const Text('Do you want to include photos in the backup? This will make the backup larger but will preserve all your photos.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Data Only'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Include Photos'),
            ),
          ],
        ),
      );
    }

    if (includePhotos == null) return; // User cancelled

    // Show progress dialog
    if (context.mounted) {
      final backupPath = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _BackupProgressDialog(
          includePhotos: includePhotos!,
          sessions: sessions,
        ),
      );

      if (backupPath != null && context.mounted) {
        // Show options dialog
        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Backup Created'),
            content: backupPath.endsWith('.json') 
                ? const Text('Your chunked backup has been created successfully. The index file and chunk files are ready to be shared or saved.')
                : const Text('Your backup has been created successfully. What would you like to do with it?'),
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
          if (backupPath.endsWith('.json')) {
            await _shareChunkedBackup(backupPath);
          } else {
            await Share.shareXFiles([XFile(backupPath)], text: 'Baby Daily Backup');
          }
        } else if (action == 'save' && Platform.isAndroid) {
          try {
            final savedPath = await BackupService.saveBackupToAndroid(backupPath);
            if (context.mounted && savedPath != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Backup saved to: $savedPath')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save backup: ${e.toString()}')),
              );
            }
          }
        }
      }
    }
  }

  Future<void> _restoreFromBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'], // Allow both single backups and chunked backup index files
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
          // Show progress dialog with detailed progress tracking
          String progressMessage = 'Reading backup file...';
          double progressValue = 0.0;
          
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => StatefulBuilder(
              builder: (context, setState) => Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text(
                          'Restoring backup...',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(value: progressValue),
                        const SizedBox(height: 8),
                        Text(
                          progressMessage,
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(progressValue * 100).toInt()}%',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

          // Restore the backup
          final sessions = await BackupService.restoreBackup(
            file.path!,
            onProgress: (message, progress) {
              if (context.mounted) {
                // Update the dialog state
                progressMessage = message;
                progressValue = progress;
                // Force rebuild of the dialog
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => StatefulBuilder(
                    builder: (context, setState) => Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              const Text(
                                'Restoring backup...',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(value: progressValue),
                              const SizedBox(height: 8),
                              Text(
                                progressMessage,
                                style: const TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(progressValue * 100).toInt()}%',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
            },
          );

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

  Future<void> _shareChunkedBackup(String indexPath) async {
    try {
      // Read the index file to get all chunk paths
      final indexData = jsonDecode(await File(indexPath).readAsString());
      final chunks = indexData['chunks'] as List;
      
      // Collect all file paths (index + chunks)
      final List<String> allFilePaths = [indexPath];
      for (final chunk in chunks) {
        final chunkPath = chunk['path'] as String;
        if (await File(chunkPath).exists()) {
          allFilePaths.add(chunkPath);
        }
      }
      
      // Share all files
      await SharePlus.instance.share(ShareParams(
        files: allFilePaths.map((path) => XFile(path)).toList(),
        subject: 'Baby Daily Chunked Backup',
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share chunked backup: ${e.toString()}'),
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
                      'The backup can be shared or saved for later use. '
                      'Large backups with many photos are processed efficiently to prevent memory issues.',
                    ),
                    SizedBox(height: 16),
                    if (!_isLoading) ...[
                      Text(
                        'Chunking Threshold: $_chunkingThreshold photos per chunk',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Lower values create smaller chunks but more files. Higher values may cause memory issues on older devices.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('10'),
                          Expanded(
                            child: Slider(
                              value: _chunkingThreshold.toDouble(),
                              min: 10,
                              max: 200,
                              divisions: 19,
                              label: _chunkingThreshold.toString(),
                              onChanged: (value) {
                                _updateChunkingThreshold(value.toInt());
                              },
                            ),
                          ),
                          const Text('200'),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildPresetButton(10, 'Small'),
                          _buildPresetButton(25, 'Medium'),
                          _buildPresetButton(50, 'Large'),
                          _buildPresetButton(100, 'Extra Large'),
                        ],
                      ),
                      SizedBox(height: 16),
                    ],
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _createBackup(context),
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
