import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pee_entry.dart';
import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../session_utils.dart';
import '../session_widgets.dart';

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
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: session.peeEntries.length,
                separatorBuilder: (context, index) => Divider(),
                itemBuilder: (context, index) {
                  final entry = session.peeEntries[index];
                  return _PeeEntryItem(
                    entry: entry,
                    session: session,
                    onUpdate: (updatedEntry) async {
                      if (!session.isClosed && entry.id != null) {
                        // In session screen - persist immediately through provider
                        final provider = context.read<SessionProvider>();
                        final updatedEntries = List.of(session.peeEntries);
                        updatedEntries[index] = updatedEntry;
                        await provider.updateSession(session.copyWith(peeEntries: updatedEntries));
                      } else {
                        // In edit screen - only update memory
                        final updatedEntries = List.of(session.peeEntries);
                        updatedEntries[index] = updatedEntry;
                        onSessionChanged(session.copyWith(peeEntries: updatedEntries));
                      }
                    },
                    onDelete: () async {
                      if (!session.isClosed && entry.id != null) {
                        // In session screen - persist immediately through provider
                        final provider = context.read<SessionProvider>();
                        await provider.deletePeeEntry(entry.id!, session.id!);
                      } else {
                        // In edit screen or entry without ID - just update memory
                        final updatedEntries = List.of(session.peeEntries)..removeAt(index);
                        onSessionChanged(session.copyWith(peeEntries: updatedEntries));
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

  Future<void> _addNewPeeEntry(BuildContext context) async {
    if (session.id == null) return;

    if (!session.isClosed) {
      // In session screen - persist immediately through provider
      final provider = context.read<SessionProvider>();
      await provider.addPeeEntry(
        sessionId: session.id!,
        amount: PeeAmount.na,
        time: truncateToMinute(DateTime.now()),
      );
    } else {
      // In edit screen - keep in memory only
      final newEntry = PeeEntry(
        sessionId: session.id!,
        amount: PeeAmount.na,
        time: truncateToMinute(DateTime.now()),
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
  final VoidCallback? onDelete;

  const _PeeEntryItem({
    Key? key,
    required this.entry,
    required this.session,
    required this.onUpdate,
    this.onDelete,
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
    final sessionProvider = context.read<SessionProvider>();

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
            if (widget.onDelete != null)
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  widget.onDelete!();
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
                isValidActivityTime(context, time, widget.session, sessionProvider),
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
