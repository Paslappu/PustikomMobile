import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qrscan/models/device_model.dart';
import 'package:qrscan/models/ref_item.dart';
import 'package:qrscan/pages/device_detail_page.dart';
import 'package:qrscan/services/api_exception.dart';
import 'package:qrscan/services/app_scope.dart';
import 'package:qrscan/services/app_services.dart';
import 'package:qrscan/widgets/app_button.dart';
import 'package:qrscan/widgets/app_snackbar.dart';
import 'package:qrscan/widgets/device_list_tile.dart';
import 'package:qrscan/widgets/empty_state.dart';
import 'package:qrscan/widgets/filter_chips_bar.dart';
import 'package:qrscan/widgets/loading_overlay.dart';
import 'package:qrscan/widgets/manual_code_sheet.dart';
import 'package:qrscan/widgets/paged_list_footer.dart';

/// Searchable, filterable list of all devices.
///
/// With [selectMode] a tap returns the chosen [DeviceModel] to the caller
/// instead of opening the detail screen.
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, this.selectMode = false});

  final bool selectMode;

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DeviceFilters {
  const _DeviceFilters({this.tipeId, this.categoryDanaId, this.isActive});

  final int? tipeId;
  final int? categoryDanaId;
  final bool? isActive;

  bool get isEmpty =>
      tipeId == null && categoryDanaId == null && isActive == null;
}

class _DevicesPageState extends State<DevicesPage> {
  static const Duration _debounceDelay = Duration(milliseconds: 400);
  static const int _searchMax = 100;

  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  AppServices? _services;
  Timer? _debounce;

