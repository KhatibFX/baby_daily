import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/poop_entry.dart';
import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../session_utils.dart';
import '../session_widgets.dart';
import 'expandable_entry_list.dart';
import 'session_photo_card.dart';

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
              ExpandableEntryList<MapEntry<int, PoopEntry>>(
                items: session.poopEntries.asMap().entries.map((entry) {
                  return ExpandableEntryListItem(
                    data: entry,
                    summaryText: (data) =>
                        '${data.value.amount.name}, ${data.value.consistency.name}, ${data.value.color.name} at ${_formatTime(data.value.time)}${data.value.hasPhoto ? ' 📷' : ''}',
                    builder: (data, isExpanded) => _PoopEntryItem(
                      entry: data.value,
                      session: session,
                      isEditing: isEditing,
                      onUpdate: (updatedEntry) async {
                        if (!session.isClosed && data.value.id != null) {
                          final provider = context.read<SessionProvider>();
                          final updatedEntries = List.of(session.poopEntries);
                          updatedEntries[data.key] = updatedEntry;
                          await provider.updateSessionWithPoopEntries(
                              session.copyWith(poopEntries: updatedEntries));
                        } else {
                          final updatedEntries = List.of(session.poopEntries);
                          updatedEntries[data.key] = updatedEntry;
                          onSessionChanged(session.copyWith(poopEntries: updatedEntries));
                        }
                      },
                      onDelete: () async {
                        if (!session.isClosed && data.value.id != null) {
                          final provider = context.read<SessionProvider>();
                          await provider.deletePoopEntry(
                            data.value.id!,
                            session.id!,
                            photoPath: data.value.photoPath,
                          );
                        } else {
                          final updatedEntries = List.of(session.poopEntries)..removeAt(data.key);
                          onSessionChanged(session.copyWith(poopEntries: updatedEntries));
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
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
        time: await getValidEntryTime(
            context: context, time: truncateToMinute(DateTime.now()), session: session),
      );
    } else {
      // In edit screen - keep in memory only
      final newEntry = PoopEntry(
        sessionId: session.id!,
        amount: PoopAmount.na,
        consistency: PoopConsistency.normal,
        color: PoopColor.yellow,
        time: await getValidEntryTime(
            context: context, time: truncateToMinute(DateTime.now()), session: session),
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
  final VoidCallback onDelete;

  const _PoopEntryItem({
    Key? key,
    required this.entry,
    required this.session,
    required this.isEditing,
    required this.onUpdate,
    required this.onDelete,
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
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                FocusScope.of(context).unfocus();
                onDelete();
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
            onValidate: (time) =>
                isValidActivityTime(context: context, time: time, session: session),
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
    if (entry.color != PoopColor.abnormal) {
      return Container();
    }

    return SessionPhotoCard(
      session: session,
      onSessionChanged: (updatedSession) {
        // Find this entry in the updated session's poop entries and call onUpdate with it
        final updatedEntry =
            updatedSession.poopEntries.firstWhere((e) => e.id == entry.id || e.time == entry.time);
        onUpdate(updatedEntry);
      },
      title: 'Abnormal Poop Photo',
      photoPrefix: 'poop',
      photoPath: entry.photoPath,
      hasPhoto: entry.hasPhoto,
      isEditing: isEditing,
      updatePhotoInSession: (session, photoPath, hasPhoto) {
        // Create a copy of the session with the updated poop entry
        final updatedEntry = entry.copyWith(photoPath: photoPath, hasPhoto: hasPhoto);
        final entryIndex =
            session.poopEntries.indexWhere((e) => e.id == entry.id || e.time == entry.time);
        final updatedEntries = List.of(session.poopEntries);
        updatedEntries[entryIndex] = updatedEntry;
        return session.copyWith(poopEntries: updatedEntries);
      },
    );
  }
}
