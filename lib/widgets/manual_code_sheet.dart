import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qrscan/widgets/app_button.dart';

/// Asks for a device code typed by hand. Returns the trimmed text, or null
/// when dismissed.
Future<String?> showManualCodeSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ManualCodeSheet(),
  );
}

class _ManualCodeSheet extends StatefulWidget {
  const _ManualCodeSheet();

  @override
  State<_ManualCodeSheet> createState() => _ManualCodeSheetState();
}

class _ManualCodeSheetState extends State<_ManualCodeSheet> {
  static const int _maxLength = 500;

  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ketik Kode Perangkat', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Masukkan kode perangkat atau tautan pada stiker.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: _maxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              hintText: 'Kode perangkat',
              prefixIcon: Icon(Icons.keyboard_outlined),
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => AppButton(
              label: 'Cari Perangkat',
              icon: Icons.search,
              onPressed: value.text.trim().isEmpty ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}
