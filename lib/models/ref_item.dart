class RefItem {
  const RefItem({required this.id, required this.name, this.slug});

  final int id;
  final String name;
  final String? slug;

  factory RefItem.fromJson(Map<String, dynamic> json) => RefItem(
    id: (json['id'] as num).toInt(),
    name: json['name']?.toString() ?? '',
    slug: json['slug']?.toString(),
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'slug': slug};

  /// Parses a list, skipping entries that are not JSON objects.
  static List<RefItem> listFromJson(dynamic json) {
    if (json is! List) return const [];
    final result = <RefItem>[];
    for (final e in json) {
      if (e is Map && e['id'] is num) {
        result.add(RefItem.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is RefItem && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
