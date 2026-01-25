import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/Image/collage_utils.dart';
import 'package:shoe_view/Image/shoe_network_image.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:shoe_view/error_dialog.dart';
import 'package:shoe_view/Services/firebase_service.dart';
import 'package:shoe_view/shoe_model.dart';

class CollageBuilder extends StatefulWidget {
  final List<Shoe> shoes;
  final String text;
  final FirebaseService firebaseService;
  static const int maxImages = 16;

  const CollageBuilder({
    super.key,
    required this.firebaseService,
    required this.shoes,
    required this.text,
  });

  @override
  State<CollageBuilder> createState() => _CollageBuilderState();
}

class _CollageBuilderState extends State<CollageBuilder> {
  final _collageKey = GlobalKey();
  bool _isSaving = false;
  // Use a nullable ad to manage its state clearly
  RewardedAd? _rewardedAd;
  File? _logoFile;
  final ValueNotifier<bool> isAdLoading = ValueNotifier(
    true,
  ); // Still useful for dialog state

  @override
  void initState() {
    // 🎯 Call load in initState as before
    bool isTest = context.read<AppStatusNotifier>().isTest;

    if (!isTest) loadRewardedAd();
    _loadLogo();
    super.initState();
  }

  // 🎯 Dispose the ad properly
  @override
  void dispose() {
    _rewardedAd?.dispose();
    isAdLoading.dispose(); // Dispose the ValueNotifier
    super.dispose();
  }

