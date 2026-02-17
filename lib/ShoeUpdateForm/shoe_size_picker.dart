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
  final String displayCmSize;
  final Set<String> currentEurSizes;
  final bool showCmInput;
  final void Function(bool) onBoundChanged;
  final void Function(bool) onCmToggleChanged; // Added callback
  final void Function(String) onEurSizeSelected;
  final void Function(String) onUkSizeSelected;
  final void Function(String) onCmSizeSelected;
  final void Function(Set<String>) onMultiSizeChanged;

  const ShoeSizePicker({
    super.key,
    required this.isSingleSize,
    required this.isBound,
    required this.isLoading,
    required this.displayEurSize,
    required this.displayUkSize,
    required this.displayCmSize,
    required this.currentEurSizes,
    required this.showCmInput,
    required this.onBoundChanged,
    required this.onCmToggleChanged, // Added param
    required this.onEurSizeSelected,
    required this.onUkSizeSelected,
    required this.onCmSizeSelected,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              SizedBox(
                height: 250,
                child: CupertinoPicker.builder(
                  scrollController: FixedExtentScrollController(
                    initialItem: sizeList.indexOf(selectedSize),
                  ),
                  itemExtent: 40.0,
                  onSelectedItemChanged: (index) {
                    tempSelected = sizeList[index];
                  },
                  childCount: sizeList.length,
                  itemBuilder: (context, index) => Center(
                    child: Text(
                      sizeList[index],
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      onSelected(tempSelected);
                      Navigator.pop(context);
                    },
                    child: const Text('Confirm Selection'),
                  ),
                ),
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
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
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
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Include CM Size',
              style: TextStyle(
                fontSize: 12, 
                color: Theme.of(context).textTheme.bodySmall?.color, 
                fontWeight: FontWeight.w600,
              ),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch.adaptive(
                value: showCmInput,
                onChanged: isLoading ? null : onCmToggleChanged,
                activeColor: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
        if (showCmInput) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4), // ⬆️ Add vertical padding to enlarge
            child: SizeDisplayCard(
              title: 'Size CM',
              value: '$displayCmSize cm', // Add 'cm' suffix for clarity
              onTap: isLoading
                  ? null
                  : () => _showSizePicker(
                      context,
                      displayCmSize,
                      ShoeQueryUtils.cmSizesList,
                      onCmSizeSelected,
                      'Select CM Size',
                    ),
              isBound: false,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMultiSize(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected EUR Sizes:',
          style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
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
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Please select at least one size.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error, 
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return isSingleSize ? _buildSingleSize(context) : _buildMultiSize(context);
  }
}
