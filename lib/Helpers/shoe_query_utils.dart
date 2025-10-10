import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shoe_view/shoe_model.dart';

class ShoeQueryUtils {
  static const double _epsilon = 1e-9;

  static bool doesShoeMatchSmartQuery(Shoe shoe, String rawQuery) {
    if (rawQuery.isEmpty) return true;

    final queryTokens = rawQuery
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty && !s.startsWith('lim'))
        .toList();

    if (queryTokens.isEmpty) return true;

    bool allFiltersMatch = true;
    bool isPriceFilterActive = false;
    final priceRegex = RegExp(r'^([<>=~])(\d+\.?\d*)$');

    for (final token in queryTokens) {
      final priceMatch = priceRegex.firstMatch(token);

      if (priceMatch != null) {
        isPriceFilterActive = true;
        continue;
      } else if (token.startsWith('#')) {
        final idQuery = token.substring(1).trim();
        if (!shoe.shipmentId.toString().contains(idQuery)) {
          allFiltersMatch = false;
          break;
        }
      } else if (token.contains('|')) {
        final rawSizeCriteria = token
            .split('|')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        final Set<String> targetSizes = {};

        for (final sizeStr in rawSizeCriteria) {
          targetSizes.add(_formatSizeForComparison(sizeStr));
          final inputSize = double.tryParse(sizeStr);
          if (inputSize != null) {
            final nextHalfSize = inputSize + 0.5;
            targetSizes.add(_formatSizeForComparison(nextHalfSize));
          }
        }

        final shoeSizeEur = _formatSizeForComparison(shoe.sizeEur);
        final shoeSizeUk = _formatSizeForComparison(shoe.sizeUk);

        final matchesSizeOr = targetSizes.any(
          (targetStr) => shoeSizeEur == targetStr || shoeSizeUk == targetStr,
        );

        if (!matchesSizeOr) {
          allFiltersMatch = false;
          break;
        }
      } else {
        final isPureNumber = RegExp(r'^\d+(\.\d+)?$').hasMatch(token);

        if (isPureNumber) {
          final sizeStr = token;
          final Set<String> targetSizeStrings = {};

          targetSizeStrings.add(_formatSizeForComparison(sizeStr));
          final inputSize = double.tryParse(sizeStr);
          if (inputSize != null) {
            final nextHalfSize = inputSize + 0.5;
            targetSizeStrings.add(_formatSizeForComparison(nextHalfSize));
          }

          final shoeSizeEurStr = _formatSizeForComparison(shoe.sizeEur);
          final shoeSizeUkStr = _formatSizeForComparison(shoe.sizeUk);

          final matchesSize = targetSizeStrings.any(
            (targetStr) =>
                shoeSizeEurStr == targetStr || shoeSizeUkStr == targetStr,
          );

          if (!matchesSize) {
            allFiltersMatch = false;
            break;
          }
        } else {
          if (!shoe.shoeDetail.toLowerCase().contains(token)) {
            allFiltersMatch = false;
            break;
          }
        }
      }
    }

    if (!allFiltersMatch) return false;

    if (isPriceFilterActive) {
      double? lowerBound;
      double? upperBound;
      double? exactPrice;

      for (final token in queryTokens) {
        final match = priceRegex.firstMatch(token);
        if (match == null) continue;

        final operator = match.group(1);
        final valueStr = match.group(2);
        final value = _safeDoubleParse(valueStr);

        if (operator == '=') {
          exactPrice = value;
        } else if (operator == '<') {
          upperBound = upperBound == null ? value : min(upperBound, value);
        } else if (operator == '>') {
          lowerBound = lowerBound == null ? value : max(lowerBound, value);
        } else if (operator == '~') {
          const range = 500.0;
          lowerBound = lowerBound == null
              ? value - range
              : max(lowerBound, value - range);
          upperBound = upperBound == null
              ? value + range
              : min(upperBound, value + range);
        }
      }

      final price = shoe.sellingPrice;

      if (exactPrice != null) {
        return (price - exactPrice).abs() < _epsilon;
      }

      if (lowerBound != null && price < lowerBound - _epsilon) return false;
      if (upperBound != null && price > upperBound + _epsilon) return false;

      return true;
    }

    return true;
  }

  static List<Shoe> sortAndLimitShoes({
    required List<Shoe> shoes,
    required String rawQuery,
    required String sortField,
    required bool sortAscending,
  }) {
    List<Shoe> displayedShoes = List<Shoe>.from(shoes);

    if (sortField.toLowerCase().contains('sold')) {
      displayedShoes = displayedShoes.where((a) => a.status == 'Sold').toList();
    } else if (sortField.toLowerCase().contains('repaired')) {
      displayedShoes = displayedShoes
          .where((a) => a.status == 'Repaired')
          .toList();
    } else {
      // Default: show only Available
      displayedShoes = displayedShoes
          .where((a) => a.status == 'Available')
          .toList();
    }
    // --- 1. Sorting ---
    displayedShoes.sort((a, b) {
      final shipmentA = int.tryParse(a.shipmentId) ?? 0;
      final shipmentB = int.tryParse(b.shipmentId) ?? 0;
      int comparison = shipmentA.compareTo(shipmentB);

      if (comparison == 0) {
        if (sortField == 'size') {
          final sizeA = double.tryParse(a.sizeEur) ?? 0.0;
          final sizeB = double.tryParse(b.sizeEur) ?? 0.0;
          comparison = sizeA.compareTo(sizeB);
        } else if (sortField == 'sellingPrice') {
          comparison = a.sellingPrice.compareTo(b.sellingPrice);
        } else if (sortField == 'ItemId') {
          comparison = a.itemId.compareTo(b.itemId);
        }

        if (!sortAscending) {
          comparison = -comparison;
        }
      }

      return comparison;
    });

    // --- 2. Limiting & Randomization ---
    final limRegex = RegExp(r'lim([<>]|~)(\d+)');
    final limMatch = limRegex.firstMatch(rawQuery.toLowerCase());

    if (limMatch != null) {
      final operator = limMatch.group(1);
      final limitValue = int.tryParse(limMatch.group(2) ?? '0') ?? 0;

      if (limitValue > 0) {
        if (operator == '<') {
          displayedShoes = displayedShoes.take(limitValue).toList();
        } else if (operator == '>') {
          displayedShoes = displayedShoes.length > limitValue
              ? displayedShoes.skip(limitValue).toList()
              : [];
        } else if (operator == '~') {
          final random = Random();
          displayedShoes = List<Shoe>.from(displayedShoes)..shuffle(random);
          displayedShoes = displayedShoes.take(limitValue).toList();
        }
      }
    }

    return displayedShoes;
  }

  static double _safeDoubleParse(String? text) {
    if (text == null || text.isEmpty) return 0.0;
    return double.tryParse(text) ?? 0.0;
  }

  static String _formatSizeForComparison(dynamic size) {
    if (size == null) return '';
    return size.toString().trim().replaceAll(RegExp(r'\.0$'), '');
  }

  static String normalizeGoogleImageUrl(String url, {int width = 300}) {
    final regex = RegExp(
      r'(=w\d+)$',
    ); // matches '=w' followed by digits at the end
    if (regex.hasMatch(url)) {
      return url.replaceAll(regex, '=w$width');
    } else {
      return '$url=w$width';
    }
  }
}
