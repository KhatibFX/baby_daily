import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums/vitamin_enums.dart';
import '../../models/session.dart';
import '../../models/vitamin_entry.dart';
import '../../providers/session_provider.dart';
import '../session_utils.dart';
import '../session_widgets.dart';
import 'expandable_entry_list.dart';

class VitaminSectionCard extends StatelessWidget {
  final Session session;
  final Function(Session) onSessionChanged;

  const VitaminSectionCard({
    Key? key,
    required this.session,
    required this.onSessionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with legacy vitamin AD toggle and add button
            Row(
              children: [
                Text(
                  'Vitamin',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _addNewVitaminEntry(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (session.vitaminEntries.isEmpty)
              const Center(
                child: Text('No vitamin entries recorded'),
              )
            else
              ExpandableEntryList<MapEntry<int, VitaminEntry>>(
                items: session.vitaminEntries.asMap().entries.map((entry) {
                  return ExpandableEntryListItem(
                    data: entry,
                    summaryText: (data) =>
                        '${data.value.type?.label ?? 'Not set'} at ${_formatTime(data.value.time)}${data.value.notes?.isNotEmpty == true ? ' - ${data.value.notes}' : ''}',
                    builder: (data, isExpanded) => _VitaminEntryItem(
                      entry: data.value,
                      session: session,
                      onUpdate: (updatedEntry) async {
                        if (!session.isClosed && data.value.id != null) {
                          final provider = context.read<SessionProvider>();
                          final updatedEntries = List.of(session.vitaminEntries);
                          updatedEntries[data.key] = updatedEntry;
                          await provider.updateSessionWithVitaminEntries(
                              session.copyWith(vitaminEntries: updatedEntries));
                        } else {
                          final updatedEntries = List.of(session.vitaminEntries);
                          updatedEntries[data.key] = updatedEntry;
                          onSessionChanged(session.copyWith(vitaminEntries: updatedEntries));
                        }
                      },
                      onDelete: () async {
                        if (!session.isClosed && data.value.id != null) {
                          final provider = context.read<SessionProvider>();
                          await provider.deleteVitaminEntry(data.value.id!, session.id!);
                        } else {
                          final updatedEntries = List.of(session.vitaminEntries)
                            ..removeAt(data.key);
                          onSessionChanged(session.copyWith(vitaminEntries: updatedEntries));
                        }
                      },
                    ),
                  );
                }).toList(),
                shouldExpand: (data) => !data.value.isComplete,
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _addNewVitaminEntry(BuildContext context) async {
    if (session.id == null) return;

    // Check if all existing vitamin entries are complete
    final incompleteEntries = session.vitaminEntries.where((entry) => !entry.isComplete).toList();
    if (incompleteEntries.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete all existing vitamin entries before adding a new one'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!session.isClosed) {
      // In session screen - persist immediately through provider
      final provider = context.read<SessionProvider>();
      await provider.addVitaminEntry(
        sessionId: session.id!,
        time: await getValidEntryTime(
            session: session, time: truncateToMinute(DateTime.now()), context: context),
      );
    } else {
      // In edit screen - keep in memory only
      final newEntry = VitaminEntry(
        sessionId: session.id!,
        time: await getValidEntryTime(
            session: session, time: truncateToMinute(DateTime.now()), context: context),
      );
      onSessionChanged(session.copyWith(
        vitaminEntries: List.of(session.vitaminEntries)..add(newEntry),
      ));
    }
  }
}

class _VitaminEntryItem extends StatefulWidget {
  final VitaminEntry entry;
  final Session session;
  final Function(VitaminEntry) onUpdate;
  final VoidCallback onDelete;

  const _VitaminEntryItem({
    Key? key,
    required this.entry,
    required this.session,
    required this.onUpdate,
    required this.onDelete,
  }) : super(key: key);

  @override
  _VitaminEntryItemState createState() => _VitaminEntryItemState();
}

class _VitaminEntryItemState extends State<_VitaminEntryItem> {
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.entry.notes);
  }

  @override
  void didUpdateWidget(_VitaminEntryItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry.notes != _notesController.text) {
      _notesController.text = widget.entry.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8.0,
                children: VitaminType.values.map((type) {
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: type == VitaminType.ad
                                ? Colors.orange
                                : Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(type.label),
                      ],
                    ),
                    selected: widget.entry.type == type,
                    onSelected: (selected) {
                      if (selected) {
                        widget.onUpdate(widget.entry.copyWith(type: type));
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                FocusScope.of(context).unfocus();
                widget.onDelete();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        TimePickerRow(
          time: widget.entry.time,
          placeholder: 'Time not set',
          icon: Icons.access_time,
          firstDate: widget.session.wakeUpTime,
          lastDate: widget.session.sleepTime ?? DateTime.now(),
          onValidate: (time) =>
              isValidActivityTime(context: context, time: time, session: widget.session),
          onTimeSelected: (time) {
            widget.onUpdate(widget.entry.copyWith(time: time));
          },
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Notes (Optional)',
            hintText: 'Add any additional notes...',
            border: OutlineInputBorder(),
          ),
          controller: _notesController,
          maxLines: 2,
          minLines: 1,
          onChanged: (value) {
            widget.onUpdate(widget.entry.copyWith(notes: value));
          },
        ),
      ],
    );
  }
}
