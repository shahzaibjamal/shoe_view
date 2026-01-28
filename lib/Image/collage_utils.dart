import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/Image/shoe_view_cache_manager.dart';
import 'package:shoe_view/shoe_model.dart';

class CollageLayout {
  final int cols;
  final int rows;
  final double tileSize;
  final double spacing;
  final double padding;
  final double width;
  final double height;

  CollageLayout({
    required this.cols,
    required this.rows,
    required this.tileSize,
    required this.spacing,
    required this.padding,
    required this.width,
    required this.height,
  });
}

class CollageUtils {
  /// 🎯 The Core Layout Engine
  /// This calculates exactly how to fit a number of items into a given width.
  static CollageLayout calculateBestLayout({
    required int itemCount,
    required double availableWidth,
  }) {
    // 1. Define base constants (Logical Pixels)
    const double minPadding = 8.0;
    const double minSpacing = 6.0;

    // 2. Decide the best number of columns based on item count
    int cols = 1;
    if (itemCount > 1) {
      if (itemCount <= 4) {
        cols = 2;
      } else if (itemCount <= 9) {
        cols = 3;
      } else {
        cols = 4;
      }
    }

    // 3. Calculate max available width for content
    final double maxContentWidth = availableWidth - (minPadding * 2);
    
    // 4. Calculate Tile Size
    // Formula: ContentWidth = (cols * tile) + ((cols - 1) * spacing)
    // => tile = (ContentWidth - (cols - 1) * spacing) / cols
    double tileSize = (maxContentWidth - (cols - 1) * minSpacing) / cols;

    // 5. Apply "Sweet Spot" Caps (Prevent images from being too massive)
    // We don't want a single 1x1 image to take 400px, it looks bad.
    double maxCap = 180.0;
    if (cols == 1) maxCap = 300.0;
    if (cols == 2) maxCap = 200.0;
    
    tileSize = min(tileSize, maxCap);

    // 6. Finalize Dimensions
    final int rows = (itemCount / cols).ceil();
    final double finalContentWidth = (cols * tileSize) + ((cols - 1) * minSpacing);
    final double finalContentHeight = (rows * tileSize) + (rows > 1 ? (rows - 1) * minSpacing : 0.0);

    return CollageLayout(
      cols: cols,
      rows: rows,
      tileSize: tileSize,
      spacing: minSpacing,
      padding: minPadding,
      width: finalContentWidth + (minPadding * 2),
      height: finalContentHeight + (minPadding * 2),
    );
  }

  static Future<ui.Image> getUiImageFromCache(String url) async {
    try {
      final cacheManager = ShoeViewCacheManager();
      final cacheKey = ShoeViewCacheManager.getStableKey(url);

      FileInfo? fileInfo = await cacheManager.getFileFromCache(cacheKey);
      
      File file;
      String processedUrl = url;
      if (url.contains('googleusercontent.com')) {
        processedUrl = url.replaceAll(RegExp(r'=w\d+'), '=w1200');
      }

      if (fileInfo != null && await fileInfo.file.exists()) {
        file = fileInfo.file;
      } else {
        file = await cacheManager
            .getSingleFile(processedUrl, key: cacheKey)
            .timeout(const Duration(seconds: 10));
      }

      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      AppLogger.log("Error loading image for collage: $e");
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(Colors.grey.shade200, BlendMode.src);
      final picture = recorder.endRecording();
      return picture.toImage(100, 100);
    }
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
          fontSize: 14 * scale,
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
    final double verticalShift = 15.0 * scale;
    canvas.save();
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
    const double scale = 10.0;
    
    // 🎯 Use the Logical Layout Engine but scale it up
    // We assume a standard width of 350 logical pixels for the "base" canvas
    final baseLayout = calculateBestLayout(
      itemCount: min(shoes.length, maxImages),
      availableWidth: 400.0, 
    );

    final double canvasWidth = baseLayout.width * scale;
    final double canvasHeight = baseLayout.height * scale;
    final double tileSize = baseLayout.tileSize * scale;
    final double spacing = baseLayout.spacing * scale;
    final double padding = baseLayout.padding * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
      Paint()..color = Colors.white,
    );

    final imagesToDisplay = shoes.take(maxImages).toList();
    final List<ui.Image> loadedImages = await Future.wait(
      imagesToDisplay.map((shoe) => getUiImageFromCache(shoe.remoteImageUrl)),
    );

    for (int i = 0; i < loadedImages.length; i++) {
      final shoe = imagesToDisplay[i];
      final img = loadedImages[i];
      final col = i % baseLayout.cols;
      final row = i ~/ baseLayout.cols;

      final x = padding + (col * (tileSize + spacing));
      final y = padding + (row * (tileSize + spacing));
      final rect = Rect.fromLTWH(x, y, tileSize, tileSize);
      
      paintCanvasImage(canvas, img, rect, radius: 6.0 * scale);
      
      if (loadedImages.length > 1 && shoe.sizeEur != null && shoe.sizeEur!.isNotEmpty) {
        paintCanvasSize(canvas, shoe.sizeEur![0], rect, scale: scale);
      }
      if (loadedImages.length > 1) {
        paintCanvasIndex(canvas, "${i + 1}", rect, scale: scale);
      }
      if (shoe.status == 'Sold') {
        paintCanvasSold(canvas, rect, scale: scale);
      }
    }

    if (logoFile != null) {
      final bool isOddSquareGrid = (baseLayout.cols == baseLayout.rows) && (baseLayout.cols % 2 != 0);
      final double logicalLogoSize = isOddSquareGrid ? 45.0 : 65.0;
      final double logoSize = logicalLogoSize * scale;

      double logoTopPosition = isOddSquareGrid 
          ? padding 
          : (canvasHeight - logoSize) / 2;
      final double logoLeftPosition = (canvasWidth - logoSize) / 2;

      final logoBytes = await logoFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(logoBytes);
      final logoImg = (await codec.getNextFrame()).image;

      canvas.drawImageRect(
        logoImg,
        Rect.fromLTWH(0, 0, logoImg.width.toDouble(), logoImg.height.toDouble()),
        Rect.fromLTWH(logoLeftPosition, logoTopPosition, logoSize, logoSize),
        Paint(),
      );
      logoImg.dispose();
    }

    final picture = recorder.endRecording();
    final finalImg = await picture.toImage(canvasWidth.toInt(), canvasHeight.toInt());

    for (var img in loadedImages) {
      img.dispose();
    }

    final byteData = await finalImg.toByteData(format: ui.ImageByteFormat.png);
    finalImg.dispose();

    return byteData!.buffer.asUint8List();
  }

  static void paintCanvasSize(
    Canvas canvas,
    String size,
    Rect tileRect, {
    required double scale,
  }) {
    if (size.isEmpty) return;

    final tp = TextPainter(
      text: TextSpan(
        text: size,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10 * scale,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = Rect.fromLTWH(
      tileRect.right - tp.width - (8 * scale),
      tileRect.top + (4 * scale),
      tp.width + (4 * scale),
      tp.height + (2 * scale),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, Radius.circular(3 * scale)),
      Paint()..color = Colors.black45,
    );

    tp.paint(
      canvas,
      Offset(bgRect.left + (2 * scale), bgRect.top + (1 * scale)),
    );
  }

  static int calculateGridSize(int count) {
    if (count <= 1) return 1;
    if (count <= 4) return 2;
    if (count <= 9) return 3;
    return 4;
  }

  static Future<Uint8List> generateCollageFromWidget(GlobalKey key) async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 7.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}