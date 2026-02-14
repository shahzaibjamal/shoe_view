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

    return LayoutBuilder(
      builder: (context, constraints) {
        // 🎯 The New Layout Engine
        // Use the actual width provided by the parent (SingleChildScrollView/Dialog)
        final double availableWidth = constraints.maxWidth;
        
        final layout = CollageUtils.calculateBestLayout(
          itemCount: imageCount,
          availableWidth: availableWidth,
        );

        final bool isOddSquareGrid =
            (layout.cols == layout.rows) && (layout.cols % 2 != 0);
        final double logoSize = isOddSquareGrid ? 45.0 : 65.0;
        final double logoTopPosition = isOddSquareGrid 
            ? layout.padding 
            : (layout.height - logoSize) / 2;
        final double logoLeftPosition = (layout.width - logoSize) / 2;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ️ Collage Card (Moved to Top)
            Center(
              child: RepaintBoundary(
                key: _collageKey,
                child: Container(
                  width: layout.width,
                  height: layout.height,
                  padding: EdgeInsets.all(layout.padding),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white, // Keep white for export consistency
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(layout.rows, (rowIndex) {
                          final start = rowIndex * layout.cols;
                          final end = min(start + layout.cols, imageCount);
                          final rowImages = imagesToDisplay.sublist(start, end);

                          return Padding(
                            padding: EdgeInsets.only(
                              top: rowIndex == 0 ? 0.0 : layout.spacing,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(layout.cols, (colIndex) {
                                if (colIndex < rowImages.length) {
                                  final shoe = rowImages[colIndex];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      left: colIndex == 0 ? 0.0 : layout.spacing,
                                    ),
                                    child: _buildShoeTile(
                                      shoe,
                                      start + colIndex,
                                      layout.tileSize,
                                      imageCount,
                                    ),
                                  );
                                } else {
                                  // Spacer for empty grid cells
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      left: colIndex == 0 ? 0.0 : layout.spacing,
                                    ),
                                    child: SizedBox(
                                      width: layout.tileSize,
                                      height: layout.tileSize,
                                    ),
                                  );
                                }
                              }),
                            ),
                          );
                        }),
                      ),

                      if (_logoFile != null)
                        Positioned(
                          left: logoLeftPosition,
                          top: logoTopPosition,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Image.file(
                              _logoFile!,
                              width: logoSize,
                              height: logoSize,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 📝 Text Summary (Moved to Bottom)
            _buildTextPreview(),
            const SizedBox(height: 24),
            
            // 🚀 Action Button
            _buildShareButton(),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildTextPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 16,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              Text(
                'Text Summary',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: RichText(
                text: _parseStyledText(widget.text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _parseStyledText(String text) {
    final List<TextSpan> spans = [];
    // Look for text between single tildes ~ for strikethrough (matching share format)
    final RegExp exp = RegExp(r'(~.*?~)|([^~]+)', dotAll: true);
    final matches = exp.allMatches(text);

    for (final match in matches) {
      final String segment = match.group(0)!;
      if (segment.startsWith('~') && segment.endsWith('~') && segment.length > 2) {
        // Strikethrough segments
        spans.add(TextSpan(
          text: segment.substring(1, segment.length - 1),
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ));
      } else {
        // Normal text
        spans.add(TextSpan(text: segment));
      }
    }

    return TextSpan(
      style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color, height: 1.4),
      children: spans,
    );
  }

  Widget _buildShareButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: _canShareCollage,
        icon: _isSaving ? const SizedBox.shrink() : const Icon(Icons.share_outlined),
        label: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Generate & Share',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[200],
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
    double spacing,
    double internalPadding,
  ) {
    // 🎯 subtract the internal padding of the collage container itself
    final double actualContentWidth = availableWidth - (internalPadding * 2);

    // Determine the maximum requested size based on the grid structure
    double requestedCap;
    if (crossAxisCount == 1) {
      requestedCap = 300.0;
    } else if (crossAxisCount == 2) {
      requestedCap = 160.0;
    } else if (crossAxisCount == 3) {
      requestedCap = 120.0;
    } else {
      // crossAxisCount == 4
      requestedCap = 100.0;
    }

    // Calculate the maximum possible item size that fits within the available content width
    final double totalSpacing = (crossAxisCount - 1) * spacing;
    final double calculatedItemSize =
        (actualContentWidth - totalSpacing) / crossAxisCount;

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
