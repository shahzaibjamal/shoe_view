import 'package:flutter/material.dart';
import 'package:shoe_view/shoe_model.dart';

class FilterState {
  final Set<String> selectedShipments;
  final RangeValues priceRange;
  final Set<String> selectedSizesEur;
  final Set<double> selectedConditions;
  final ShoeSortField sortBy;
  final bool ascending;

  FilterState({
    this.selectedShipments = const {},
    this.priceRange = const RangeValues(0, 100000),
    this.selectedSizesEur = const {},
    this.selectedConditions = const {},
    this.sortBy = ShoeSortField.itemId,
    this.ascending = true,
  });

  FilterState copyWith({
    Set<String>? selectedShipments,
    RangeValues? priceRange,
    Set<String>? selectedSizesEur,
    Set<double>? selectedConditions,
    ShoeSortField? sortBy,
    bool? ascending,
  }) {
    return FilterState(
      selectedShipments: selectedShipments ?? this.selectedShipments,
      priceRange: priceRange ?? this.priceRange,
      selectedSizesEur: selectedSizesEur ?? this.selectedSizesEur,
      selectedConditions: selectedConditions ?? this.selectedConditions,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
    );
  }

  bool get isShipmentFilterActive => selectedShipments.isNotEmpty;
  bool get isSizeFilterActive => selectedSizesEur.isNotEmpty;
  bool get isConditionFilterActive => selectedConditions.isNotEmpty;
  
  bool isPriceFilterActive(double maxPrice) =>
      priceRange.start > 0 || (priceRange.end > 0 && priceRange.end < maxPrice * 0.99);

  int countActiveFilters(double maxPrice) {
    int count = 0;
    if (isShipmentFilterActive) count++;
    if (isSizeFilterActive) count++;
    if (isConditionFilterActive) count++;
    if (isPriceFilterActive(maxPrice)) count++;
    return count;
  }

  bool get isEmpty =>
      selectedShipments.isEmpty &&
      selectedSizesEur.isEmpty &&
      selectedConditions.isEmpty;
}
