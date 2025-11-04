import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/shoe_display_card.dart';

class ShoeSizePicker extends StatelessWidget {
  final bool isSingleSize;
  final bool isBound;
  final bool isLoading;
  final String displayEurSize;
  final String displayUkSize;
  final Set<String> currentEurSizes;
  final void Function(bool) onBoundChanged;
  final void Function(String) onEurSizeSelected;
  final void Function(String) onUkSizeSelected;
  final void Function(Set<String>) onMultiSizeChanged;

  const ShoeSizePicker({
    super.key,
    required this.isSingleSize,
    required this.isBound,
    required this.isLoading,
    required this.displayEurSize,
    required this.displayUkSize,
    required this.currentEurSizes,
    required this.onBoundChanged,
    required this.onEurSizeSelected,
    required this.onUkSizeSelected,
    required this.onMultiSizeChanged,
  });

  Future<void> _showSizePicker(
    BuildContext context,
    String selectedSize,
    List<String> sizeList,
    Function(String) onSelected,
    String title,
  ) async {
    String tempSelected = selectedSize;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SizedBox(
                height: 200,
                child: CupertinoPicker.builder(
                  scrollController: FixedExtentScrollController(
                    initialItem: sizeList.indexOf(selectedSize),
                  ),
                  itemExtent: 32.0,
                  onSelectedItemChanged: (index) {
                    tempSelected = sizeList[index];
                  },
                  childCount: sizeList.length,
                  itemBuilder: (context, index) =>
                      Center(child: Text(sizeList[index])),
                ),
              ),
              TextButton(
                onPressed: () {
                  onSelected(tempSelected);
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSingleSize(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isBound ? 'Sizes linked (Auto)' : 'Sizes independent (Manual)',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            Switch(
              value: isBound,
              onChanged: isLoading ? null : onBoundChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizeDisplayCard(
                title: 'Size EUR',
                value: displayEurSize,
                onTap: isLoading
                    ? null
                    : () => _showSizePicker(
                        context,
                        displayEurSize,
                        ShoeQueryUtils.eurSizesList,
                        onEurSizeSelected,
                        'Select EUR Size',
                      ),
                isBound: isBound,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizeDisplayCard(
                title: 'Size UK',
                value: displayUkSize,
                onTap: isLoading
                    ? null
                    : () => _showSizePicker(
                        context,
                        displayUkSize,
                        ShoeQueryUtils.ukSizesList,
                        onUkSizeSelected,
                        'Select UK Size',
                      ),
                isBound: isBound,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMultiSize(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selected EUR Sizes:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6.0,
          runSpacing: 6.0,
          children: ShoeQueryUtils.eurSizesList.map((size) {
            final isSelected = currentEurSizes.contains(size);
            return FilterChip(
              label: Text(size),
              selected: isSelected,
              onSelected: isLoading
                  ? null
                  : (selected) {
                      final updated = Set<String>.from(currentEurSizes);
                      if (selected) {
                        updated.add(size);
                      } else {
                        if (updated.length > 1) updated.remove(size);
                      }
                      onMultiSizeChanged(updated);
                    },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        if (currentEurSizes.isEmpty)
          const Text(
            'Please select at least one size.',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return isSingleSize ? _buildSingleSize(context) : _buildMultiSize(context);
  }
}
