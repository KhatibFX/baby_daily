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

  const ExpandableEntryList({
    Key? key,
    required this.items,
    this.header,
    this.initialExpandedIndex,
  }) : super(key: key);

  @override
  State<ExpandableEntryList> createState() => _ExpandableEntryListState<T>();
}

class _ExpandableEntryListState<T> extends State<ExpandableEntryList<T>> {
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    // Use initialExpandedIndex if provided, otherwise expand the last entry
    _expandedIndex = widget.initialExpandedIndex ?? (widget.items.isEmpty ? null : widget.items.length - 1);
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

          return Column(
            children: [
              if (index > 0) Divider(height: 1),
              InkWell(
                onTap: () {
                  setState(() {
                    _expandedIndex = isExpanded ? null : index;
                  });
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: isExpanded
                      ? item.builder(item.data, true)
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.summaryText(item.data),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Icon(Icons.expand_more),
                          ],
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
