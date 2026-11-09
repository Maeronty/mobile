// =============================================================================
// WIDGET: DIALOG CHỌN CHẾ ĐỘ ĂN (Hồ sơ)
// =============================================================================
//
// FLOW
//   Chọn một mục → `onSelected(option)` → ProfileController lưu → đóng dialog.
// =============================================================================

import 'package:flutter/material.dart';

class DietPreferenceDialog extends StatelessWidget {
  final List<String> options;
  final ValueChanged<String> onSelected;

  const DietPreferenceDialog({
    super.key,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Chọn chế độ ăn uống'),
      children: options.map((opt) {
        return SimpleDialogOption(
          onPressed: () {
            onSelected(opt);
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(opt, style: const TextStyle(fontSize: 15)),
          ),
        );
      }).toList(),
    );
  }
}
