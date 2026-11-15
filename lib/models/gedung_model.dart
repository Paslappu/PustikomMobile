class Gedung {
  const Gedung({
    required this.id,
    required this.name,
    required this.label,
    this.lokasi,
    this.parentId,
    this.photoUrl,
  });

  final int id;
  final String name;
  final String? lokasi;

  /// Full display label from the server (for example "Gedung A > Lantai 2").
  final String label;
  final int? parentId;
  final String? photoUrl;

  factory Gedung.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    final label = json['label']?.toString();
    return Gedung(
      id: (json['id'] as num).toInt(),
      name: name,
      lokasi: json['lokasi']?.toString(),
      label: (label == null || label.isEmpty) ? name : label,
      parentId: (json['parent_id'] as num?)?.toInt(),
      photoUrl: json['photo_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lokasi': lokasi,
    'label': label,
    'parent_id': parentId,
    'photo_url': photoUrl,
  };

  static List<Gedung> listFromJson(dynamic json) {
    if (json is! List) return const [];
    final result = <Gedung>[];
    for (final e in json) {
      if (e is Map && e['id'] is num) {
        result.add(Gedung.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return result;
  }
}

class GedungRow {
  const GedungRow({
    required this.gedung,
    required this.depth,
    required this.hasChildren,
  });

  final Gedung gedung;
  final int depth;
  final bool hasChildren;
}

/// Parent/child view over a flat list of [Gedung].
class GedungTree {
  GedungTree._(this._byId, this._children, this.roots);

  final Map<int, Gedung> _byId;
  final Map<int, List<Gedung>> _children;
  final List<Gedung> roots;

  static final GedungTree empty = GedungTree.build(const []);

  factory GedungTree.build(List<Gedung> all) {
    final byId = <int, Gedung>{for (final g in all) g.id: g};
    final children = <int, List<Gedung>>{};
    final roots = <Gedung>[];

    for (final g in byId.values) {
      final parent = g.parentId;
      if (parent == null || parent == g.id || !byId.containsKey(parent)) {
        roots.add(g);
      } else {
        children.putIfAbsent(parent, () => []).add(g);
      }
    }

    int byName(Gedung a, Gedung b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    roots.sort(byName);
    for (final list in children.values) {
      list.sort(byName);
    }

    // Nodes caught in a parent cycle are not reachable from any root. Walk
    // from the roots with a visited set, then promote leftovers to roots.
    final visited = <int>{};
    void visit(Gedung g) {
      if (!visited.add(g.id)) return;
      for (final c in children[g.id] ?? const <Gedung>[]) {
        visit(c);
      }
    }

    for (final r in roots) {
      visit(r);
    }
    final leftovers = byId.values.where((g) => !visited.contains(g.id)).toList()
      ..sort(byName);
    for (final g in leftovers) {
      if (visited.contains(g.id)) continue;
      roots.add(g);
      visit(g);
    }

    return GedungTree._(byId, children, roots);
  }

  bool get isEmpty => _byId.isEmpty;

  Gedung? byId(int id) => _byId[id];

  List<Gedung> childrenOf(int id) => _children[id] ?? const [];

  /// Depth-first rows. Children are listed only below expanded nodes.
  List<GedungRow> flatten(Set<int> expanded) {
    final rows = <GedungRow>[];
    final seen = <int>{};
    void walk(Gedung g, int depth) {
      if (!seen.add(g.id)) return;
      final kids = childrenOf(g.id);
      rows.add(
        GedungRow(gedung: g, depth: depth, hasChildren: kids.isNotEmpty),
      );
      if (kids.isNotEmpty && expanded.contains(g.id)) {
        for (final c in kids) {
          walk(c, depth + 1);
        }
      }
    }

    for (final r in roots) {
      walk(r, 0);
    }
    return rows;
  }

  /// Case-insensitive contains on label or name, as a flat list.
  List<Gedung> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final hits = _byId.values
        .where(
          (g) =>
              g.label.toLowerCase().contains(q) ||
              g.name.toLowerCase().contains(q),
        )
        .toList();
    hits.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return hits;
  }
}
