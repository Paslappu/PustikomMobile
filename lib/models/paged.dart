class Paged<T> {
  const Paged({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  /// Parses a Laravel resource collection (`data` + `meta`). Non-object
  /// entries in `data` are skipped.
  factory Paged.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final data = json['data'];
    final items = <T>[];
    if (data is List) {
      for (final e in data) {
        if (e is Map) items.add(parse(Map<String, dynamic>.from(e)));
      }
    }
    final meta = json['meta'];
    int metaInt(String key, int fallback) =>
        meta is Map && meta[key] is num ? (meta[key] as num).toInt() : fallback;
    return Paged(
      items: items,
      currentPage: metaInt('current_page', 1),
      lastPage: metaInt('last_page', 1),
      total: metaInt('total', items.length),
    );
  }
}
