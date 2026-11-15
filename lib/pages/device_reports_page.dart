import 'package:flutter/material.dart';
import 'package:qrscan/models/report_model.dart';
import 'package:qrscan/widgets/report_list_view.dart';

/// Reports of one device, newest first.
class DeviceReportsPage extends StatelessWidget {
  const DeviceReportsPage({super.key, required this.deviceId, this.deviceCode});

  final int deviceId;

  /// Shown in the app bar when known.
  final String? deviceCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          deviceCode == null ? 'Riwayat Laporan' : 'Laporan $deviceCode',
        ),
      ),
      body: ReportListView(filter: ReportFilter(deviceId: deviceId)),
    );
  }
}
