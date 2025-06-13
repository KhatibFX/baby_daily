import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import '../../models/poop_entry.dart';
import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../session_utils.dart';
import '../session_widgets.dart';

class PoopSectionCard extends StatelessWidget {
  final Session session;
  final Function(Session) onSessionChanged;
  final bool isEditing;

  const PoopSectionCard({
    Key? key,
    required this.session,
    required this.onSessionChanged,
    this.isEditing = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Poop',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _addNewPoopEntry(context);
                  },
                ),
              ],
            ),
            SizedBox(height: 8),
            if (session.poopEntries.isEmpty)
              Center(
                child: Text('No poop entries recorded'),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: session.poopEntries.length,
                separatorBuilder: (context, index) => Divider(),
                itemBuilder: (context, index) {
                  final entry = session.poopEntries[index];
                  return _PoopEntryItem(
                    entry: entry,
                    session: session,
                    isEditing: isEditing,
                    onUpdate: (updatedEntry) async {
                      if (!session.isClosed && entry.id != null) {
                        // In session screen - persist immediately through provider
                        final provider = context.read<SessionProvider>();
                        final updatedEntries = List.of(session.poopEntries);
                        updatedEntries[index] = updatedEntry;
                        await provider.updateSession(session.copyWith(poopEntries: updatedEntries));
                      } else {
                        // In edit screen - only update memory
                        final updatedEntries = List.of(session.poopEntries);
                        updatedEntries[index] = updatedEntry;
                        onSessionChanged(session.copyWith(poopEntries: updatedEntries));
                      }
                    },
                    onDelete: () async {
                      if (!session.isClosed && entry.id != null) {
                        // In session screen - persist immediately through provider
                        final provider = context.read<SessionProvider>();
                        await provider.deletePoopEntry(entry.id!, session.id!,
                            photoPath: entry.photoPath);
                      } else {
                        // In edit screen or entry without ID - just update memory
                        final updatedEntries = List.of(session.poopEntries)..removeAt(index);
                        onSessionChanged(session.copyWith(poopEntries: updatedEntries));
                      }
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addNewPoopEntry(BuildContext context) async {
    if (session.id == null) return;

    if (!session.isClosed) {
      // In session screen - persist immediately through provider
      final provider = context.read<SessionProvider>();
      await provider.addPoopEntry(
        sessionId: session.id!,
        amount: PoopAmount.na,
        consistency: PoopConsistency.normal,
        color: PoopColor.yellow,
        time: truncateToMinute(DateTime.now()),
      );
    } else {
      // In edit screen - keep in memory only
      final newEntry = PoopEntry(
        sessionId: session.id!,
        amount: PoopAmount.na,
        consistency: PoopConsistency.normal,
        color: PoopColor.yellow,
        time: truncateToMinute(DateTime.now()),
      );
      onSessionChanged(session.copyWith(
        poopEntries: List.of(session.poopEntries)..add(newEntry),
      ));
    }
  }
}

class _PoopEntryItem extends StatelessWidget {
  final PoopEntry entry;
  final Session session;
  final bool isEditing;
  final Function(PoopEntry) onUpdate;
  final VoidCallback? onDelete;

  const _PoopEntryItem({
    Key? key,
    required this.entry,
    required this.session,
    required this.isEditing,
    required this.onUpdate,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.read<SessionProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount'),
                  Wrap(
                    spacing: 8.0,
                    children: PoopAmount.values.map((amount) {
                      return ChoiceChip(
                        label: Text(amount.name),
                        selected: entry.amount == amount,
                        onSelected: (selected) {
                          if (selected) {
                            onUpdate(entry.copyWith(
                              amount: amount,
                              consistency: amount == PoopAmount.na
                                  ? PoopConsistency.normal
                                  : entry.consistency,
                              color: amount == PoopAmount.na ? PoopColor.yellow : entry.color,
                            ));
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  onDelete!();
                },
              ),
          ],
        ),
        if (entry.amount != PoopAmount.na) ...[
          SizedBox(height: 8),
          TimePickerRow(
            time: entry.time,
            placeholder: 'Time not set',
            icon: Icons.access_time,
            firstDate: session.wakeUpTime,
            lastDate: session.sleepTime ?? DateTime.now(),
            onValidate: (time) => isValidActivityTime(context, time, session, sessionProvider),
            onTimeSelected: (time) {
              onUpdate(entry.copyWith(time: time));
            },
          ),
          Text('Consistency'),
          SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: PoopConsistency.values.map((consistency) {
              return ChoiceChip(
                label: Text(consistency.name),
                selected: entry.consistency == consistency,
                onSelected: (selected) {
                  if (selected) {
                    onUpdate(entry.copyWith(consistency: consistency));
                  }
                },
              );
            }).toList(),
          ),
          Text('Color'),
          SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: PoopColor.values.map((color) {
              return ChoiceChip(
                label: Text(color.name),
                selected: entry.color == color,
                onSelected: (selected) {
                  if (selected) {
                    onUpdate(entry.copyWith(color: color));
                  }
                },
              );
            }).toList(),
          ),
          if (entry.color == PoopColor.abnormal) ...[
            SizedBox(height: 16),
            _buildPhotoSection(context, sessionProvider),
          ],
        ],
      ],
    );
  }

  Widget _buildPhotoSection(BuildContext context, SessionProvider sessionProvider) {
    if (!isEditing && !entry.hasPhoto) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Abnormal Poop Photo'),
        SizedBox(height: 8),
        if (entry.hasPhoto && entry.photoPath != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.file(
              File(entry.photoPath!),
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          if (isEditing) ...[
            SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _deletePhoto(context, sessionProvider),
              icon: Icon(Icons.delete),
              label: Text('Delete Photo'),
            ),
          ],
        ] else if (isEditing) ...[
          ElevatedButton.icon(
            onPressed: () => _takePhoto(context, sessionProvider),
            icon: Icon(Icons.camera_alt),
            label: Text('Take Photo'),
          ),
        ],
      ],
    );
  }

  Future<void> _takePhoto(BuildContext context, SessionProvider sessionProvider) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      final String photoFileName = 'poop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String photoPath = path.join(path.dirname(image.path), photoFileName);

      // Move the temporary file to a permanent location
      await File(image.path).copy(photoPath);
      await File(image.path).delete();

      onUpdate(entry.copyWith(photoPath: photoPath, hasPhoto: true));
    }
  }

  Future<void> _deletePhoto(BuildContext context, SessionProvider sessionProvider) async {
    if (entry.photoPath != null) {
      final file = File(entry.photoPath!);
      if (await file.exists()) {
        await file.delete();
      }
      onUpdate(entry.copyWith(photoPath: null, hasPhoto: false));
    }
  }
}
