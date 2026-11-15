import 'package:flutter/material.dart';
import 'package:qrscan/pages/antrean_page.dart';
import 'package:qrscan/services/app_scope.dart';
import 'package:qrscan/widgets/report_list_view.dart';

/// Body of the "Laporan" tab: server reports ("Riwayat") and the offline
/// queue ("Antrean").
class LaporanPage extends StatelessWidget {
  const LaporanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final outbox = AppScope.of(context).outbox;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Laporan'),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Riwayat'),
              Tab(
                child: ListenableBuilder(
                  listenable: outbox,
                  builder: (context, _) {
                    final count = outbox.badgeCount;
                    return Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      offset: const Offset(12, -6),
                      child: const Text('Antrean'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        body: const TabBarView(children: [ReportListView(), OutboxListView()]),
      ),
    );
  }
}
