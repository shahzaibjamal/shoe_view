import 'package:flutter/material.dart';
import 'package:shoe_view/Image/shoe_network_image.dart';
import 'package:shoe_view/shoe_model.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'dart:io';

class CollageBuilder extends StatefulWidget {
  final List<Shoe> shoes;
  final String text;

  const CollageBuilder({super.key, required this.shoes, required this.text});

  @override
  State<CollageBuilder> createState() => _CollageBuilderState();
}

class _CollageBuilderState extends State<CollageBuilder> {
  final _collageKey = GlobalKey();
  static const int _maxImages = 16;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    // Determine the number of images to display, up to _maxImages
    final imagesToDisplay = widget.shoes.take(_maxImages).toList();
    final imageCount = imagesToDisplay.length;

    // Determine grid layout based on number of images
    final int crossAxisCount = imageCount <= 4
        ? 2
        : imageCount <= 9
        ? 3
        : 4;

    return Column(
      mainAxisSize: MainAxisSize.min, // Make Column fit its children
      children: [
        RepaintBoundary(
          key: _collageKey,
          child: Container(
            color: Colors.white,
            child: Wrap(
              alignment: WrapAlignment.center,
              children: imagesToDisplay.asMap().entries.map((entry) {
                final index = entry.key;
                final shoe = entry.value;

                return Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      Container(
                        width:
                            MediaQuery.of(context).size.width / crossAxisCount -
                            8,
                        height:
                            MediaQuery.of(context).size.width / crossAxisCount -
                            8,
                        color: Colors.grey[200],
                        child: ShoeNetworkImage(
                          imageUrl: shoe.remoteImageUrl,
                          // Use BoxFit.fitWidth to fit the image horizontally
                          fit: BoxFit.fitHeight,
                        ),
                      ),
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
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isSaving ? null : _captureAndShareCollage,
          child: _isSaving
              ? const CircularProgressIndicator(strokeWidth: 2)
              : const Text('Share to WhatsApp'),
        ),
      ],
    );
  }

  Future<void> _captureAndShareCollage() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final boundary =
          _collageKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/collage.png').create();
      await file.writeAsBytes(pngBytes);

      // await Share.shareXFiles([XFile(file.path)], text: 'Check out my shoe collage!');
      await SharePlus.instance.share(
        ShareParams(text: widget.text, files: [XFile(file.path)]),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error capturing or sharing collage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share collage.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
