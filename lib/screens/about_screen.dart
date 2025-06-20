import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('About Baby Daily'),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          _buildSection(
            context,
            title: 'Overview',
            content:
                'Baby Daily helps you track your baby\'s daily routine, from wake up to sleep time. '
                'Track feeding, diapering, and capture precious moments with photos.',
          ),
          _buildSection(
            context,
            title: 'Features',
            content:
                '• Session tracking (wake up to sleep)\n'
                '• Milk feeding tracking\n'
                '• Diaper change tracking (pee & poop)\n'
                '• Photo capturing\n'
                '• Session history\n'
                '• Analytics and insights\n'
                '• Backup and restore functionality',
          ),
          _buildSection(
            context,
            title: 'Backup & Restore',
            content:
                'Keep your data safe with our backup feature:\n\n'
                '• Create backups of all your data including photos\n'
                '• Share backups via your preferred method\n'
                '• Restore your data from backup files\n\n'
                'We recommend creating regular backups to prevent data loss.',
          ),
          _buildSection(
            context,
            title: 'Privacy',
            content:
                'Your data stays on your device. Backups are only created and shared when you choose to do so.',
          ),
          _buildSection(
            context,
            title: 'Version',
            content: '1.0.0',
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
