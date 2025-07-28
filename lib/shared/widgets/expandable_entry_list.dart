import 'package:flutter/material.dart';

class ExpandableEntryListItem<T> {
  final T data;
  final Widget Function(T data, bool isExpanded) builder;
  final String Function(T data) summaryText;

  const ExpandableEntryListItem({
    required this.data,
    required this.builder,
    required this.summaryText,
  });
}

class ExpandableEntryList<T> extends StatefulWidget {
  final List<ExpandableEntryListItem<T>> items;
  final Widget? header;
  final int? initialExpandedIndex;
  final bool Function(T data)? shouldExpand;
  final bool Function(T data)? isComplete;

  const ExpandableEntryList({
    Key? key,
    required this.items,
    this.header,
    this.initialExpandedIndex,
    this.shouldExpand,
    this.isComplete,
  }) : super(key: key);

  @override
  State<ExpandableEntryList> createState() => _ExpandableEntryListState<T>();
}

class _ExpandableEntryListState<T> extends State<ExpandableEntryList<T>> {
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    // Use initialExpandedIndex if provided
    if (widget.initialExpandedIndex != null) {
      _expandedIndex = widget.initialExpandedIndex;
    }
    // If shouldExpand function is provided, find first entry that should be expanded
    else if (widget.shouldExpand != null) {
      _expandedIndex = widget.items.indexWhere((item) => widget.shouldExpand!(item.data));
      if (_expandedIndex == -1) _expandedIndex = null;
    }
    // Otherwise, expand the last entry (original behavior)
    else {
      _expandedIndex = widget.items.isEmpty ? null : widget.items.length - 1;
    }
  }

  @override
  void didUpdateWidget(ExpandableEntryList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If items were added, expand the newest one
    if (widget.items.length > oldWidget.items.length) {
      setState(() {
        _expandedIndex = widget.items.length - 1;
      });
    }
    // If items were removed, clear expansion to avoid expanding wrong entry
    else if (widget.items.length < oldWidget.items.length) {
      setState(() {
        _expandedIndex = null;
      });
    }
    // If initialExpandedIndex changed, update expanded index
    else if (widget.initialExpandedIndex != null && widget.initialExpandedIndex != oldWidget.initialExpandedIndex) {
      setState(() {
        _expandedIndex = widget.initialExpandedIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.header != null) ...[
          widget.header!,
          SizedBox(height: 8),
        ],
        ...widget.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isExpanded = index == _expandedIndex;

          final isEntryComplete = widget.isComplete?.call(item.data) ?? false;
          
          return Column(
            children: [
              if (index > 0) Divider(height: 1),
              Container(
                decoration: BoxDecoration(
                  color: isEntryComplete ? Colors.green.shade50 : null,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _expandedIndex = isExpanded ? null : index;
                    });
                  },
                  borderRadius: BorderRadius.circular(4.0),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.summaryText(item.data),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                          ],
                        ),
                        if (isExpanded) ...[
                          SizedBox(height: 8),
                          item.builder(item.data, true),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }
}
