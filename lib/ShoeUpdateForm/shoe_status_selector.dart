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
    'Internal',
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
              decoration: InputDecoration(
                labelText: 'Repair Notes',
                hintText: 'Describe what was repaired...',
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                ),
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
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                ),
              ),
          ),
        ],
      ],
    );
  }
}
