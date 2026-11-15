import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qrscan/models/device_model.dart';
import 'package:qrscan/models/report_model.dart';
import 'package:qrscan/pages/devices_page.dart';
import 'package:qrscan/pages/report_detail_page.dart';
import 'package:qrscan/services/api_exception.dart';
import 'package:qrscan/services/app_scope.dart';
import 'package:qrscan/services/app_services.dart';
import 'package:qrscan/services/auth_scope.dart';
import 'package:qrscan/utils/formatters.dart';
import 'package:qrscan/widgets/app_button.dart';
import 'package:qrscan/widgets/app_snackbar.dart';
import 'package:qrscan/widgets/empty_state.dart';
import 'package:qrscan/widgets/filter_chips_bar.dart';
import 'package:qrscan/widgets/gedung_picker_sheet.dart';
import 'package:qrscan/widgets/paged_list_footer.dart';
import 'package:qrscan/widgets/report_tile.dart';

/// Server-backed, paginated list of reports with search and filters.
///
/// [filter] is the starting filter. A device set in it is fixed: the user can
/// neither change nor remove it (used by the device history screen).
class ReportListView extends StatefulWidget {
  const ReportListView({
    super.key,
    this.filter = const ReportFilter(),
    this.showFilterBar = true,
  });

  final ReportFilter filter;

  /// Show the search field and the filter button.
  final bool showFilterBar;

  @override
  State<ReportListView> createState() => _ReportListViewState();
}

/// What the filter sheet hands back: the filter plus the display names of the
/// chosen device and building (the filter itself only keeps ids).
class _FilterResult {
  const _FilterResult({
    required this.filter,
    this.deviceLabel,
    this.gedungLabel,
  });

  final ReportFilter filter;
  final String? deviceLabel;
  final String? gedungLabel;
}

