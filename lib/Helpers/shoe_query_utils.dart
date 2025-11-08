import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/Services/firebase_service.dart';
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

        // ⭐️ MODIFIED: Check if ANY size in the shoe's size lists matches ANY target size
        final matchesSizeOr = targetSizes.any(
          (targetStr) =>
              (shoe.sizeEur ?? []).any(
                (s) => _formatSizeForComparison(s) == targetStr,
              ) ||
              (shoe.sizeUk ?? []).any(
                (s) => _formatSizeForComparison(s) == targetStr,
              ),
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

          // ⭐️ MODIFIED: Check if ANY size in the shoe's size lists matches ANY target size
          final matchesSize = targetSizeStrings.any(
            (targetStr) =>
                (shoe.sizeEur ?? []).any(
                  (s) => _formatSizeForComparison(s) == targetStr,
                ) ||
                (shoe.sizeUk ?? []).any(
                  (s) => _formatSizeForComparison(s) == targetStr,
                ),
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

    // ... (Price filtering logic - UNCHANGED) ...
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
    } else if (sortField.toLowerCase().contains('n/a')) {
      displayedShoes = displayedShoes.where((a) => a.status == 'N/A').toList();
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
    final isStatusFiltered = [
      'sold',
      'n/a',
      'repaired',
    ].any((status) => sortField.toLowerCase().contains(status));

    displayedShoes.sort((a, b) {
      final shipmentA = int.tryParse(a.shipmentId) ?? 0;
      final shipmentB = int.tryParse(b.shipmentId) ?? 0;

      // Always sort by shipmentId first
      int comparison = shipmentA.compareTo(shipmentB);
      if (comparison != 0) return comparison;

      // Then sort by the selected field
      final normalizedField = sortField.toLowerCase();

      if (normalizedField == 'itemid') {
        comparison = a.itemId.compareTo(b.itemId);
      } else if (normalizedField == 'size') {
        final sizeA = _safeDoubleParse(a.sizeEur?.first);
        final sizeB = _safeDoubleParse(b.sizeEur?.first);
        comparison = sizeA.compareTo(sizeB);
      } else if (normalizedField == 'sellingprice') {
        comparison = a.sellingPrice.compareTo(b.sellingPrice);
      } else {
        // Default fallback: itemId
        comparison = a.itemId.compareTo(b.itemId);
      }

      return sortAscending ? comparison : -comparison;
    }); // --- 2. Limiting & Randomization ---
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

  // --- Data Conversion & Validation Helpers ---
  static int safeIntParse(String? text) {
    if (text == null || text.isEmpty) return 0;
    return int.tryParse(text) ?? 0;
  }

  static String? validateLink(String? value, String requiredDomain) {
    if (value == null || value.trim().isEmpty) {
      return null; // Links are optional
    }
    if (!value.toLowerCase().contains(requiredDomain)) {
      return 'If provided, must contain "$requiredDomain".';
    }
    return null;
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

  // Lists for the CupertinoPicker
  static const List<String> eurSizesList = [
    '37',
    '37.5',
    '38',
    '38.5',
    '39',
    '39.5',
    '40',
    '40.5',
    '41',
    '41.5',
    '42',
    '42.5',
    '43',
    '43.5',
    '44',
    '44.5',
    '45',
    '45.5',
    '46',
    '46.5',
    '47',
    '47.5',
    '48',
    '48.5',
    '49',
    '49.5',
  ];
  // --- SIZE CONVERSION DATA ---
  // A reliable mapping based on standard shoe conversion charts for sports shoes.
  static const Map<String, String> eurToUk = {
    // Start (37 - 39.5)
    '37': '4',
    '37.5': '4.5',
    '38': '5',
    '38.5': '5.5',
    '39': '6',
    '39.5': '6.5', // Filled step
    // Mid-range (40 - 43.5)
    '40': '6.5', // Original value retained
    '40.5': '7',
    '41': '7.5',
    '41.5': '7.5', // Filled step (often 41.5 is the same as 41 or 42 is an 8)
    '42': '8',
    '42.5': '8.5',
    '43': '9',
    '43.5': '9.5', // Filled step
    // Upper Mid-range (44 - 47)
    '44': '9.5', // Original value retained
    '44.5': '10',
    '45': '10.5',
    '45.5': '11', // Filled step
    '46': '11', // Original value retained
    '46.5': '11.5', // Filled step
    '47': '12', // Original value retained
    // Extended range (47.5 - 49.5)
    '47.5': '12.5',
    '48': '13',
    '48.5': '13.5',
    '49': '14',
    '49.5': '14.5',
  };

  // Generate reverse map (UK to EUR)
  static Map<String, String> ukToEur = Map.fromEntries(
    eurToUk.entries.map((e) => MapEntry(e.value, e.key)),
  );

  static List<String> ukSizesList = eurToUk.values.toSet().toList()
    ..sort((a, b) => double.parse(a).compareTo(double.parse(b)));

  static List<Map<String, String>> currencies = [
    {'code': 'USD', 'symbol': '\$'},
    {'code': 'PKR', 'symbol': '₨.'},
    {'code': 'EUR', 'symbol': '€'},
    {'code': 'GBP', 'symbol': '£'},
    {'code': 'JPY', 'symbol': '¥'},
    {'code': 'AUD', 'symbol': 'A\$'},
    {'code': 'CAD', 'symbol': 'C\$'},
    {'code': 'INR', 'symbol': '₹'},
    {'code': 'CNY', 'symbol': '¥'},
  ];

  static String getSymbolFromCode(String code) {
    return ShoeQueryUtils.currencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => {'symbol': '\$'},
    )['symbol']!;
  }

  // --- CONDITION DATA ---
  // Generate list of conditions from 1.0 to 10.0 in 0.5 increments
  static List<String> conditionList = List<String>.generate(
    19, // Total items from 1.0 to 10.0 in 0.5 increments (1.0, 1.5, ..., 9.5, 10.0)
    (i) => (1.0 + i * 0.5).toStringAsFixed(1),
  );

  static String formatSizes(List<String>? sizes) {
    if (sizes == null || sizes.isEmpty) {
      return 'N/A';
    }
    return sizes.length > 1 ? sizes.join(', ') : sizes.first;
  }

  static Future<void> debugAddShoesFromSheetData(
    FirebaseService firebaseService,
    List<Shoe> shoes,
  ) async {
    String? base64Image;
    for (var newShoe in shoes) {
      final urlResponse = await http.get(Uri.parse(newShoe.remoteImageUrl));
      if (urlResponse.statusCode == 200) {
        final bytes = urlResponse.bodyBytes;
        base64Image = base64Encode(bytes);
      }
      final response = await firebaseService.updateShoe(
        newShoe,
        base64Image,
        isTest: true, // will be null if no image
      );
      if (response['success']) {
        final url = response['remoteImageUrl'];
        AppLogger.log('successfully added - $url');
      } else {
        AppLogger.log('Unable to add - ${newShoe.shoeDetail}');
      }
    }
  }

  static void logDynamic(dynamic data) {
    if (data == null) {
      AppLogger.log("⚠️ Data is null.");
      return;
    }

    AppLogger.log("🔍 Logging data of type: ${data.runtimeType}");

    if (data is Map) {
      data.forEach((key, value) {
        AppLogger.log("• $key: $value");
      });
    } else if (data is List) {
      for (int i = 0; i < data.length; i++) {
        AppLogger.log("• [$i]: ${data[i]}");
      }
    } else {
      AppLogger.log("• Value: $data");
    }
  }

  static String cleanLink(String url) {
    final uri = Uri.parse(url);
    return '${uri.scheme}://${uri.host}${uri.path}';
  }

  static String formatLabel(String field) {
    switch (field) {
      case 'sellingPrice':
        return 'Price';
      case 'n/a':
        return 'N/A';
      case 'repaired':
        return 'Repaired';
      default:
        return field[0].toUpperCase() + field.substring(1);
    }
  }
}
