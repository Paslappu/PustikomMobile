import 'package:flutter/material.dart';
import 'package:qrscan/models/device_model.dart';
import 'package:qrscan/theme/app_tokens.dart';
import 'package:qrscan/widgets/app_card.dart';
import 'package:qrscan/widgets/status_chip.dart';

/// One row of the device list: code, "tipe · kategori dana", status and the
/// current building.
class DeviceListTile extends StatelessWidget {
  const DeviceListTile({super.key, required this.device, required this.onTap});

  final DeviceModel device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final text = context.text;
    final subtitle = device.subtitle;
    final gedung = device.currentLocation?.gedung?.label;

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(context.tokens.radiusMd),
            ),
            child: Icon(
              Icons.devices_other_outlined,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.code,
                  style: text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (gedung != null && gedung.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          gedung,
                          style: text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(
            label: device.isActive ? 'Aktif' : 'Nonaktif',
            tone: device.isActive ? StatusTone.success : StatusTone.neutral,
          ),
        ],
      ),
    );
  }
}