class _ReportListViewState extends State<ReportListView>
    with AutomaticKeepAliveClientMixin {
  static const Duration _debounceDelay = Duration(milliseconds: 400);
  static const int _searchMax = 100;

  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  AppServices? _services;
  Timer? _debounce;

  final List<DeviceReport> _items = [];
  late ReportFilter _filter = widget.filter;
  String? _deviceLabel;
  String? _gedungLabel;
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _moreError;
  int _requestId = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppScope.of(context);
    if (!identical(services, _services)) {
      _services?.reports.revision.removeListener(_onRevision);
      _services = services;
      services.reports.revision.addListener(_onRevision);
      unawaited(_fetch(reset: true));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _services?.reports.revision.removeListener(_onRevision);
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onRevision() {
    if (mounted) unawaited(_fetch(reset: true, keepItems: true));
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) _loadMore();
  }

  void _loadMore() {
    if (_loading || _loadingMore || !_hasMore || _moreError != null) return;
    unawaited(_fetch(reset: false));
  }

  /// Loads page 1 ([reset]) or the next page. A newer request makes older
  /// responses stale; they are dropped.
  Future<void> _fetch({required bool reset, bool keepItems = false}) async {
    final services = _services;
    if (services == null) return;
    final id = ++_requestId;
    final page = reset ? 1 : _page + 1;

    setState(() {
      if (reset) {
        _loadingMore = false;
        _moreError = null;
        if (!keepItems) {
          _loading = true;
          _error = null;
          _items.clear();
          _hasMore = false;
        }
      } else {
        _loadingMore = true;
        _moreError = null;
      }
    });

    try {
      final result = await services.reports.list(_filter, page: page);
      if (!mounted || id != _requestId) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result.items);
        _page = result.currentPage;
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // A short first page may not fill the screen, so scrolling could never
        // trigger the next one.
        if (mounted &&
            _scroll.hasClients &&
            _scroll.position.maxScrollExtent <= 0) {
          _loadMore();
        }
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      _handleError(e.message, reset: reset, keepItems: keepItems);
    } catch (_) {
      if (!mounted || id != _requestId) return;
      _handleError(
        'Terjadi kesalahan. Coba lagi.',
        reset: reset,
        keepItems: keepItems,
      );
    }
  }

  void _handleError(
    String message, {
    required bool reset,
    required bool keepItems,
  }) {
    if (reset && keepItems && _items.isNotEmpty) {
      setState(() => _loading = false);
      showAppSnackBar(context, message, isError: true);
      return;
    }
    setState(() {
      _loading = false;
      _loadingMore = false;
      if (reset) {
        _error = message;
      } else {
        _moreError = message;
      }
    });
  }

  Future<void> _refresh() => _fetch(reset: true, keepItems: true);

  // ---- Filters ----

  void _applyFilter(ReportFilter filter) {
    setState(() => _filter = filter);
    unawaited(_fetch(reset: true));
  }

  void _onSearchChanged(String value) {
    setState(() {}); // toggles the clear button
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      final term = value.trim();
      if (term == (_filter.q ?? '')) return;
      _applyFilter(
        term.isEmpty
            ? _filter.copyWith(clearQ: true)
            : _filter.copyWith(q: term),
      );
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _debounce?.cancel();
    setState(() {});
    if ((_filter.q ?? '').isNotEmpty) {
      _applyFilter(_filter.copyWith(clearQ: true));
    }
  }

  bool get _deviceFixed => widget.filter.deviceId != null;

  Future<void> _openFilters() async {
    final user = AuthScope.of(context).user;
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReportFilterSheet(
        initial: _filter,
        deviceLabel: _deviceLabel,
        gedungLabel: _gedungLabel,
        deviceFixed: _deviceFixed,
        meId: (user?.isAdmin ?? false) ? user?.id : null,
      ),
    );
    if (result == null || !mounted) return;
    _deviceLabel = result.deviceLabel;
    _gedungLabel = result.gedungLabel;
    _applyFilter(result.filter);
  }

  List<FilterChipItem> _activeChips() {
    final f = _filter;
    final meId = AuthScope.of(context).user?.id;
    return [
      if (f.from != null || f.to != null)
        FilterChipItem(
          label: _rangeLabel(f.from, f.to),
          onDeleted: () =>
              _applyFilter(f.copyWith(clearFrom: true, clearTo: true)),
        ),
      if (f.deviceId != null && !_deviceFixed)
        FilterChipItem(
          label: 'Perangkat: ${_deviceLabel ?? '#${f.deviceId}'}',
          onDeleted: () {
            _deviceLabel = null;
            _applyFilter(f.copyWith(clearDeviceId: true));
          },
        ),
      if (f.gedungId != null)
        FilterChipItem(
          label: 'Gedung: ${_gedungLabel ?? '#${f.gedungId}'}',
          onDeleted: () {
            _gedungLabel = null;
            _applyFilter(f.copyWith(clearGedungId: true));
          },
        ),
      if (f.userId != null)
        FilterChipItem(
          label: f.userId == meId
              ? 'Hanya laporan saya'
              : 'Pengguna #${f.userId}',
          onDeleted: () => _applyFilter(f.copyWith(clearUserId: true)),
        ),
    ];
  }

  static String _rangeLabel(DateTime? from, DateTime? to) {
    String d(DateTime v) => formatDateTime(v).split(',').first;
    if (from != null && to != null) return '${d(from)} - ${d(to)}';
    if (from != null) return 'Mulai ${d(from)}';
    return 'Sampai ${d(to!)}';
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        if (widget.showFilterBar) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_searchMax),
                    ],
                    decoration: InputDecoration(
                      hintText: 'Cari catatan atau kode perangkat...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Bersihkan',
                              icon: const Icon(Icons.close),
                              onPressed: _clearSearch,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Filter',
                  icon: const Icon(Icons.tune),
                  onPressed: _openFilters,
                ),
              ],
            ),
          ),
          FilterChipsBar(items: _activeChips()),
        ],
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Gagal memuat laporan',
        message: _error,
        actionLabel: 'Coba Lagi',
        onAction: () => _fetch(reset: true),
      );
    }

    final isAdmin = AuthScope.of(context).user?.isAdmin ?? false;
    if (_items.isEmpty) {
      final filtered =
          _filter.q != null && _filter.q!.isNotEmpty ||
          _filter.from != null ||
          _filter.to != null ||
          _filter.gedungId != null ||
          _filter.userId != null ||
          (_filter.deviceId != null && !_deviceFixed);
      return RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: EmptyState(
                icon: Icons.assignment_outlined,
                title: filtered
                    ? 'Tidak ada laporan yang cocok'
                    : 'Belum ada laporan',
                message: filtered
                    ? 'Ubah kata kunci atau filter pencarian.'
                    : 'Laporan yang dibuat akan muncul di sini.',
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return PagedListFooter(
              isLoading: _loadingMore,
              hasMore: _hasMore,
              errorMessage: _moreError,
              onRetry: () => _fetch(reset: false),
            );
          }
          final report = _items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ReportTile(
              report: report,
              showUser: isAdmin,
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => ReportDetailPage(id: report.id),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReportFilterSheet extends StatefulWidget {
  const _ReportFilterSheet({
    required this.initial,
    required this.deviceLabel,
    required this.gedungLabel,
    required this.deviceFixed,
    required this.meId,
  });

  final ReportFilter initial;
  final String? deviceLabel;
  final String? gedungLabel;
  final bool deviceFixed;

  /// Id of the current user when they are an admin (shows the "only mine"
  /// switch); null otherwise.
  final int? meId;

  @override
  State<_ReportFilterSheet> createState() => _ReportFilterSheetState();
}

class _ReportFilterSheetState extends State<_ReportFilterSheet> {
  late ReportFilter _filter = widget.initial;
  late String? _deviceLabel = widget.deviceLabel;
  late String? _gedungLabel = widget.gedungLabel;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final current = (_filter.from != null && _filter.to != null)
        ? DateTimeRange(start: _filter.from!, end: _filter.to!)
        : null;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: current,
    );
    if (range == null || !mounted) return;
    setState(() {
      _filter = _filter.copyWith(from: range.start, to: range.end);
    });
  }

  Future<void> _pickDevice() async {
    final device = await Navigator.of(context).push<DeviceModel>(
      MaterialPageRoute(builder: (_) => const DevicesPage(selectMode: true)),
    );
    if (device == null || !mounted) return;
    setState(() {
      _filter = _filter.copyWith(deviceId: device.id);
      _deviceLabel = device.code;
    });
  }

  Future<void> _pickGedung() async {
    final pick = await showGedungPicker(context, selectedId: _filter.gedungId);
    if (pick == null || !mounted) return;
    setState(() {
      final g = pick.gedung;
      _filter = g == null
          ? _filter.copyWith(clearGedungId: true)
          : _filter.copyWith(gedungId: g.id);
      _gedungLabel = g?.label;
    });
  }

  void _reset() {
    setState(() {
      _filter = _filter.copyWith(
        clearFrom: true,
        clearTo: true,
        clearGedungId: true,
        clearUserId: true,
        clearDeviceId: !widget.deviceFixed,
      );
      _deviceLabel = null;
      _gedungLabel = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final f = _filter;
    final meId = widget.meId;
    final rangeText = (f.from != null && f.to != null)
        ? '${formatDate(f.from!)} s/d ${formatDate(f.to!)}'
        : 'Semua tanggal';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter Laporan', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.date_range_outlined),
            title: const Text('Rentang tanggal'),
            subtitle: Text(rangeText),
            trailing: (f.from != null || f.to != null)
                ? IconButton(
                    tooltip: 'Hapus tanggal',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(
                      () =>
                          _filter = f.copyWith(clearFrom: true, clearTo: true),
                    ),
                  )
                : null,
            onTap: _pickRange,
          ),
          if (!widget.deviceFixed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.devices_other_outlined),
              title: const Text('Perangkat'),
              subtitle: Text(
                f.deviceId == null
                    ? 'Semua perangkat'
                    : (_deviceLabel ?? '#${f.deviceId}'),
              ),
              trailing: f.deviceId != null
                  ? IconButton(
                      tooltip: 'Hapus perangkat',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _filter = f.copyWith(clearDeviceId: true);
                        _deviceLabel = null;
                      }),
                    )
                  : null,
              onTap: _pickDevice,
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.apartment_outlined),
            title: const Text('Gedung'),
            subtitle: Text(
              f.gedungId == null
                  ? 'Semua gedung'
                  : (_gedungLabel ?? '#${f.gedungId}'),
            ),
            trailing: f.gedungId != null
                ? IconButton(
                    tooltip: 'Hapus gedung',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _filter = f.copyWith(clearGedungId: true);
                      _gedungLabel = null;
                    }),
                  )
                : null,
            onTap: _pickGedung,
          ),
          if (meId != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.person_outline),
              title: const Text('Hanya laporan saya'),
              value: f.userId == meId,
              onChanged: (on) => setState(
                () => _filter = on
                    ? f.copyWith(userId: meId)
                    : f.copyWith(clearUserId: true),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Reset',
                  variant: AppButtonVariant.secondary,
                  onPressed: _reset,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Terapkan',
                  onPressed: () => Navigator.of(context).pop(
                    _FilterResult(
                      filter: _filter,
                      deviceLabel: _deviceLabel,
                      gedungLabel: _gedungLabel,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
