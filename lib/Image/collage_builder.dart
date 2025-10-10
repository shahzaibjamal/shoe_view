import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/Image/shoe_network_image.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:shoe_view/error_dialog.dart';
import 'package:shoe_view/firebase_service.dart';
import 'package:shoe_view/shoe_model.dart';

class CollageBuilder extends StatefulWidget {
  final List<Shoe> shoes;
  final String text;
  final FirebaseService firebaseService;

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
  static const int _maxImages = 16;
  bool _isSaving = false;
  // Use a nullable ad to manage its state clearly
  RewardedAd? _rewardedAd;
  final ValueNotifier<bool> isAdLoading = ValueNotifier(
    true,
  ); // Still useful for dialog state

  @override
  void initState() {
    // 🎯 Call load in initState as before
    loadRewardedAd();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final imagesToDisplay = widget.shoes.take(_maxImages).toList();
    final imageCount = imagesToDisplay.length;
    if (imageCount == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No shoes selected to build collage.'),
        ),
      );
    }

    final int crossAxisCount = _calculateGridSize(imageCount);
    final int rowCount = (imageCount / crossAxisCount).ceil();
    const double spacing = 4.0;
    const double itemSize = 100.0;

    final double collageWidth =
        (crossAxisCount * itemSize) + ((crossAxisCount - 1) * spacing);
    final double collageHeight =
        (rowCount * itemSize) + ((rowCount - 1) * spacing);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: RepaintBoundary(
            key: _collageKey,
            child: SizedBox(
              width: collageWidth,
              height: collageHeight,
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: 1.0,
                ),
                itemCount: imageCount,
                itemBuilder: (context, index) {
                  final shoe = imagesToDisplay[index];
                  return SizedBox(
                    width: itemSize,
                    height: itemSize,
                    child: Stack(
                      alignment: Alignment.bottomLeft,
                      children: [
                        Container(
                          color: Colors.grey[200],
                          child: ShoeNetworkImage(
                            imageUrl: shoe.remoteImageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (imagesToDisplay.length > 1)
                          Positioned(
                            left: 5,
                            bottom: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
                      ],
                    ),
                  );
                },
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
                : const Text('Share to WhatsApp'),
          ),
        ),
      ],
    );
  }

  // 🎯 NEW: Dispose the ad properly
  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  // 🎯 REVISED: Better UX flow for the share button logic
  void _canShareCollage() {
    if (_isSaving) {
      return; // Prevent multiple presses while saving/sharing
    }

    final sharesUsed = context.read<AppStatusNotifier>().dailyShares;
    final sharesLimit = context.read<AppStatusNotifier>().dailySharesLimit;

    // 1. Direct share if limit is not reached
    if (sharesUsed < sharesLimit) {
      _validateShareCollage();
      return;
    }

    // 2. Limit reached: show reward dialog
    showDialog(
      context: context,
      builder: (context) {
        // The dialog title and message depend on whether the ad is ready
        final bool isAdReady = _rewardedAd != null && !isAdLoading.value;

        return ErrorDialog(
          title: 'Daily Share Limit Reached',
          message: isAdReady
              ? 'Watch a short ad to share for free, or upgrade your plan.'
              : 'The reward ad is loading. Please wait a moment or try the premium plan.',
          // Only enable the reward button if the ad is ready
          onYesPressed: isAdReady ? _showRewardedAd : null,
          onDismissed: () => {/* Optional logging/cleanup */},
          // Pass the ValueNotifier to manage the "loading" state of the button itself
          isLoadingNotifier: isAdLoading,
        );
      },
    );
  }

  int _calculateGridSize(int count) {
    if (count <= 1) return 1;
    if (count <= 4) return 2;
    if (count <= 9) return 3;
    return 4;
  }

  // 🎯 REVISED: Load ad logic with proper ad management
  void loadRewardedAd() {
    const testAdUnit = "ca-app-pub-3940256099942544/5224354917";
    const releaseAdUnit = "ca-app-pub-3489872370282662/3859555894";

    // Set loading state true, and preload the next ad unit.
    isAdLoading.value = true;
    _rewardedAd?.dispose(); // Dispose any old ad instance
    _rewardedAd = null;

    // Optional: Start timeout fallback, but the isAdReady check is usually sufficient

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
          isAdLoading.value =
              false; // Set to false to indicate load attempt finished
        },
      ),
    );
  }

  // 🎯 REVISED: Simplified ad showing logic
  void _showRewardedAd() {
    // Dismiss the ErrorDialog first to clean up the UI
    if (mounted) Navigator.of(context).pop();

    if (_rewardedAd == null) {
      // This case should be rare if the dialog check is correct, but safe to handle.
      AppLogger.log('Ad is null when trying to show.');
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) =>
          AppLogger.log('$ad showed.'),
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        AppLogger.log('$ad dismissed.');
        ad.dispose(); // IMPORTANT: Dispose the ad after it's shown
        loadRewardedAd(); // Load the next ad immediately for good UX
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        AppLogger.log('$ad failed to show: $error');
        ad.dispose();
        loadRewardedAd();
        // Show user error message that the ad couldn't play
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
        _validateShareCollage(isRewarded: true);
      },
    );
  }

  // 🎯 REVISED: Move _isSaving state change to *before* image capture
  Future<void> _validateShareCollage({bool isRewarded = false}) async {
    bool isTest = context.read<AppStatusNotifier>().isTest;

    if (isRewarded || isTest) {
      // If reward or test, skip Firebase increment, go straight to image capture
      // 🎯 Set state to show saving indicator *before* image capture
      setState(() => _isSaving = true);
      // Image capture and Share will handle the rest
      _shareCollage();
      return;
    }

    // --- Standard Firebase Increment Path ---
    try {
      final response = await widget.firebaseService.incrementShares(
        isTest: isTest,
      );

      if (response['status'] == 'success') {
        // Update local notifier immediately (fast local operation)
        final sharesUsed = response['dailySharesUsed'];
        final sharesLimit = response['dailySharesLimit'];
        context.read<AppStatusNotifier>().updateDailyShares(sharesUsed);
        context.read<AppStatusNotifier>().updateDailySharesLimit(sharesLimit);

        // 🎯 Now that Firebase is done, start the slow UI part (image capture)
        setState(() => _isSaving = true);
        _shareCollage();
      } else {
        // Handle server/network error gracefully without setting _isSaving=true
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
      // Handle client-side errors
      debugPrint('Error incrementing shares or sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A network error occurred. Try again.')),
        );
      }
    } finally {
      // Ensure the button resets on success or error
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _shareCollage() async {
    final boundary =
        _collageKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final tempDir = await getTemporaryDirectory();
    final file = await File('${tempDir.path}/collage.png').create();
    await file.writeAsBytes(pngBytes);
    await SharePlus.instance.share(
      ShareParams(text: widget.text, files: [XFile(file.path)]),
    );
    if (mounted) Navigator.of(context).pop();
  }
}
