import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/session.dart';
import '../../models/pee_entry.dart';
import '../../providers/session_provider.dart';
import '../session_utils.dart';
import '../session_widgets.dart';
import '../shared.dart';

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
                      final updatedEntries = List.of(session.peeEntries);
                      updatedEntries[index] = updatedEntry;
                      onSessionChanged(session.copyWith(peeEntries: updatedEntries));
                      
                      // The database update will happen when the user saves the session
                      if (session.isClosed) {
                        final provider = context.read<SessionProvider>();
                        await provider.updateSession(session.copyWith(peeEntries: updatedEntries));
                      }
                    },
                    onDelete: entry.id != null ? () async {
                      final provider = context.read<SessionProvider>();
                      final success = await provider.deletePeeEntry(entry.id!, session.id!);
                      if (success) {
                        final updatedEntries = List.of(session.peeEntries)..removeAt(index);
                        onSessionChanged(session.copyWith(peeEntries: updatedEntries));
                      }
                    } : null,
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
    
    final provider = context.read<SessionProvider>();
    await provider.addPeeEntry(
      sessionId: session.id!,
      amount: PeeAmount.na,
      time: truncateToMinute(DateTime.now()),
    );
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

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Column(
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
                  onPressed: widget.onDelete,
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
              onValidate: (time) => isValidActivityTime(context, time, widget.session, sessionProvider),
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
      ),
    );
  }
}
