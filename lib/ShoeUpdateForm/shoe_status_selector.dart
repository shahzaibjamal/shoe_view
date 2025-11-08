import 'package:flutter/material.dart';

class ShoeStatusSelector extends StatelessWidget {
  final String selectedStatus;
  final String repairNotes;
  final String imagesLink;
  final bool isLoading;
  final void Function(String) onStatusChanged;
  final void Function(String) onRepairNotesChanged;
  final void Function(String) onImagesLinkChanged;

  const ShoeStatusSelector({
    super.key,
    required this.selectedStatus,
    required this.repairNotes,
    required this.imagesLink,
    required this.isLoading,
    required this.onStatusChanged,
    required this.onRepairNotesChanged,
    required this.onImagesLinkChanged,
  });

  static const List<String> statusOptions = [
    'Available',
    'Sold',
    'N/A',
    'Repaired',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Wrap(
          spacing: 12,
          children: statusOptions.map((status) {
            return ChoiceChip(
              label: Text(status),
              selected: selectedStatus == status,
              onSelected: isLoading ? null : (_) => onStatusChanged(status),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (selectedStatus == 'Repaired') ...[
          TextFormField(
            initialValue: repairNotes,
            maxLines: 3,
            enabled: !isLoading,
            onChanged: onRepairNotesChanged,
            decoration: const InputDecoration(
              labelText: 'Repair Notes',
              hintText: 'Describe what was repaired...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            enabled: !isLoading,
            initialValue: imagesLink,
            onChanged: onImagesLinkChanged,
            decoration: InputDecoration(
              labelText: 'Images URL',
              hintText: imagesLink.isEmpty ? 'No images URL provided' : null,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }
}
