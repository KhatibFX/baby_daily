import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/session.dart';
import '../../models/milk_entry.dart';
import '../../providers/session_provider.dart';
import '../session_utils.dart';
import '../session_widgets.dart';
import '../shared.dart';

class MilkSectionCard extends StatelessWidget {
  final Session session;
  final Function(Session) onSessionChanged;

  const MilkSectionCard({
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
                  'Milk Intake',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _addNewMilkEntry(context);
                  },
                ),
              ],
            ),
            SizedBox(height: 8),
            if (session.totalMilkIntake > 0)
              Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Total: ${session.totalMilkIntake} ml',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            if (session.milkEntries.isEmpty)
              Center(
                child: Text('No milk intake recorded'),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: session.milkEntries.length,
                separatorBuilder: (context, index) => Divider(),
                itemBuilder: (context, index) {
                  final entry = session.milkEntries[index];
                  return _buildMilkEntry(context, entry);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _addNewMilkEntry(BuildContext context) async {
    if (session.id == null) return;
    
    if (!session.isClosed) {
      // In session screen - persist immediately to DB
      // The provider will handle updating the UI through notifyListeners
      final provider = context.read<SessionProvider>();
      await provider.addMilkEntry(
        sessionId: session.id!,
        amount: 0,
        time: truncateToMinute(DateTime.now()),
      );
    } else {
      // In edit screen - keep in memory only
      final newEntry = MilkEntry(
        sessionId: session.id!,
        amount: 0,
        time: truncateToMinute(DateTime.now()),
      );
      onSessionChanged(session.copyWith(
        milkEntries: List.of(session.milkEntries)..add(newEntry),
      ));
    }
  }

  Widget _buildMilkEntry(BuildContext context, MilkEntry entry) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        _showEditDialog(context, entry);
      },
      child: Card(
        // ...existing entry card UI code...
      ),
    );
  }

  void _showEditDialog(BuildContext context, MilkEntry entry) {
    // Implementation for showing edit dialog
  }
}

class _MilkEntryItem extends StatefulWidget {
  final MilkEntry entry;
  final Session session;
  final Function(MilkEntry) onUpdate;
  final VoidCallback? onDelete;

  const _MilkEntryItem({
    Key? key,
    required this.entry,
    required this.session,
    required this.onUpdate,
    this.onDelete,
  }) : super(key: key);

  @override
  _MilkEntryItemState createState() => _MilkEntryItemState();
}

class _MilkEntryItemState extends State<_MilkEntryItem> {
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.entry.amount.toString());
  }

  @override
  void didUpdateWidget(_MilkEntryItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry.amount.toString() != _amountController.text) {
      _amountController.text = widget.entry.amount.toString();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.read<SessionProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Amount (ml)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                controller: _amountController,
                onChanged: (value) {
                  FocusScope.of(context).unfocus();
                  final amount = int.tryParse(value) ?? 0;
                  widget.onUpdate(widget.entry.copyWith(amount: amount));
                },
              ),
            ),
            if (widget.onDelete != null) ...[
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: widget.onDelete,
              ),
            ],
          ],
        ),
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
      ],
    );
  }
}
