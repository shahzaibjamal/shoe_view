import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      
      final count = context.read<AppStatusNotifier>().dailyShares;
      AppLogger.log('daily count ${count}');
      if (context.read<AppStatusNotifier>().dailyShares >= 2) {
        showDialog(
          context: context,
          builder: (context) => ErrorDialog(
            title: 'Something went wrong. Please try again later.',
            message: 'Daily Share limit reached',
            onDismissed: () => {},
          ),
        );
      } else {
        _captureAndShareCollage();
      }
    }
  }

  int _calculateGridSize(int count) {
    if (count <= 1) return 1;
    if (count <= 4) return 2;
    if (count <= 9) return 3;
    return 4;
  }

  Future<void> _captureAndShareCollage() async {
    setState(() => _isSaving = true);

    try {
      final response = await widget.firebaseService.incrementShares();
      if (response['status'] == 'success') {
        final dailyShares = response['dailySharesUsed'];
        context.read<AppStatusNotifier>().updateDailyShares(dailyShares);
        final boundary =
            _collageKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
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