  Future<void> _loadLogo() async {
    final dir = await getApplicationDocumentsDirectory();
    final logoPath = File('${dir.path}/logo.jpg');
    if (await logoPath.exists()) {
      setState(() => _logoFile = logoPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagesToDisplay = widget.shoes
        .take(CollageBuilder.maxImages)
        .toList();
    final imageCount = imagesToDisplay.length;
    if (imageCount == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No shoes selected to build collage.'),
        ),
      );
    }

    final int crossAxisCount = CollageUtils.calculateGridSize(imageCount);
    final int actualRowCount = (imageCount / crossAxisCount).ceil();

    const double spacing = 4.0;
    const double screenHorizontalPadding = 40.0; // 20.0 on each side

    // 🎯 Get the width available for the collage
    final double totalAvailableWidth =
        MediaQuery.of(context).size.width - screenHorizontalPadding;

    // 🎯 Use the new function to calculate itemSize dynamically
    final double itemSize = _calculateItemSizeFromWidth(
      totalAvailableWidth,
      crossAxisCount,
    );

    const double internalPadding = 4.0;

    // 1. Calculate the core content dimensions (Tiles + Gaps)
    final double contentWidth =
        (crossAxisCount * itemSize) + ((crossAxisCount - 1) * spacing);

    // 2. Calculate the core content height (tiles and spacing between them)
    final double contentHeight =
        (actualRowCount * itemSize) +
        // Only spacing BETWEEN rows (RowCount - 1)
        (actualRowCount > 0 ? (actualRowCount - 1) * spacing : 0.0);

    // 3. Calculate the final dimensions by adding 2 * internalPadding to the content size.
    final double collageWidth = contentWidth + (internalPadding * 2);
    final double collageHeight = contentHeight + (internalPadding * 2);

    final bool isOddSquareGrid =
        (crossAxisCount == actualRowCount) && (crossAxisCount % 2 != 0);
    final double logoSize = isOddSquareGrid ? 40.0 : 60.0;
    final double logoTopPosition;
    if (isOddSquareGrid) {
      // Top-aligned position: Small margin from the top edge (e.g., 5.0)
      logoTopPosition = 0.0;
      // Center horizontally
    } else {
      // Centered position (for all other grids, including 2x2, 4x4, and non-squares)
      logoTopPosition = (collageHeight - logoSize) / 2;
    }
    final double logoLeftPosition =
        (collageWidth - logoSize) / 2; // Center horizontally
    bool isSalePrice = context.read<AppStatusNotifier>().isSalePrice;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: RepaintBoundary(
            key: _collageKey,
            child: Container(
              width: collageWidth,
              height: collageHeight,
              padding: EdgeInsets.all(internalPadding),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.white,
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(actualRowCount, (rowIndex) {
                      final start = rowIndex * crossAxisCount;
                      final end = min(start + crossAxisCount, imageCount);
                      final rowImages = imagesToDisplay.sublist(start, end);

                      return Padding(
                        // Vertical Spacing
                        padding: EdgeInsets.only(
                          top: rowIndex == 0 ? 0.0 : spacing,
                        ),
                        child: SizedBox(
                          width: collageWidth,
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.start, // Align to start
                            mainAxisSize: MainAxisSize.max, // Take full width
                            children: List.generate(crossAxisCount, (colIndex) {
                              // Check if this cell actually contains an image
                              if (colIndex < rowImages.length) {
                                final shoe = rowImages[colIndex];
                                final index = start + colIndex;

                                return Padding(
                                  // Horizontal Spacing: Only apply padding to the LEFT of items after the first one
                                  padding: EdgeInsets.only(
                                    left: colIndex == 0 ? 0.0 : spacing,
                                  ),
                                  child: _buildShoeTile(
                                    shoe,
                                    index,
                                    itemSize,
                                    imageCount,
                                  ),
                                );
                              } else {
                                // If this is an empty cell (in the last partial row)
                                return Padding(
                                  // Apply the same padding logic for empty cells to maintain spacing integrity
                                  padding: EdgeInsets.only(
                                    left: colIndex == 0 ? 0.0 : spacing,
                                  ),
                                  child: SizedBox(
                                    width: itemSize,
                                    height: itemSize,
                                  ),
                                );
                              }
                            }),
                          ),
                        ),
                      );
                    }),
                  ),

                  // Logo Centering is correct with the precise collageHeight
                  if (_logoFile != null)
                    Positioned(
                      left: logoLeftPosition, // Centered horizontally

                      top: logoTopPosition,
                      child: Image.file(
                        _logoFile!,
                        width: logoSize,
                        height: logoSize,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ElevatedButton(
            onPressed: _canShareCollage,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Share'),
          ),
        ),
      ],
    );
  }

  Widget _buildShoeTile(Shoe shoe, int index, double itemSize, int imageCount) {
    // Extracted tile content for cleaner code
    final isSold = shoe.status == 'Sold';
    return SizedBox(
      width: itemSize,
      height: itemSize,
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              color: Colors.grey[200],
              child: ShoeNetworkImage(
                imageUrl: shoe.remoteImageUrl,
                fit: BoxFit.cover,
                width: itemSize,
                height: itemSize,
                disableMemCache: true, // 🎯 High Quality for Collage Capture
              ),
            ),
          ),
          // 2. NEW: Shoe Size in Top Right Corner
          if (imageCount > 1 &&
              shoe.sizeEur != null &&
              shoe.sizeEur!.isNotEmpty)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black45, // Slightly more transparent than index
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  shoe.sizeEur![0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 6, // Smaller than the index
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (imageCount > 1)
            Positioned(
              left: 5,
              bottom: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (isSold)
            Align(
              alignment: Alignment.bottomCenter, // ✅ bottom center
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: 8,
                ), // move up a bit from bottom
                child: Transform.rotate(
                  angle: -0.3, // ~ -17 degrees, subtle slant
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54, // ✅ subtle background
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'SOLD',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16, // compact size
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _calculateItemSizeFromWidth(
    double availableWidth,
    int crossAxisCount,
  ) {
    const double spacing = 4.0;

    // Determine the maximum requested size based on the grid structure
    double requestedCap;
    if (crossAxisCount == 1) {
      requestedCap = 100.0;
    } else if (crossAxisCount == 2) {
      requestedCap = 90.0;
    } else if (crossAxisCount == 3) {
      requestedCap = 80.0;
    } else {
      // crossAxisCount == 4
      requestedCap = 70.0;
    }

    // Calculate the maximum possible item size that fits within the available width
    // MaxItemSize = (AvailableWidth - Total_Spacing) / crossAxisCount
    final double totalSpacing = (crossAxisCount - 1) * spacing;
    final double calculatedItemSize =
        (availableWidth - totalSpacing) / crossAxisCount;

    // Use the smaller of the two: the calculated size or your requested cap
    return min(calculatedItemSize, requestedCap);
  }

  void _canShareCollage() {
    if (_isSaving) {
      return;
    }

    var appStatusNotifier = context.read<AppStatusNotifier>();
    final sharesUsed = appStatusNotifier.dailyShares;
    final sharesLimit = appStatusNotifier.dailySharesLimit;
    bool isTest = appStatusNotifier.isTest;

    if (isTest || sharesUsed < sharesLimit) {
      _validateShareCollage();
      return;
    }

    // ⭐️ ADJUSTMENT: Use ValueListenableBuilder inside the dialog builder
    showDialog(
      context: context,
      builder: (context) {
        return ValueListenableBuilder<bool>(
          valueListenable: isAdLoading,
          builder: (context, isLoading, child) {
            final bool isAdReady = _rewardedAd != null && !isLoading;

            return ErrorDialog(
              title: 'Daily Share Limit Reached',
              message: isAdReady
                  ? 'Watch a short ad to share for free, or upgrade your plan.'
                  : 'The reward ad is loading. Please wait a moment or try the premium plan.',
              onYesPressed: isAdReady ? _showRewardedAd : null,
              onDismissed: () => {},
              // Keep isLoadingNotifier for external display (e.g., premium button state)
              isLoadingNotifier: isAdLoading,
            );
          },
        );
      },
    );
  }

  void loadRewardedAd() {
    final testAdUnit = dotenv.env['ADMOB_TEST_AD_UNIT'] ?? '';
    final releaseAdUnit = dotenv.env['ADMOB_RELEASE_AD_UNIT'] ?? '';

    isAdLoading.value = true;
    _rewardedAd?.dispose();
    _rewardedAd = null;

    RewardedAd.load(
      adUnitId: kReleaseMode ? releaseAdUnit : testAdUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          debugPrint('Ad was loaded.');
          _rewardedAd = ad;
          isAdLoading.value = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Ad failed to load with error: $error');
          _rewardedAd = null;
          isAdLoading.value = false;
        },
      ),
    );
  }

  void _showRewardedAd() {
    if (_rewardedAd == null) {
      AppLogger.log('Ad is null when trying to show.');
      return;
    }
    bool rewardGranted = false;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) => {},
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        if (mounted) Navigator.of(context).pop();
        if (rewardGranted) {
          _validateShareCollage(isRewarded: true);
        }

        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        AppLogger.log('$ad failed to show: $error');
        ad.dispose();
        loadRewardedAd();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not play the ad. Please try again.'),
          ),
        );
      },
    );
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) {
        AppLogger.log('Reward amount: ${rewardItem.amount}');
        rewardGranted = true;
      },
    );
  }

  Future<void> _validateShareCollage({bool isRewarded = false}) async {
    if (mounted) {
      setState(() => _isSaving = true);
    }
    bool isTest = context.read<AppStatusNotifier>().isTest;

    if (isRewarded || isTest) {
      _shareCollage();
      return;
    }

    try {
      final response = await widget.firebaseService.incrementShares(
        isTest: isTest,
      );

      if (response['status'] == 'success') {
        final sharesUsed = response['dailySharesUsed'];
        final sharesLimit = response['dailySharesLimit'];
        context.read<AppStatusNotifier>().updateDailyShares(sharesUsed);
        context.read<AppStatusNotifier>().updateDailySharesLimit(sharesLimit);

        _shareCollage();
      } else {
        showDialog(
          context: context,
          builder: (context) => ErrorDialog(
            title: 'Something went wrong. Please try again later.',
            message: response['message'],
            onDismissed: () => {},
          ),
        );
      }
    } catch (e) {
      debugPrint('Error incrementing shares or sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A network error occurred. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _shareCollage() async {
    // 🎯 TOGGLE: Change this to false to use the old RepaintBoundary method
    bool useCanvasMethod = context.read<AppStatusNotifier>().isHighResCollage;
    bool isInfoCopied = context.read<AppStatusNotifier>().isInfoCopied;

    setState(() => _isSaving = true);
    Uint8List pngBytes;

    try {
      if (useCanvasMethod) {
        // METHOD 2: Manual Canvas Generation (High Res)
        pngBytes = await CollageUtils.generateCollageWithCanvas(
          shoes: widget.shoes,
          logoFile: _logoFile,
        );
      } else {
        pngBytes = await CollageUtils.generateCollageFromWidget(_collageKey);
      }

      // --- Share Logic ---

      if (isInfoCopied) {
        Clipboard.setData(ClipboardData(text: widget.text));
      }
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/collage.png').create();
      await file.writeAsBytes(pngBytes);

      await SharePlus.instance.share(
        ShareParams(text: widget.text, files: [XFile(file.path)]),
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      AppLogger.log("Error generating collage: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
