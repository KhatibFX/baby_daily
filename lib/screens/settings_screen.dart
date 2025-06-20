import 'package:baby_daily/models/session.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/session_provider.dart';
import '../services/excel_service.dart';
import './about_screen.dart';
import './backup_restore_screen.dart';

class SettingsScreen extends StatelessWidget {
  Future<void> _exportToExcel(BuildContext context, List<Session> sessions) async {
    try {
      final filePath = await ExcelService.exportToExcel(sessions);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(filePath)],
        subject: 'Baby Daily Sessions',
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export sessions: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _buildSection(
          context,
          title: 'Data Management',
          children: [
            ListTile(
              leading: Icon(Icons.backup),
              title: Text('Backup & Restore'),
              subtitle: Text('Create or restore data backups'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BackupRestoreScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.calculate),
              title: Text('Export to Excel'),
              subtitle: Text('Export session data to Excel'),
              onTap: () async {
                try {
                  final provider = Provider.of<SessionProvider>(context, listen: false);
                  final sessions = await provider.getAllSessions();
                  if (context.mounted) {
                    await _exportToExcel(context, sessions);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to export: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
        _buildSection(
          context,
          title: 'App Information',
          children: [
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('About'),
              subtitle: Text('About Baby Daily'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AboutScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        Card(
          margin: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}
