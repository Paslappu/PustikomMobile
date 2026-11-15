import 'package:flutter/material.dart';
import 'package:qrscan/config/app_config.dart';
import 'package:qrscan/pages/antrean_page.dart';
import 'package:qrscan/pages/legacy_notes_page.dart';
import 'package:qrscan/services/api_exception.dart';
import 'package:qrscan/services/app_scope.dart';
import 'package:qrscan/services/auth_scope.dart';
import 'package:qrscan/services/database_service.dart';
import 'package:qrscan/theme/app_tokens.dart';
import 'package:qrscan/widgets/app_button.dart';
import 'package:qrscan/widgets/app_card.dart';
import 'package:qrscan/widgets/app_snackbar.dart';
import 'package:qrscan/widgets/confirm_dialog.dart';
import 'package:qrscan/widgets/info_tile.dart';
import 'package:qrscan/widgets/loading_overlay.dart';
import 'package:qrscan/widgets/section_header.dart';
import 'package:qrscan/widgets/status_chip.dart';
import 'package:qrscan/widgets/user_avatar.dart';

/// "Profil" tab: account details, app info, queue and legacy notes shortcuts
/// and logout.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _busy = false;
  int _legacyCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLegacyCount();
  }

  /// The legacy notes tile only appears while the old table still has rows.
  Future<void> _loadLegacyCount() async {
    int count;
    try {
      count = (await DatabaseService.instance.getPerangkat()).length;
    } catch (_) {
      count = 0;
    }
    if (!mounted) return;
    setState(() => _legacyCount = count);
  }

  Future<void> _refresh() async {
    final auth = AuthScope.read(context);
    try {
      await auth.refreshProfile();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.failure != ApiFailure.unauthorized) {
        showAppSnackBar(context, e.message, isError: true);
      }
    }
    await _loadLegacyCount();
  }

  Future<void> _openLegacyNotes() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const LegacyNotesPage()));
    if (!mounted) return;
    await _loadLegacyCount();
  }

  void _openQueue() {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const AntreanPage()));
  }

  Future<void> _logout() async {
    final auth = AuthScope.read(context);
    final waiting = AppScope.of(context).outbox.badgeCount;
    var message =
        'Anda perlu masuk kembali untuk menggunakan aplikasi. Laporan yang '
        'belum terkirim tetap tersimpan dan hanya dikirim setelah Anda masuk '
        'dengan akun yang sama.';
    if (waiting > 0) {
      message += ' Saat ini ada $waiting laporan yang menunggu dikirim.';
    }
    final ok = await showConfirmDialog(
      context,
      title: 'Keluar dari akun?',
      message: message,
      confirmLabel: 'Keluar',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    // The gate replaces this page once the session is cleared; nothing to
    // update afterwards.
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthScope.of(context).user;
    final outbox = AppScope.of(context).outbox;
    final name = user?.name ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: LoadingOverlay(
        isLoading: _busy,
        message: 'Keluar...',
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  children: [
                    UserAvatar(
                      name: name.isEmpty ? 'Pengguna' : name,
                      radius: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name.isEmpty ? 'Pengguna' : name,
                      style: context.text.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? '',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    StatusChip(
                      label: user?.roleLabel ?? 'Pengguna',
                      tone: StatusTone.info,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Akun'),
              AppCard(
                child: Column(
                  children: [
                    InfoTile(label: 'Nama', value: name),
                    InfoTile(label: 'Email', value: user?.email ?? ''),
                    InfoTile(label: 'Peran', value: user?.roleLabel ?? ''),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Aplikasi'),
              AppCard(
                child: Column(
                  children: [
                    const InfoTile(
                      label: 'Versi Aplikasi',
                      value: AppConfig.appVersion,
                    ),
                    InfoTile(
                      label: 'Server',
                      value: Uri.parse(AppConfig.apiBaseUrl).host,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: outbox,
                builder: (context, _) => _NavTile(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Antrean pengiriman',
                  subtitle: '${outbox.badgeCount} laporan',
                  onTap: _openQueue,
                ),
              ),
              if (_legacyCount > 0) ...[
                const SizedBox(height: 12),
                _NavTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Catatan lama (lokal)',
                  subtitle: '$_legacyCount catatan di perangkat ini',
                  onTap: _openLegacyNotes,
                ),
              ],
              const SizedBox(height: 24),
              AppButton(
                variant: AppButtonVariant.danger,
                icon: Icons.logout,
                label: 'Keluar',
                onPressed: _busy ? null : _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                Text(subtitle, style: context.text.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
