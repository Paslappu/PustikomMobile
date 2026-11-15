const List<String> _monthsId = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// `yyyy-MM-ddTHH:mm:ss+HH:MM` using the local UTC offset of [local].
String formatIsoWithOffset(DateTime local) {
  final d = local.isUtc ? local : local.toLocal();
  final offset = d.timeZoneOffset;
  final negative = offset.isNegative;
  final totalMinutes = offset.inMinutes.abs();
  final sign = negative ? '-' : '+';
  final oh = _two(totalMinutes ~/ 60);
  final om = _two(totalMinutes % 60);
  return '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}'
      'T${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}$sign$oh:$om';
}

/// `yyyy-MM-dd`.
String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// "15 Nov 2026, 09:30". Callers pass a local time (`.toLocal()`).
String formatDateTime(DateTime d) =>
    '${d.day} ${_monthsId[d.month - 1]} ${d.year}, ${_two(d.hour)}:${_two(d.minute)}';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
}
