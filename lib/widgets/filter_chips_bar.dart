import 'package:flutter/material.dart';

class FilterChipItem {
  const FilterChipItem({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;
}

/// Horizontally scrolling chips for the active filters, each with a delete
/// icon. Collapses to nothing when [items] is empty.
class FilterChipsBar extends StatelessWidget {
  const FilterChipsBar({super.key, required this.items});

  final List<FilterChipItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          return InputChip(
            label: Text(item.label),
            onDeleted: item.onDeleted,
            deleteButtonTooltipMessage: 'Hapus filter',
          );
        },
      ),
    );
  }
}
