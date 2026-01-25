import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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
    bool applyStatusFilter = true,
  }) {
    List<Shoe> displayedShoes = List<Shoe>.from(shoes);

    if (applyStatusFilter) {
      if (sortField.toLowerCase().contains('sold')) {
        displayedShoes = displayedShoes
            .where((a) => a.status == 'Sold')
            .toList();
      } else if (sortField.toLowerCase().contains('n/a')) {
        displayedShoes = displayedShoes
            .where((a) => a.status == 'N/A')
            .toList();
      } else if (sortField.toLowerCase().contains('repaired')) {
        displayedShoes = displayedShoes
            .where((a) => a.status == 'Repaired')
            .toList();
      } else if (sortField.toLowerCase().contains('in')) {
        displayedShoes = displayedShoes
            .where((a) => a.status == 'Internal')
            .toList();
      } else {
        // Default: show only Available
        displayedShoes = displayedShoes
            .where((a) => a.status == 'Available')
            .toList();
      }
    } else {
      // 👇 Always exclude Sold and Repaired when skipping status filter
      displayedShoes = displayedShoes
          .where((a) => a.status != 'Sold' && a.status != 'Repaired')
          .toList();
    } // --- 1. Sorting ---
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
        AppLogger.log(
          'successfully added - ${newShoe.shipmentId}_${newShoe.itemId} Detail: ${newShoe.shoeDetail}',
        );
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
      case 'in':
        return 'Internal';
      case 'repaired':
        return 'Repaired';
      default:
        return field[0].toUpperCase() + field.substring(1);
    }
  }

  static int generateOriginalPrice(
    double actualPrice, {
    double minPercent = 7,
    double maxPercent = 10,
  }) {
    // pick a random percentage between min and max
    final random = Random();
    final percent =
        minPercent + (random.nextDouble() * (maxPercent - minPercent));

    // apply percentage
    double inflated = actualPrice + (actualPrice * percent / 100);

    // round to nearest 0, 50, or 100
    int rounded = roundToNearest(inflated.toInt());

    return rounded;
  }

  static int roundToNearest(int value) {
    int remainder = value % 100;

    if (remainder < 25) return value - remainder; // nearest 0
    if (remainder < 75) return value - remainder + 50; // nearest 50
    return value - remainder + 100; // nearest 100
  }

  static double roundToNearestDouble(double value) {
    return roundToNearest(value.toInt()).toDouble();
  }

  static String removeSalePrice(String text) {
    final regex = RegExp(r'^.*Price:\s*~.*?~\s*X\s*.*?✅.*$', multiLine: true);
    return text.replaceAll(regex, '').trim();
  }

  static Future<void> saveShoesToAppExternal(List<Shoe> shoes) async {
    // Get the external storage directory for your app
    final Directory? extDir = await getExternalStorageDirectory();

    if (extDir != null) {
      // Create a "downloads" subfolder inside your app's external files dir
      final downloadsDir = Directory('${extDir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Encode your list to JSON
      final jsonContent = jsonEncode(shoes.map((s) => s.toMap()).toList());

      // Save file
      final file = File('${downloadsDir.path}/shoes.json');
      await file.writeAsString(jsonContent);

      print("✅ File saved at: ${file.path}");
    } else {
      print("❌ Could not get external storage directory");
    }
  }

  static String generateCopyText({
    required List<Shoe> shoes,
    required String currencyCode,
    required bool isRepairedInfoAvailable,
    required bool isSalePrice,
    required bool isFlatSale,
    required bool isPriceHidden,
    required double flatDiscount,
    required double lowDiscount,
    required double highDiscount,
    required String sortField,
  }) {
    final symbol = ShoeQueryUtils.getSymbolFromCode(currencyCode);

    final buffer = StringBuffer();
    final gap = shoes.length > 1 ? '    ' : '';

    final shoeList = shoes.take(30).toList(); // Hardcoded maxImages match
    if (shoeList.length > 1) {
      buffer.writeln('Kick Hive Drop - ${shoeList.length} Pairs\n');
    }
    if (isFlatSale) {
      buffer.writeln(
        '🔥 *Flat $flatDiscount% OFF* 🔥\nOffer ends soon! \n',
      );
    }

    final isSold = sortField.toLowerCase().contains('sold');

    for (int i = 0; i < shoeList.length; i++) {
      final shoe = shoeList[i];
      final numbering = shoeList.length > 1 ? '${i + 1}. ' : '';
      final indent = ' ' * (numbering.length) + gap;

      String displayDetail = shoe.shoeDetail;
      // Check for regex match directly since contains('no insoles') misses 'no insole'
      final noInsoleRegex = RegExp(r'no insoles?', caseSensitive: false);
      final bool hasNoInsoles = noInsoleRegex.hasMatch(displayDetail);
      
      if (hasNoInsoles) {
        displayDetail = displayDetail
            .replaceAll(noInsoleRegex, '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }

      buffer.writeln('$numbering$displayDetail');
      if (shoe.sizeEur != null && shoe.sizeEur!.length > 1) {
        // Multiple EUR sizes
        String line = '${indent}Sizes: EUR ';
        for (var size in shoe.sizeEur!) {
          line += '$size, ';
        }

        // Trim trailing comma
        line = line.trim().replaceAll(RegExp(r',$'), '');

        // Append CM if available
        if (shoe.sizeCm != null && shoe.sizeCm!.isNotEmpty) {
          line += ' | CM ${shoe.sizeCm!.join(", ")}';
        }

        buffer.writeln(line);
      } else {
        // Single size case
        String line =
            '${indent}Sizes: EUR ${shoe.sizeEur?.first}, UK ${shoe.sizeUk?.first}';

        // Append CM if available
        if (shoe.sizeCm != null && shoe.sizeCm!.isNotEmpty) {
          line += ', CM ${shoe.sizeCm!.first}';
        }

        buffer.writeln(line);
      }
      final sellingPrice = isFlatSale
          ? ShoeQueryUtils.roundToNearestDouble(
              shoe.sellingPrice * (1 - flatDiscount / 100),
            )
          : shoe.sellingPrice;
      if (!isSold) {
        if (!isPriceHidden) {
          if (isSalePrice) {
            buffer.writeln(
              '${indent}Price: ❌ ~$symbol${ShoeQueryUtils.generateOriginalPrice(sellingPrice, minPercent: lowDiscount, maxPercent: highDiscount)}/-~ ✅ $symbol${sellingPrice}/-',
            );
          } else if (isFlatSale) {
            buffer.writeln(
              '${indent}Price: ❌ ~$symbol${shoe.sellingPrice}/-~ ✅ $symbol${sellingPrice}/-',
            );
          } else {
            buffer.writeln('${indent}Price: $symbol${sellingPrice}/-');
          }
        }
        buffer.writeln(
          '${indent}Condition: ${shoe.condition}/10${hasNoInsoles ? " (no insoles)" : ""}',
        );
      }
      if (shoe.instagramLink.isNotEmpty) {
        buffer.writeln('${indent}Instagram: ${shoe.instagramLink}');
      }
      if (shoe.tiktokLink.isNotEmpty) {
        buffer.writeln('${indent}TikTok: ${shoe.tiktokLink}');
      }
      if (shoe.status == 'Repaired') {
        if (isRepairedInfoAvailable) {
          String notes = shoe.notes;
          if (shoe.notes.contains("Not repaired")) {
            notes = notes.replaceAll("Not repaired", "").trim();
          } else {
            buffer.writeln('$indent❌❌ Repaired ❌❌');
          }
          buffer.writeln('${indent}Note: ✨$notes✨');
        }
        buffer.writeln('${indent}Images: ${shoe.imagesLink}');
      }
      if (isSold) {
        buffer.writeln(); // blank line for separation
        buffer.writeln('${indent}❌ SOLD ❌');
      }
      buffer.writeln(); // blank line for separation
    }

    // Only add "Tap to claim" if none are sold
    if (!isSold) {
      buffer.writeln('Tap to claim 📦');
    }

    return buffer.toString();
  }
}
