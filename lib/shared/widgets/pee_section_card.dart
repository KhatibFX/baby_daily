import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pee_entry.dart';
import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../session_utils.dart';
import '../session_widgets.dart';
import 'expandable_entry_list.dart';

class PeeSectionCard extends StatelessWidget {
  final Session session;
  final Function(Session) onSessionChanged;

  const PeeSectionCard({
    Key? key,
    required this.session,
    required this.onSessionChanged,
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
                  'Pee',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _addNewPeeEntry(context);
                  },
                ),
              ],
            ),
            SizedBox(height: 8),
            if (session.peeEntries.isEmpty)
              Center(
                child: Text('No pee entries recorded'),
              )
            else
              ExpandableEntryList<MapEntry<int, PeeEntry>>(
                items: session.peeEntries.asMap().entries.map((entry) {
                  return ExpandableEntryListItem(
                    data: entry,
                    summaryText: (data) =>
                        '${data.value.amount.name} at ${_formatTime(data.value.time)}${data.value.remarks?.isNotEmpty == true ? ' - ${data.value.remarks}' : ''}',
                    builder: (data, isExpanded) => _PeeEntryItem(
                      entry: data.value,
                      session: session,
                      onUpdate: (updatedEntry) async {
                        if (!session.isClosed && data.value.id != null) {
                          final provider = context.read<SessionProvider>();
                          final updatedEntries = List.of(session.peeEntries);
                          updatedEntries[data.key] = updatedEntry;
                          await provider.updateSessionWithPeeEntries(
                              session.copyWith(peeEntries: updatedEntries));
                        } else {
                          final updatedEntries = List.of(session.peeEntries);
                          updatedEntries[data.key] = updatedEntry;
                          onSessionChanged(session.copyWith(peeEntries: updatedEntries));
                        }
                      },
                      onDelete: () async {
                        if (!session.isClosed && data.value.id != null) {
                          final provider = context.read<SessionProvider>();
                          await provider.deletePeeEntry(data.value.id!, session.id!);
                        } else {
                          final updatedEntries = List.of(session.peeEntries)..removeAt(data.key);
                          onSessionChanged(session.copyWith(peeEntries: updatedEntries));
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

  Future<void> _addNewPeeEntry(BuildContext context) async {
    if (session.id == null) return;

    if (!session.isClosed) {
      // In session screen - persist immediately through provider
      final provider = context.read<SessionProvider>();
      await provider.addPeeEntry(
        sessionId: session.id!,
        amount: PeeAmount.na,
        time: await getValidEntryTime(
            context: context, time: truncateToMinute(DateTime.now()), session: session),
      );
    } else {
      // In edit screen - keep in memory only
      final newEntry = PeeEntry(
        sessionId: session.id!,
        amount: PeeAmount.na,
        time: await getValidEntryTime(
            context: context, time: truncateToMinute(DateTime.now()), session: session),
      );
      onSessionChanged(session.copyWith(
        peeEntries: List.of(session.peeEntries)..add(newEntry),
      ));
    }
  }
}

class _PeeEntryItem extends StatefulWidget {
  final PeeEntry entry;
  final Session session;
  final Function(PeeEntry) onUpdate;
  final VoidCallback onDelete;

  const _PeeEntryItem({
    Key? key,
    required this.entry,
    required this.session,
    required this.onUpdate,
    required this.onDelete,
  }) : super(key: key);

  @override
  _PeeEntryItemState createState() => _PeeEntryItemState();
}

class _PeeEntryItemState extends State<_PeeEntryItem> {
  late TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController(text: widget.entry.remarks);
  }

  @override
  void didUpdateWidget(_PeeEntryItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry.remarks != _remarksController.text) {
      _remarksController.text = widget.entry.remarks ?? '';
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
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
                children: PeeAmount.values.map((amount) {
                  return ChoiceChip(
                    label: Text(amount.name),
                    selected: widget.entry.amount == amount,
                    onSelected: (selected) {
                      if (selected) {
                        widget.onUpdate(widget.entry.copyWith(amount: amount));
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                FocusScope.of(context).unfocus();
                widget.onDelete();
              },
            ),
          ],
        ),
        if (widget.entry.amount != PeeAmount.na) ...[
          SizedBox(height: 8),
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
          SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              labelText: 'Remarks',
              border: OutlineInputBorder(),
            ),
            controller: _remarksController,
            onChanged: (value) {
              widget.onUpdate(widget.entry.copyWith(remarks: value));
            },
          ),
        ],
      ],
    );
  }
}
