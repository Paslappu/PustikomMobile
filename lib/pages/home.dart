import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qrscan/config/app_config.dart';
import 'package:qrscan/models/outbox_item.dart';
import 'package:qrscan/models/report_model.dart';
import 'package:qrscan/pages/antrean_page.dart';
import 'package:qrscan/pages/base.dart';
import 'package:qrscan/pages/devices_page.dart';
import 'package:qrscan/pages/report_detail_page.dart';
import 'package:qrscan/pages/report_form_page.dart';
import 'package:qrscan/services/api_exception.dart';
import 'package:qrscan/services/app_scope.dart';
import 'package:qrscan/services/app_services.dart';
import 'package:qrscan/services/auth_scope.dart';
import 'package:qrscan/theme/app_tokens.dart';
import 'package:qrscan/widgets/app_button.dart';
import 'package:qrscan/widgets/app_card.dart';
import 'package:qrscan/widgets/empty_state.dart';
import 'package:qrscan/widgets/report_tile.dart';
import 'package:qrscan/widgets/section_header.dart';
import 'package:qrscan/widgets/user_avatar.dart';

/// "Beranda" tab: greeting, scan shortcut, queue and draft notices, report
/// count and the latest reports.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const int _recentCount = 5;

  AppServices? _services;
  List<DeviceReport> _recent = const [];
  int? _total;
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppScope.of(context);
    if (!identical(services, _services)) {
      _services?.reports.revision.removeListener(_onRevision);
      _services = services;
      services.reports.revision.addListener(_onRevision);
      unawaited(_fetch());
    }
  }

  @override
  void dispose() {
    _services?.reports.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() => unawaited(_fetch());

  Future<void> _fetch() async {
    final services = _services;
    if (services == null) return;
    final id = ++_requestId;
    try {
      final page = await services.reports.list(
        const ReportFilter(),
        perPage: _recentCount,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _recent = page.items;
        _total = page.total;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = 'Terjadi kesalahan. Coba lagi.';
        _loading = false;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    unawaited(_fetch());
  }

  void _push(Widget page) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final services = _services!;
    final user = AuthScope.of(context).user;
    final isAdmin = user?.isAdmin ?? false;
    final fullName = user?.name.trim() ?? '';
    final firstName = fullName.isEmpty
        ? 'Pengguna'
        : fullName.split(RegExp(r'\s+')).first;

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _HeaderBand(
            fullName: fullName.isEmpty ? 'Pengguna' : fullName,
            greeting: 'Halo, $firstName',
            onScan: () => services.shellTab.value = BaseHome.scanTab,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListenableBuilder(
                  listenable: services.outbox,
                  builder: (context, _) => _OutboxNotices(
                    services: services,
                    onOpenQueue: () => _push(const AntreanPage()),
                    onOpenDraft: (uuid) => _push(ReportFormPage(uuid: uuid)),
                  ),
                ),
                _StatCard(
                  label: isAdmin ? 'Total laporan' : 'Laporan saya',
                  value: _total == null ? '-' : '$_total',
                ),
                const SizedBox(height: 16),
                SectionHeader(
                  title: 'Laporan Terakhir',
                  actionLabel: 'Lihat semua',
                  onAction: () => services.shellTab.value = BaseHome.reportsTab,
                ),
                const SizedBox(height: 8),
                _buildRecent(isAdmin),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Daftar Perangkat',
                  icon: Icons.devices_other_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _push(const DevicesPage()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecent(bool isAdmin) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Gagal memuat laporan',
        message: _error,
        actionLabel: 'Coba Lagi',
        onAction: _retry,
      );
    }
    if (_recent.isEmpty) {
      return const EmptyState(
        icon: Icons.assignment_outlined,
        title: 'Belum ada laporan',
        message: 'Pindai QR perangkat untuk membuat laporan pertama.',
      );
    }
    return Column(
      children: [
        for (final report in _recent)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ReportTile(
              report: report,
              showUser: isAdmin,
              onTap: () => _push(ReportDetailPage(id: report.id)),
            ),
          ),
      ],
    );
  }
}

class _HeaderBand extends StatelessWidget {
  const _HeaderBand({
    required this.fullName,
    required this.greeting,
    required this.onScan,
  });

  final String fullName;
  final String greeting;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final text = context.text;
    return Container(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(context.tokens.radiusXl),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  UserAvatar(name: fullName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: text.titleMedium?.copyWith(
                            color: scheme.onPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          AppConfig.appFullName,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.qr_code_scanner, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pindai QR Perangkat',
                            style: text.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Arahkan kamera ke kode QR pada perangkat.',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Mulai Pindai',
                      icon: Icons.qr_code_scanner,
                      onPressed: onScan,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(context.tokens.radiusMd),
            ),
            child: Icon(
              Icons.assignment_outlined,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: context.text.bodyMedium)),
          Text(value, style: context.text.headlineSmall),
        ],
      ),
    );
  }
}

/// Banners for reports waiting to be sent and for unfinished drafts.
class _OutboxNotices extends StatelessWidget {
  const _OutboxNotices({
    required this.services,
    required this.onOpenQueue,
    required this.onOpenDraft,
  });

  final AppServices services;
  final VoidCallback onOpenQueue;
  final ValueChanged<String> onOpenDraft;

  @override
  Widget build(BuildContext context) {
    final controller = services.outbox;
    final count = controller.badgeCount;
    final blocked = controller.blockedByAuth;
    final drafts = controller.drafts
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final tokens = context.tokens;

    final banners = <Widget>[];
    if (count > 0 || blocked) {
      banners.add(
        _NoticeCard(
          background: tokens.infoContainer,
          foreground: tokens.info,
          icon: Icons.cloud_upload_outlined,
          title: blocked && count == 0
              ? 'Pengiriman laporan dijeda'
              : '$count laporan menunggu dikirim',
          actionLabel: 'Lihat Antrean',
          onAction: onOpenQueue,
        ),
      );
    }
    if (drafts.isNotEmpty) {
      final OutboxItem newest = drafts.first;
      banners.add(
        _NoticeCard(
          background: tokens.warningContainer,
          foreground: tokens.warning,
          icon: Icons.edit_note,
          title: 'Draf laporan belum selesai',
          subtitle: drafts.length > 1
              ? '${newest.deviceLabel} dan ${drafts.length - 1} draf lainnya'
              : newest.deviceLabel,
          actionLabel: 'Lanjutkan',
          onAction: () => onOpenDraft(newest.uuid),
        ),
      );
    }
    if (banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final banner in banners)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: banner),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.subtitle,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return AppCard(
      color: background,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleSmall?.copyWith(color: foreground),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: text.bodySmall?.copyWith(color: foreground),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: foreground),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
