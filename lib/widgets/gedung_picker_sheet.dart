import 'package:flutter/material.dart';
import 'package:qrscan/models/gedung_model.dart';
import 'package:qrscan/services/app_scope.dart';
import 'package:qrscan/services/reference_repository.dart';
import 'package:qrscan/theme/app_tokens.dart';
import 'package:qrscan/widgets/empty_state.dart';

/// Result of [showGedungPicker]. A cleared selection is `GedungPick(null)`;
/// a dismissed sheet returns null instead.
class GedungPick {
  const GedungPick(this.gedung);

  final Gedung? gedung;
}

/// Full-height sheet to choose a building. Any node of the tree can be picked.
Future<GedungPick?> showGedungPicker(
  BuildContext context, {
  int? selectedId,
  bool allowClear = true,
}) {
  return showModalBottomSheet<GedungPick>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _GedungPickerSheet(selectedId: selectedId, allowClear: allowClear),
  );
}

class _GedungPickerSheet extends StatefulWidget {
  const _GedungPickerSheet({
    required this.selectedId,
    required this.allowClear,
  });

  final int? selectedId;
  final bool allowClear;

  @override
  State<_GedungPickerSheet> createState() => _GedungPickerSheetState();
}

class _GedungPickerSheetState extends State<_GedungPickerSheet> {
  final _searchCtrl = TextEditingController();
  final Set<int> _expanded = {};

  ReferenceRepository? _refs;
  String _query = '';
  String? _loadError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_refs == null) {
      _refs = AppScope.of(context).references;
      _initExpanded(_refs!.tree);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Roots start expanded one level; the selected node is made visible.
  void _initExpanded(GedungTree tree) {
    for (final root in tree.roots) {
      if (tree.childrenOf(root.id).isNotEmpty) _expanded.add(root.id);
    }
    var current = widget.selectedId == null
        ? null
        : tree.byId(widget.selectedId!);
    final seen = <int>{};
    while (current != null && seen.add(current.id)) {
      final parent = current.parentId;
      if (parent == null) break;
      _expanded.add(parent);
      current = tree.byId(parent);
    }
  }

  Future<void> _reload() async {
    final refs = _refs!;
    setState(() => _loadError = null);
    try {
      await refs.load(force: true);
      if (!mounted) return;
      setState(() => _initExpanded(refs.tree));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Gagal memuat daftar gedung.');
    }
  }

  void _toggle(int id) {
    setState(() {
      if (!_expanded.remove(id)) _expanded.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height * 0.85;
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pilih Gedung',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (widget.allowClear && widget.selectedId != null)
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop(const GedungPick(null)),
                      child: const Text('Hapus Pilihan'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Cari gedung...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Bersihkan',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _refs!,
                builder: (context, _) => _buildList(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final refs = _refs!;
    final tree = refs.tree;

    if (tree.isEmpty) {
      if (refs.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return EmptyState(
        icon: Icons.apartment_outlined,
        title: 'Daftar gedung belum tersedia',
        message: _loadError ?? 'Periksa koneksi lalu muat ulang.',
        actionLabel: 'Muat ulang',
        onAction: _reload,
      );
    }

    final searching = _query.trim().isNotEmpty;
    if (searching) {
      final hits = tree.search(_query);
      if (hits.isEmpty) {
        return const EmptyState(
          icon: Icons.search_off,
          title: 'Gedung tidak ditemukan',
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: hits.length,
        itemBuilder: (context, i) => _GedungRowTile(
          gedung: hits[i],
          depth: 0,
          hasChildren: false,
          expanded: false,
          selected: hits[i].id == widget.selectedId,
          onSelect: () => Navigator.of(context).pop(GedungPick(hits[i])),
        ),
      );
    }

    final rows = tree.flatten(_expanded);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        return _GedungRowTile(
          gedung: row.gedung,
          depth: row.depth,
          hasChildren: row.hasChildren,
          expanded: _expanded.contains(row.gedung.id),
          selected: row.gedung.id == widget.selectedId,
          onToggle: () => _toggle(row.gedung.id),
          onSelect: () => Navigator.of(context).pop(GedungPick(row.gedung)),
        );
      },
    );
  }
}

class _GedungRowTile extends StatelessWidget {
  const _GedungRowTile({
    required this.gedung,
    required this.depth,
    required this.hasChildren,
    required this.expanded,
    required this.selected,
    required this.onSelect,
    this.onToggle,
  });

  final Gedung gedung;
  final int depth;
  final bool hasChildren;
  final bool expanded;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return InkWell(
      onTap: onSelect,
      child: Padding(
        padding: EdgeInsets.only(left: 8 + depth * 16.0, right: 16),
        child: Row(
          children: [
            if (hasChildren && onToggle != null)
              IconButton(
                tooltip: expanded ? 'Ciutkan' : 'Bentangkan',
                icon: Icon(expanded ? Icons.expand_more : Icons.chevron_right),
                onPressed: onToggle,
              )
            else
              const SizedBox(width: 48, height: 48),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  gedung.label,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
            if (selected) Icon(Icons.check, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
