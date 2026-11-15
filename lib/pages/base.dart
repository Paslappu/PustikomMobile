import 'package:flutter/material.dart';
import 'package:qrscan/pages/home.dart';
import 'package:qrscan/pages/laporan_page.dart';
import 'package:qrscan/pages/profile.dart';
import 'package:qrscan/pages/qr_scan.dart';
import 'package:qrscan/services/app_scope.dart';

/// Signed-in shell: bottom navigation with Beranda, Pindai, Laporan and
/// Profil. The selected tab lives in `AppServices.shellTab` so other screens
/// can switch tabs.
class BaseHome extends StatelessWidget {
  const BaseHome({super.key});

  static const int homeTab = 0;
  static const int scanTab = 1;
  static const int reportsTab = 2;
  static const int profileTab = 3;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: services.shellTab,
      builder: (context, index, _) {
        return PopScope(
          canPop: index == homeTab,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) services.shellTab.value = homeTab;
          },
          child: Scaffold(
            body: IndexedStack(
              index: index,
              children: [
                const HomePage(),
                // Built only while selected so the camera is released.
                index == scanTab ? const QrScan() : const SizedBox.shrink(),
                const LaporanPage(),
                const ProfilePage(),
              ],
            ),
            bottomNavigationBar: ListenableBuilder(
              listenable: services.outbox,
              builder: (context, _) {
                final count = services.outbox.badgeCount;
                Widget reportsIcon(IconData icon) => Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: Icon(icon),
                );
                return NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (i) => services.shellTab.value = i,
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Beranda',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.qr_code_scanner),
                      label: 'Pindai',
                    ),
                    NavigationDestination(
                      icon: reportsIcon(Icons.assignment_outlined),
                      selectedIcon: reportsIcon(Icons.assignment),
                      label: 'Laporan',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Profil',
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