  final List<DeviceModel> _items = [];
  _DeviceFilters _filters = const _DeviceFilters();
  String _search = '';
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _moreError;
  int _requestId = 0;
  bool _looking = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_services == null) {
      _services = AppScope.of(context);
      // Filter options come from the cached reference lists.
      unawaited(_services!.references.load().catchError((_) {}));
      unawaited(_fetch(reset: true));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _searchCtrl.dispose();
    super.dispose();
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
  /// responses stale; they are dropped. [keepItems] keeps the list visible
  /// during a pull-to-refresh.
  Future<void> _fetch({required bool reset, bool keepItems = false}) async {
    final services = _services;
    if (services == null) return;
    final id = ++_requestId;
    final page = reset ? 1 : _page + 1;

    if (reset) {
      setState(() {
        _loadingMore = false;
        _moreError = null;
        if (!keepItems) {
          _loading = true;
          _error = null;
          _items.clear();
          _hasMore = false;
        }
      });
    } else {
      setState(() {
        _loadingMore = true;
        _moreError = null;
      });
    }

    try {
      final result = await services.devices.list(
        search: _search,
        tipeId: _filters.tipeId,
        categoryDanaId: _filters.categoryDanaId,
        isActive: _filters.isActive,
        page: page,
      );
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
        // A short first page may not fill the screen, so scrolling can never
        // trigger the next one.
        if (mounted &&
            _scroll.hasClients &&
            _scroll.position.maxScrollExtent <= 0) {
          _loadMore();
        }
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      _handleFetchError(e.message, reset: reset, keepItems: keepItems);
    } catch (_) {
      if (!mounted || id != _requestId) return;
      _handleFetchError(
        'Terjadi kesalahan. Coba lagi.',
        reset: reset,
        keepItems: keepItems,
      );
    }
  }

  void _handleFetchError(
    String message, {
    required bool reset,
    required bool keepItems,
  }) {
    if (reset && keepItems && _items.isNotEmpty) {
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

  void _onSearchChanged(String value) {
    setState(() {}); // toggles the clear button
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      final term = value.trim();
      if (term == _search) return;
      _search = term;
      unawaited(_fetch(reset: true));
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _debounce?.cancel();
    setState(() {});
    if (_search.isNotEmpty) {
      _search = '';
      unawaited(_fetch(reset: true));
    }
  }

  void _applyFilters(_DeviceFilters filters) {
    setState(() => _filters = filters);
    unawaited(_fetch(reset: true));
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_DeviceFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DeviceFilterSheet(
        initial: _filters,
        tipe: _services!.references.tipe,
        categoryDana: _services!.references.categoryDana,
      ),
    );
    if (result == null || !mounted) return;
    _applyFilters(result);
  }

  List<FilterChipItem> _activeChips() {
    final refs = _services!.references;
    String nameOf(List<RefItem> list, int id) {
      for (final r in list) {
        if (r.id == id) return r.name;
      }
      return '#$id';
    }

    return [
      if (_filters.tipeId != null)
        FilterChipItem(
          label: 'Tipe: ${nameOf(refs.tipe, _filters.tipeId!)}',
          onDeleted: () => _applyFilters(
            _DeviceFilters(
              categoryDanaId: _filters.categoryDanaId,
              isActive: _filters.isActive,
            ),
          ),
        ),
      if (_filters.categoryDanaId != null)
        FilterChipItem(
          label: 'Dana: ${nameOf(refs.categoryDana, _filters.categoryDanaId!)}',
          onDeleted: () => _applyFilters(
            _DeviceFilters(
              tipeId: _filters.tipeId,
              isActive: _filters.isActive,
            ),
          ),
        ),
      if (_filters.isActive != null)
        FilterChipItem(
          label: _filters.isActive! ? 'Status: Aktif' : 'Status: Nonaktif',
          onDeleted: () => _applyFilters(
            _DeviceFilters(
              tipeId: _filters.tipeId,
              categoryDanaId: _filters.categoryDanaId,
            ),
          ),
        ),
    ];
  }

  void _onTapDevice(DeviceModel device) {
    if (widget.selectMode) {
      Navigator.of(context).pop(device);
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => DeviceDetailPage(device: device)),
    );
  }

  Future<void> _manualLookup() async {
    final raw = await showManualCodeSheet(context);
    if (raw == null || !mounted) return;
    final devices = _services!.devices;
    setState(() => _looking = true);
    try {
      final device = await devices.lookup(raw);
      if (!mounted) return;
      setState(() => _looking = false);
      if (widget.selectMode) {
        Navigator.of(context).pop(device);
      } else {
        await DeviceDetailPage.openFromScan(context, device);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _looking = false);
      if (e.failure == ApiFailure.unauthorized) return;
      showAppSnackBar(
        context,
        e.failure == ApiFailure.notFound
            ? 'Perangkat tidak ditemukan untuk kode tersebut.'
            : e.message,
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectMode ? 'Pilih Perangkat' : 'Daftar Perangkat'),
        actions: [
          IconButton(
            tooltip: 'Ketik kode',
            icon: const Icon(Icons.keyboard_outlined),
            onPressed: _looking ? null : _manualLookup,
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _looking,
        message: 'Mencari perangkat...',
        child: Column(
          children: [
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
                        hintText: 'Cari kode perangkat...',
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
            ListenableBuilder(
              listenable: _services!.references,
              builder: (context, _) => FilterChipsBar(items: _activeChips()),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Gagal memuat perangkat',
        message: _error,
        actionLabel: 'Coba Lagi',
        onAction: () => _fetch(reset: true),
      );
    }
    if (_items.isEmpty) {
      final filtered = _search.isNotEmpty || !_filters.isEmpty;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: EmptyState(
                icon: Icons.devices_other_outlined,
                title: filtered
                    ? 'Tidak ada perangkat yang cocok'
                    : 'Belum ada perangkat',
                message: filtered
                    ? 'Ubah kata kunci atau filter pencarian.'
                    : null,
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
          final device = _items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DeviceListTile(
              device: device,
              onTap: () => _onTapDevice(device),
            ),
          );
        },
      ),
    );
  }
}

class _DeviceFilterSheet extends StatefulWidget {
  const _DeviceFilterSheet({
    required this.initial,
    required this.tipe,
    required this.categoryDana,
  });

  final _DeviceFilters initial;
  final List<RefItem> tipe;
  final List<RefItem> categoryDana;

  @override
  State<_DeviceFilterSheet> createState() => _DeviceFilterSheetState();
}

class _DeviceFilterSheetState extends State<_DeviceFilterSheet> {
  late int? _tipeId = widget.initial.tipeId;
  late int? _categoryDanaId = widget.initial.categoryDanaId;
  late bool? _isActive = widget.initial.isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter Perangkat', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Text('Status', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Semua'),
                selected: _isActive == null,
                onSelected: (_) => setState(() => _isActive = null),
              ),
              ChoiceChip(
                label: const Text('Aktif'),
                selected: _isActive == true,
                onSelected: (_) => setState(() => _isActive = true),
              ),
              ChoiceChip(
                label: const Text('Nonaktif'),
                selected: _isActive == false,
                onSelected: (_) => setState(() => _isActive = false),
              ),
            ],
          ),
          if (widget.tipe.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Tipe', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _RefChoices(
              items: widget.tipe,
              selectedId: _tipeId,
              onChanged: (id) => setState(() => _tipeId = id),
            ),
          ],
          if (widget.categoryDana.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Kategori Dana', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _RefChoices(
              items: widget.categoryDana,
              selectedId: _categoryDanaId,
              onChanged: (id) => setState(() => _categoryDanaId = id),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Reset',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => setState(() {
                    _tipeId = null;
                    _categoryDanaId = null;
                    _isActive = null;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Terapkan',
                  onPressed: () => Navigator.of(context).pop(
                    _DeviceFilters(
                      tipeId: _tipeId,
                      categoryDanaId: _categoryDanaId,
                      isActive: _isActive,
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

class _RefChoices extends StatelessWidget {
  const _RefChoices({
    required this.items,
    required this.selectedId,
    required this.onChanged,
  });

  final List<RefItem> items;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Semua'),
          selected: selectedId == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final item in items)
          ChoiceChip(
            label: Text(item.name),
            selected: selectedId == item.id,
            onSelected: (_) => onChanged(item.id),
          ),
      ],
    );
  }
}
