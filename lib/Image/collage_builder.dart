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
  final ValueNotifier<bool> isAdLoading = ValueNotifier(true);
  late RewardedAd _rewardedAd;

  @override
  void initState() {
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

  void _canShareCollage() {
    if (_isSaving) {
      return;
    } else {
      final sharesUsed = context.read<AppStatusNotifier>().dailyShares;
      final sharesLimit = context.read<AppStatusNotifier>().dailySharesLimit;
      AppLogger.log('daily count ${sharesUsed}');
      if (sharesUsed >= sharesLimit) {
        showDialog(
          context: context,
          builder: (context) => ErrorDialog(
            title: 'Daily Share limit reached',
            message: 'Would you like to share for free by watching an ad?',
            onDismissed: () => {},
            onYesPressed: showRewardedAd,
            isLoadingNotifier: isAdLoading,
          ),
        );
      } else {
        _validateShareCollage();
      }
    }
  }

  int _calculateGridSize(int count) {
    if (count <= 1) return 1;
    if (count <= 4) return 2;
    if (count <= 9) return 3;
    return 4;
  }

  void loadRewardedAd() {
    final testAdUnit = "ca-app-pub-3940256099942544/5224354917";
    final releaseAdUnit = "ca-app-pub-3489872370282662/3859555894";
    isAdLoading.value = true;
    RewardedAd.load(
      adUnitId:  kReleaseMode ? releaseAdUnit : testAdUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          // Called when an ad is successfully received.
          debugPrint('Ad was loaded.');
          // Keep a reference to the ad so you can show it later.
          _rewardedAd = ad;
          isAdLoading.value = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          // Called when an ad request failed.
          debugPrint('Ad failed to load with error: $error');
          isAdLoading.value = true;
        },
      ),
    );
  }

  void showRewardedAd() {
    if (isAdLoading.value) {
      showDialog(
        context: context,
        builder: (context) => ErrorDialog(
          title: 'Ad Not Ready',
          message: "Please wait a moment while we load your reward.",
          onDismissed: () => {},
        ),
      );
    } else {
      _rewardedAd?.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) {
          AppLogger.log('Reward amount: ${rewardItem.amount}');
          _validateShareCollage(isRewarded: true);
          // loadRewardedAd(); // ✅ Preload next ad
        },
      );
    }
  }

  Future<void> _validateShareCollage({bool isRewarded = false}) async {
    setState(() => _isSaving = true);
    if (isRewarded) {
      _shareCollage();
    } else {
      try {
        final response = await widget.firebaseService.incrementShares();
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
        debugPrint('Error capturing or sharing collage: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to share collage. Check permissions.'),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
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
