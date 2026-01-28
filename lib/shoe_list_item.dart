import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/Image/shoe_network_image.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'shoe_model.dart';



class ShoeListItem extends StatelessWidget {
  final Shoe shoe;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<Shoe> onCopyDataPressed;
  final ValueChanged<Shoe> onShareDataPressed;

  const ShoeListItem({
    super.key,
    required this.shoe,
    required this.onEdit,
    required this.onDelete,
    required this.onCopyDataPressed,
    required this.onShareDataPressed,
  });

  // Helper method to build the image widget (network or file)
  Widget _buildShoeImage(String imagePath, String remoteImageUrl) {
    // Priority 1: Remote URL (from Firestore)
    if (remoteImageUrl.isNotEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[400]!,
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6.5),
          child: ShoeNetworkImage(
            imageUrl: remoteImageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    // Fallback/Priority 2 can go here if needed
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[400]!,
          width: 1.5,
        ),
        color: Colors.grey[100],
      ),
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  // Full Screen Image View
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    final double maxHeight = MediaQuery.of(context).size.height * 0.70;
    final double maxWidth = MediaQuery.of(context).size.width * 0.90;

    final appStatus = context.read<AppStatusNotifier>();
    String code = appStatus.currencyCode;
    String currency = ShoeQueryUtils.getSymbolFromCode(code);
    final bool isMultiSizeModeEnabled = appStatus.isMultiSizeModeEnabled;

    final String eurSizes = ShoeQueryUtils.formatSizes(shoe.sizeEur);
    final String ukSizes =
        shoe.sizeUk?.isNotEmpty == true ? shoe.sizeUk!.first : '';

    final String sizeDisplay = isMultiSizeModeEnabled
        ? 'EUR: $eurSizes'
        : 'EUR: $eurSizes, UK: $ukSizes';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            ),
            child: _ShoeDetailDialogContent(
              shoe: shoe,
              imageUrl: imageUrl,
              maxHeight: maxHeight,
              maxWidth: maxWidth,
              currency: currency,
              sizeDisplay: sizeDisplay,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🎯 USE SELECT/WATCH: This ensures the list item rebuilds if currency/mode changes
    final appStatus = context.watch<AppStatusNotifier>();
    
    String code = appStatus.currencyCode;
    String currency = ShoeQueryUtils.getSymbolFromCode(code);
    final bool isMultiSizeModeEnabled = appStatus.isMultiSizeModeEnabled;
    
    final String eurSizes = ShoeQueryUtils.formatSizes(shoe.sizeEur);
    final String ukSizes = shoe.sizeUk?.isNotEmpty == true ? shoe.sizeUk!.first : '-';

    final String sizeDisplay;
    if (isMultiSizeModeEnabled) {
      sizeDisplay = 'EUR: $eurSizes';
    } else {
      sizeDisplay = 'EUR: $eurSizes, UK: $ukSizes';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            _showFullScreenImage(context, shoe.remoteImageUrl);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 🖼️ Square Shoe Image
                Container(
                  width: 60,
                  height: 60,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!, width: 1.5),
                  ),
                  child: _buildShoeImage(
                    shoe.localImagePath,
                    shoe.remoteImageUrl,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 📝 Text Details (4 Lines)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shoe.shoeDetail,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 15,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'ID: ${shoe.itemId} | Ship: ${shoe.shipmentId}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        sizeDisplay,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Price: $currency${shoe.sellingPrice.toStringAsFixed(0)}/-',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),

                // ⚙️ Action Buttons (2x2 Compact Grid)
                Container(
                  height: 40,
                  child: const VerticalDivider(width: 1, thickness: 0.5, indent: 2, endIndent: 2),
                ),
                const SizedBox(width: 8),
                
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CompactActionButton(
                          icon: Icons.content_copy_rounded,
                          tooltip: 'Copy',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            onCopyDataPressed(shoe);
                          },
                        ),
                        const SizedBox(width: 4),
                        _CompactActionButton(
                          icon: Icons.share_rounded,
                          tooltip: 'Share',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            onShareDataPressed(shoe);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CompactActionButton(
                          icon: Icons.edit_rounded,
                          color: Colors.blueGrey,
                          tooltip: 'Edit',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            onEdit();
                          },
                        ),
                        const SizedBox(width: 4),
                        _CompactActionButton(
                          icon: Icons.delete_outline_rounded,
                          color: Colors.red[400],
                          tooltip: 'Delete',
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            onDelete();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShoeDetailDialogContent extends StatefulWidget {
  final Shoe shoe;
  final String imageUrl;
  final double maxHeight;
  final double maxWidth;
  final String currency;
  final String sizeDisplay;

  const _ShoeDetailDialogContent({
    required this.shoe,
    required this.imageUrl,
    required this.maxHeight,
    required this.maxWidth,
    required this.currency,
    required this.sizeDisplay,
  });

  @override
  State<_ShoeDetailDialogContent> createState() =>
      _ShoeDetailDialogContentState();
}

class _ShoeDetailDialogContentState extends State<_ShoeDetailDialogContent>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    Matrix4 endMatrix;
    if (_transformationController.value != Matrix4.identity()) {
      endMatrix = Matrix4.identity();
    } else {
      final position = details.localPosition;
      const double scale = 3.0;
      final x = -position.dx * (scale - 1);
      final y = -position.dy * (scale - 1);
      endMatrix = Matrix4.identity()
        ..translate(x, y)
        ..scale(scale);
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutExpo,
    ));

    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Transparent barrier to close on tap outside card
          GestureDetector(
            onTap: () {
              if (ModalRoute.of(context)?.isCurrent ?? false) {
                Navigator.of(context).pop();
              }
            },
            child: Container(color: Colors.transparent),
          ),

          // The Shoe Card
          GestureDetector(
            onTap: () {}, // Prevent card taps from closing
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: widget.maxWidth,
                      maxHeight: widget.maxHeight,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 4,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: GestureDetector(
                        onDoubleTapDown: _handleDoubleTap,
                        onDoubleTap: () {},
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: ShoeNetworkImage(
                            imageUrl: widget.imageUrl,
                            width: null,
                            height: null,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.shoe.shoeDetail,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Size: ${widget.sizeDisplay}',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Price: ${widget.currency}${widget.shoe.sellingPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Close Button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A highly compact action button designed for 2x2 grids
class _CompactActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color? color;

  const _CompactActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: color ?? Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}
