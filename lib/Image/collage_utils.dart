import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/Image/shoe_view_cache_manager.dart';
import 'package:shoe_view/shoe_model.dart';

class CollageUtils {
  static Future<ui.Image> getUiImageFromCache(String url) async {
    final cacheManager = ShoeViewCacheManager();
    final fileInfo = await cacheManager.getFileFromCache(url);
    final file = fileInfo?.file ?? await cacheManager.getSingleFile(url);

    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static void paintCanvasImage(
    Canvas canvas,
    ui.Image image,
    Rect rect, {
    double radius = 30.0,
  }) {
    final paint = Paint()..isAntiAlias = true;
    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final FittedSizes sizes = applyBoxFit(BoxFit.cover, imageSize, rect.size);

    final Rect inputSubrect = Alignment.center.inscribe(
      sizes.source,
      Offset.zero & imageSize,
    );

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    canvas.drawImageRect(image, inputSubrect, rect, paint);
    canvas.restore();
  }

  static void paintCanvasIndex(
    Canvas canvas,
    String text,
    Rect tileRect, {
    required double scale,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14 * scale, // Scaled size
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = Rect.fromLTWH(
      tileRect.left + (5 * scale),
      tileRect.bottom - (20 * scale),
      tp.width + (8 * scale),
      tp.height + (2 * scale),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, Radius.circular(4 * scale)),
      Paint()..color = Colors.black54,
    );
    tp.paint(
      canvas,
      Offset(tileRect.left + (9 * scale), tileRect.bottom - (19 * scale)),
    );
  }

  static void paintCanvasSold(
    Canvas canvas,
    Rect tileRect, {
    required double scale,
  }) {
    // Fine-tune this value: higher number moves it further UP
    final double verticalShift = 15.0 * scale;
    canvas.save();
    // Matches your UI: Bottom Center with a small offset up
    canvas.translate(tileRect.center.dx, tileRect.bottom - verticalShift);
    canvas.rotate(-0.3);

    final tp = TextPainter(
      text: TextSpan(
        text: 'SOLD',
        style: TextStyle(
          color: Colors.red,
          fontSize: 16 * scale,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5 * scale,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bg = Rect.fromCenter(
      center: Offset.zero,
      width: tp.width + (8 * scale),
      height: tp.height + (4 * scale),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, Radius.circular(3 * scale)),
      Paint()..color = Colors.black54,
    );

    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  static Future<Uint8List> generateCollageWithCanvas({
    required List<Shoe> shoes,
    required File? logoFile,
    int maxImages = 16,
  }) async {
    // 1. Setup Scaling (Scale UI logical pixels to high-res canvas pixels)
    const double scale = 10.0;
    const double spacing = 4.0 * scale;
    const double internalPadding = 4.0 * scale;

    final imagesToDisplay = shoes.take(maxImages).toList();
    final int imageCount = imagesToDisplay.length;
    final int cols = calculateGridSize(imageCount);
    final int rows = (imageCount / cols).ceil();

    // 2. Calculate dynamic item size based on your UI caps (80-100 logical px)
    double logicalCap;
    if (cols == 1)
      logicalCap = 100.0;
    else if (cols == 2)
      logicalCap = 90.0;
    else if (cols == 3)
      logicalCap = 80.0;
    else
      logicalCap = 70.0;

    final double tileSize = logicalCap * scale;

    // 3. Calculate Dynamic Canvas Dimensions (Ported from UI logic)
    final double contentWidth = (cols * tileSize) + ((cols - 1) * spacing);
    final double contentHeight =
        (rows * tileSize) + (rows > 1 ? (rows - 1) * spacing : 0.0);

    final double canvasWidth = contentWidth + (internalPadding * 2);
    final double canvasHeight = contentHeight + (internalPadding * 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // White Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
      Paint()..color = Colors.white,
    );

    // 4. Load Images in parallel
    final List<ui.Image> loadedImages = await Future.wait(
      imagesToDisplay.map((shoe) => getUiImageFromCache(shoe.remoteImageUrl)),
    );

    // 5. Draw Grid
    for (int i = 0; i < loadedImages.length; i++) {
      final shoe = imagesToDisplay[i];
      final img = loadedImages[i];
      final col = i % cols;
      final row = i ~/ cols;

      final x = internalPadding + (col * (tileSize + spacing));
      final y = internalPadding + (row * (tileSize + spacing));
      final rect = Rect.fromLTWH(x, y, tileSize, tileSize);

      paintCanvasImage(canvas, img, rect, radius: 6.0 * scale);
      if (imageCount > 1) {
        paintCanvasIndex(canvas, "${i + 1}", rect, scale: scale);
      }
      if (shoe.status == 'Sold') {
        paintCanvasSold(canvas, rect, scale: scale);
      }
    }

    // 6. Draw Logo (Matching Odd vs Even Square logic)
    if (logoFile != null) {
      final bool isOddSquareGrid = (cols == rows) && (cols % 2 != 0);
      final double logicalLogoSize = isOddSquareGrid ? 40.0 : 60.0;
      final double logoSize = logicalLogoSize * scale;

      double logoTopPosition;
      if (isOddSquareGrid) {
        logoTopPosition = internalPadding;
      } else {
        logoTopPosition = (canvasHeight - logoSize) / 2;
      }
      final double logoLeftPosition = (canvasWidth - logoSize) / 2;

      final logoBytes = await logoFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(logoBytes);
      final logoImg = (await codec.getNextFrame()).image;

      canvas.drawImageRect(
        logoImg,
        Rect.fromLTWH(
          0,
          0,
          logoImg.width.toDouble(),
          logoImg.height.toDouble(),
        ),
        Rect.fromLTWH(logoLeftPosition, logoTopPosition, logoSize, logoSize),
        Paint(),
      );
      logoImg.dispose();
    }

    // 7. Finalize
    final picture = recorder.endRecording();
    final finalImg = await picture.toImage(
      canvasWidth.toInt(),
      canvasHeight.toInt(),
    );

    for (var img in loadedImages) {
      img.dispose();
    }

    final byteData = await finalImg.toByteData(format: ui.ImageByteFormat.png);
    finalImg.dispose();

    AppLogger.log(
      'Canvas generated - Width: ${finalImg.width} height: ${finalImg.height}',
    );

    return byteData!.buffer.asUint8List();
  }

  static int calculateGridSize(int count) {
    if (count <= 1) return 1;
    int bestCols = 1;
    double bestScore = double.infinity;
    for (int cols = 1; cols <= 4; cols++) {
      int rows = (count / cols).ceil();
      if (rows > 4) continue;
      double score = (cols - rows).abs() + ((cols * rows) - count) * 0.1;
      if (score < bestScore) {
        bestScore = score;
        bestCols = cols;
      }
    }
    return bestCols;
  }

  static Future<Uint8List> generateCollageFromWidget(GlobalKey key) async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 4.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    AppLogger.log(
      'Repaint generated - Width: ${image.width} height: ${image.height}',
    );
    return byteData!.buffer.asUint8List();
  }
}
