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

  const ExpandableEntryList({
    Key? key,
    required this.items,
    this.header,
  }) : super(key: key);

  @override
  State<ExpandableEntryList> createState() => _ExpandableEntryListState<T>();
}

class _ExpandableEntryListState<T> extends State<ExpandableEntryList<T>> {
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    // Expand the last entry by default
    if (widget.items.isNotEmpty) {
      _expandedIndex = widget.items.length - 1;
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
