import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shoe_view/shoe_model.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/Filters/filter_state.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:provider/provider.dart';

class FilterMenu extends StatefulWidget {
  final FilterState currentFilter;
  final List<Shoe> allShoes;
  final ShoeCategory selectedCategory;
  final ValueChanged<ShoeCategory> onCategoryChanged;
  final Function(FilterState) onFilterChanged;
  final VoidCallback onClearAll;
  final bool isFlatSale;
  final double flatDiscount;
  final bool applySaleToAllStatuses;

  const FilterMenu({
    super.key,
    required this.currentFilter,
    required this.allShoes,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.onFilterChanged,
    required this.onClearAll,
    this.isFlatSale = false,
    this.flatDiscount = 0,
    this.applySaleToAllStatuses = false,
    this.isTest = false,
    this.categoryFixedPrices = const {},
  });

  final bool isTest;
  final Map<String, double?> categoryFixedPrices;

  @override
  State<FilterMenu> createState() => _FilterMenuState();
}

class _FilterMenuState extends State<FilterMenu> {
  late FilterState _tempState;
  late ShoeCategory _tempCategory;
  late double _globalMaxPrice;
  late List<String> _globalShipments;

  @override
  void initState() {
    super.initState();
    _tempState = widget.currentFilter;
    _tempCategory = widget.selectedCategory;
    
    // 🎯 Stabilize Bounds: Calculate once from all shoes to avoid jitter
    if (widget.allShoes.isEmpty) {
      _globalMaxPrice = 100000;
      _globalShipments = [];
    } else {
      _globalMaxPrice = widget.allShoes.map((s) {
        final fixedPrice = widget.isTest ? widget.categoryFixedPrices[s.status] : null;
        final effectivePrice = fixedPrice ?? ((widget.isFlatSale && (widget.applySaleToAllStatuses || s.status == 'Available'))
            ? ShoeQueryUtils.roundToNearestDouble(s.sellingPrice * (1 - widget.flatDiscount / 100))
            : s.sellingPrice);
        return effectivePrice;
      }).reduce(max);
      _globalShipments = widget.allShoes
          .map((s) => s.shipmentId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList()..sort();
    }
    
    // Ensure initial temp state is within stable bounds
    if (_tempState.priceRange.end == 0 || _tempState.priceRange.end > _globalMaxPrice * 1.5) {
      _tempState = _tempState.copyWith(priceRange: RangeValues(0, _globalMaxPrice));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.black12,
              blurRadius: 15,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              bottom: false,
              child: _buildHeader(),
            ),
            Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.1)),
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  expansionTileTheme: ExpansionTileThemeData(
                    iconColor: Theme.of(context).colorScheme.primary,
                    collapsedIconColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                    textColor: Theme.of(context).colorScheme.primary,
                    collapsedTextColor: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildCategorySection(),
                    _buildSortSection(),
                    _buildShipmentSection(),
                    _buildPriceSection(),
                    _buildSizeSection(),
                    _buildConditionSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: _buildFooter(),
            ),
          ],
        ),
        ),
    );
  }

  Widget _buildCategorySection() {
    return _FilterSection(
      title: 'Collection Category',
      initiallyExpanded: true,
      isActive: _tempCategory != ShoeCategory.available,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: ShoeCategory.values.map((cat) {
            final isSelected = _tempCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(ShoeQueryUtils.formatLabel(cat.name)),
                selected: isSelected,
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _tempCategory = cat);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Filters & Sort',
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold, 
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _tempState = FilterState(priceRange: RangeValues(0, _globalMaxPrice));
                _tempCategory = ShoeCategory.available;
              });
              widget.onClearAll();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _buildSortSection() {
    return _FilterSection(
      title: 'Sort Order',
      isActive: _tempState.sortBy != ShoeSortField.itemId || !_tempState.ascending,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            SegmentedButton<ShoeSortField>(
              segments: const [
                ButtonSegment(value: ShoeSortField.itemId, label: Text('ID')),
                ButtonSegment(value: ShoeSortField.sellingPrice, label: Text('Price')),
                ButtonSegment(value: ShoeSortField.size, label: Text('Size')),
              ],
              selected: {_tempState.sortBy},
              onSelectionChanged: (val) {
                setState(() => _tempState = _tempState.copyWith(sortBy: val.first));
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Ascending'),
                  selected: _tempState.ascending,
                  onSelected: (val) {
                    if (val) setState(() => _tempState = _tempState.copyWith(ascending: true));
                  },
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Descending'),
                  selected: !_tempState.ascending,
                  onSelected: (val) {
                    if (val) setState(() => _tempState = _tempState.copyWith(ascending: false));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentSection() {
    if (_globalShipments.isEmpty) return const SizedBox.shrink();

    return _FilterSection(
      title: 'Shipment Groups',
      isActive: _tempState.isShipmentFilterActive,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _globalShipments.map((id) {
            final isSelected = _tempState.selectedShipments.contains(id);
            return FilterChip(
              label: Text('#$id'),
              selected: isSelected,
              onSelected: (selected) {
                final newSet = Set<String>.from(_tempState.selectedShipments);
                if (selected) newSet.add(id); else newSet.remove(id);
                setState(() => _tempState = _tempState.copyWith(selectedShipments: newSet));
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    final maxVal = _globalMaxPrice;
    if (maxVal <= 0) return const SizedBox.shrink();

    return _FilterSection(
      title: 'Price Range',
      initiallyExpanded: true,
      isActive: _tempState.isPriceFilterActive(maxVal),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            RangeSlider(
              values: _tempState.priceRange,
              min: 0,
              max: maxVal,
              divisions: 50,
              activeColor: Theme.of(context).colorScheme.primary,
              labels: RangeLabels(
                _tempState.priceRange.start.toStringAsFixed(0),
                _tempState.priceRange.end.toStringAsFixed(0),
              ),
              onChanged: (val) {
                setState(() => _tempState = _tempState.copyWith(priceRange: val));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Min: ${_tempState.priceRange.start.toStringAsFixed(0)}', 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  Text(
                    'Max: ${_tempState.priceRange.end.toStringAsFixed(0)}', 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeSection() {
    return _FilterSection(
      title: 'EUR Sizes',
      isActive: _tempState.isSizeFilterActive,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: ShoeQueryUtils.eurSizesList.map((size) {
            final isSelected = _tempState.selectedSizesEur.contains(size);
            return FilterChip(
              label: Text(size, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              visualDensity: VisualDensity.compact,
              onSelected: (selected) {
                final newSet = Set<String>.from(_tempState.selectedSizesEur);
                if (selected) newSet.add(size); else newSet.remove(size);
                setState(() => _tempState = _tempState.copyWith(selectedSizesEur: newSet));
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildConditionSection() {
    final conditions = [10.0, 9.5, 9.0, 8.5, 8.0, 7.5];
    return _FilterSection(
      title: 'Shoe Condition',
      isActive: _tempState.isConditionFilterActive,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 8,
          children: conditions.map((c) {
            final isSelected = _tempState.selectedConditions.contains(c);
            return FilterChip(
              label: Text('$c'),
              selected: isSelected,
              onSelected: (selected) {
                final newSet = Set<double>.from(_tempState.selectedConditions);
                if (selected) newSet.add(c); else newSet.remove(c);
                setState(() => _tempState = _tempState.copyWith(selectedConditions: newSet));
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final count = _tempState.countActiveFilters(_globalMaxPrice);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.05))),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.black12, 
            blurRadius: 10, 
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        onPressed: () {
          widget.onCategoryChanged(_tempCategory); // 🎯 Apply Category
          widget.onFilterChanged(_tempState);      // 🎯 Apply Filters
          Navigator.pop(context);
        },
        child: Text(
          count > 0 ? 'APPLY $count FILTERS' : 'APPLY FILTERS',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
      ),
    );
  }
  }


class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final bool isActive;

  const _FilterSection({
    required this.title, 
    required this.child,
    this.initiallyExpanded = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              // Already handled by ExpansionTileTheme above, but keep for safety/Row consistency
              color: isActive 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.orangeAccent, // 🎯 Higher contrast
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
              ),
            ),
          ],
        ],
      ),
      initiallyExpanded: initiallyExpanded,
      childrenPadding: const EdgeInsets.only(bottom: 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [child],
    );
  }
}
