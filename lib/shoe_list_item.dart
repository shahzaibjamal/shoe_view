import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/Helpers/condition_hint_styles.dart';
import 'package:shoe_view/Helpers/shoe_response.dart';
import 'package:shoe_view/Image/shoe_network_image.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:shoe_view/compact_action_button.dart';
import 'package:shoe_view/shoe_model.dart';



class ShoeListItem extends StatelessWidget {
  final Shoe shoe;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<Shoe> onCopyDataPressed;
  final ValueChanged<Shoe> onShareDataPressed;

  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelection;

  const ShoeListItem({
    super.key,
    required this.shoe,
    required this.onEdit,
    required this.onDelete,
    required this.onCopyDataPressed,
    required this.onShareDataPressed,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onLongPress,
    required this.onToggleSelection,
  });

  // Helper method to build the image widget (network or file)
  Widget _buildShoeImage(BuildContext context, String imagePath, String remoteImageUrl) {
    // Priority 1: Remote URL (from Firestore)
    if (remoteImageUrl.isNotEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Hero(
          tag: 'shoe_image_${shoe.shipmentId}_${shoe.itemId}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6.5),
            child: ShoeNetworkImage(
              imageUrl: remoteImageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              desiredWidth: 400, // Optimized for list view thumbnails
            ),
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
          color: Theme.of(context).dividerColor.withOpacity(0.5),
          width: 1.5,
        ),
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
      ),
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  // Full Screen Image View
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    final appStatus = context.read<AppStatusNotifier>();
    String code = appStatus.currencyCode;
    String currency = ShoeQueryUtils.getSymbolFromCode(code);
    final bool isMultiSizeModeEnabled = appStatus.isMultiSizeModeEnabled;
    final String eurSizes = ShoeQueryUtils.formatSizes(shoe.sizeEur);
    final String ukSizes = shoe.sizeUk?.isNotEmpty == true ? shoe.sizeUk!.first : '';

    final String sizeDisplay = isMultiSizeModeEnabled ? 'EUR: $eurSizes' : 'EUR: $eurSizes, UK: $ukSizes';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: _ShoeDetailDialogContent(
              shoe: shoe,
              imageUrl: imageUrl,
              maxHeight: MediaQuery.of(context).size.height,
              maxWidth: MediaQuery.of(context).size.width,
              currency: currency,
              sizeDisplay: sizeDisplay,
              isFlatSale: appStatus.isFlatSale,
              flatDiscount: appStatus.flatDiscount,
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

    return _ScaleOnTap(
      onTap: isSelectionMode
          ? () {
              HapticFeedback.selectionClick();
              onToggleSelection();
            }
          : () {
              _showFullScreenImage(context, shoe.remoteImageUrl);
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: _ConditionBadge(
          shoe: shoe,
          isEnabled: appStatus.showConditionGradients,
          hintStyle: appStatus.conditionHintStyle,
          child: Card(
            elevation: (appStatus.showConditionGradients && appStatus.conditionHintStyle == 'glow') ? 0 : 2,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
            children: [
                Material(
                  color: Colors.transparent,
                  child: _buildInkWell(context, appStatus, currency, sizeDisplay),
                ),
                if (_isPendingSync(context))
                  Positioned.fill(
                    child: Center(
                      child: _buildSyncingOverlay(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isPendingSync(BuildContext context) {
    final pendingIds = context.select<AppStatusNotifier, Set<String>>((n) => n.pendingSyncItemIds);
    // itemId + shipmentId is the unique combination
    return pendingIds.contains('${shoe.itemId}_${shoe.shipmentId}');
  }

  Color _getConditionColor(Shoe shoe) {
    final double condition = shoe.condition;
    // < 8: Very Subtle Blue
    if (condition < 8.0) return Colors.lightBlue[200]!;
    // 8.0 - 8.4: Subtle Brown
    if (condition < 8.5) return Colors.brown[300]!;
    // 8.5 - 8.9: Subtle Red
    if (condition < 9.0) return Colors.red[300]!;
    // 9.0 - 9.4: Subtle Purple
    if (condition < 9.5) return Colors.purple[200]!;
    
    // Fallback
    return Colors.amber[300]!;
  }

  Widget _buildSyncingOverlay(BuildContext context) {
    return Container(
      height: 76, // Approximate height of a list item
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color?.withOpacity(0.8) ?? (Theme.of(context).brightness == Brightness.dark ? Colors.black54 : Colors.white70),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Text(
            'Syncing changes...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInkWell(BuildContext context, AppStatusNotifier appStatus, String currency, String sizeDisplay) {
    // 🎯 Resolve the tap action based on usage
    final VoidCallback? onTapAction = isSelectionMode
        ? () {
             HapticFeedback.selectionClick();
             onToggleSelection();
           }
        : () {
             _showFullScreenImage(context, shoe.remoteImageUrl);
           };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTapAction, // 👈 KEY FIX: InkWell now handles the tap!
      onLongPress: () {
        HapticFeedback.heavyImpact();
        onLongPress();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => onToggleSelection(),
                  activeColor: Colors.indigo.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            // 🖼️ Square Shoe Image
            _buildShoeImage(
              context,
              shoe.localImagePath,
              shoe.remoteImageUrl,
            ),
            const SizedBox(width: 12),
            
            // 📝 Text Details (4 Lines)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shoe.shoeDetail,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 15,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (shoe.condition >= 10.0)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Icon(Icons.stars_rounded, size: 14, color: Colors.amber.shade700),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ID: ${shoe.itemId} | Ship: ${shoe.shipmentId}',
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    sizeDisplay,
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (appStatus.isTest && appStatus.categoryFixedPrices[shoe.status] != null)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.green.shade900.withOpacity(0.3)
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.green.shade700
                                  : Colors.green.shade200,
                            ),
                          ),
                            child: Text(
                            'FIXED PRICE',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.green.shade300
                                  : Colors.green.shade900,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$currency${appStatus.categoryFixedPrices[shoe.status]!.toStringAsFixed(0)}/-',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.green.shade300
                                : Theme.of(context).primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  else if (appStatus.isFlatSale && shoe.status != 'Sold' && (appStatus.applySaleToAllStatuses || shoe.status == 'Available'))
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            '-${appStatus.flatDiscount.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$currency${shoe.sellingPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$currency${ShoeQueryUtils.roundToNearestDouble(shoe.sellingPrice * (1 - appStatus.flatDiscount / 100)).toStringAsFixed(0)}/-',
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Price: $currency${shoe.sellingPrice.toStringAsFixed(0)}/-',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
            
            if (!isSelectionMode) ...[
              const SizedBox(width: 8),

              // ⚙️ Action Buttons (2x2 Compact Grid)
              Container(
                height: 40,
                child: VerticalDivider(
                    width: 1, thickness: 0.5, indent: 2, endIndent: 2, color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.7) : Colors.grey[200]),
              ),
              const SizedBox(width: 8),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CompactActionButton(
                        icon: Icons.content_copy_rounded,
                        tooltip: 'Copy',
                        showSuccessCheck: true, // Only Copy shows checkmark
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onCopyDataPressed(shoe);
                        },
                      ),
                      const SizedBox(width: 4),
                      CompactActionButton(
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
                      CompactActionButton(
                        icon: Icons.edit_rounded,
                        color: Colors.blueGrey,
                        tooltip: 'Edit',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onEdit();
                        },
                      ),
                      const SizedBox(width: 4),
                      CompactActionButton(
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
          ],
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
  final bool isFlatSale;
  final double flatDiscount;

  const _ShoeDetailDialogContent({
    required this.shoe,
    required this.imageUrl,
    required this.maxHeight,
    required this.maxWidth,
    required this.currency,
    required this.sizeDisplay,
    required this.isFlatSale,
    required this.flatDiscount,
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
    final appStatus = context.watch<AppStatusNotifier>();
    final bool isSaleEligible = (widget.isFlatSale && widget.shoe.status != 'Sold' && (appStatus.applySaleToAllStatuses || widget.shoe.status == 'Available'));

    return Dialog(
      backgroundColor: Colors.transparent, // Transparent to show blur
      insetPadding: EdgeInsets.zero, // FULL SCREEN
      child: Stack(
        fit: StackFit.expand, // Fill entire screen
        alignment: Alignment.center,
        children: [
          // 🌫️ Backdrop Blur (Glassmorphism)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0), // Strong Blur
            child: Container(
              color: Colors.black.withOpacity(0.6), // Dark semi-transparent tint
            ),
          ),
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
            onTap: () {}, // Stop propagation
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        constraints: BoxConstraints(
                           maxHeight: widget.maxHeight * 0.7, // Slightly taller
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[50], // Subtle background
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey[500]!,
                            width: 2, // Slightly thinner border
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: GestureDetector(
                            onDoubleTapDown: _handleDoubleTap,
                            onDoubleTap: () {},
                            onTap: () {
                              if (ModalRoute.of(context)?.isCurrent ?? false) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: InteractiveViewer(
                              transformationController: _transformationController,
                              minScale: 1.0,
                              maxScale: 4.0,
                              child: Hero(
                                tag: 'shoe_image_${widget.shoe.shipmentId}_${widget.shoe.itemId}',
                                child: ShoeNetworkImage(
                                  imageUrl: widget.imageUrl,
                                  width: null,
                                  height: null,
                                  fit: BoxFit.contain,
                                  desiredWidth: 1200, // High quality for full screen
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.shoe.shoeDetail,
                          style: const TextStyle(
                            fontSize: 22, // Larger
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Visible on dark
                            letterSpacing: 0.5,
                            shadows: [
                               Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Size: ${widget.sizeDisplay}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[300], // Lighter for dark theme
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      
                      // Sale & Policy UI Logic
                      if (appStatus.isTest && appStatus.categoryFixedPrices[widget.shoe.status] != null)
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                'FIXED PRICE POLICY',
                                style: TextStyle(
                                  color: Colors.green.shade900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${widget.currency}${appStatus.categoryFixedPrices[widget.shoe.status]!.toStringAsFixed(0)}/-',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        )
                      else if (isSaleEligible)
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange.shade200),
                                  ),
                                  child: Text(
                                    '-${widget.flatDiscount.toStringAsFixed(0)}% OFF',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${widget.currency}${widget.shoe.sellingPrice.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[400],
                                    decoration: TextDecoration.lineThrough,
                                    decorationThickness: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${widget.currency}${ShoeQueryUtils.roundToNearestDouble(widget.shoe.sellingPrice * (1 - widget.flatDiscount / 100)).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Colors.red.shade300,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'Price: ${widget.currency}${widget.shoe.sellingPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),

                // Corner Close Button for the Card
                Positioned(
                  top: -12,
                  right: -12,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
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

/// Wrapper to handle animations for the condition badge (Legendary status)
class _ConditionBadge extends StatefulWidget {
  final Widget child;
  final Shoe shoe;
  final bool isEnabled;
  final String hintStyle;

  const _ConditionBadge({
    super.key,
    required this.child,
    required this.shoe,
    required this.isEnabled,
    this.hintStyle = 'sash',
  });

  @override
  State<_ConditionBadge> createState() => _ConditionBadgeState();
}

class _ConditionBadgeState extends State<_ConditionBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 3 second cycle for the legendary rainbow effect
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    if (widget.shoe.condition >= 10.0 || widget.hintStyle == 'glow' || widget.hintStyle == 'sweep') {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ConditionBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate = widget.shoe.condition >= 10.0 || 
                         widget.hintStyle == 'glow' || 
                         widget.hintStyle == 'sweep';
    
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConditionHintStyles.wrap(
      child: widget.child,
      shoe: widget.shoe,
      style: widget.hintStyle,
      isEnabled: widget.isEnabled,
      animation: _controller,
    );
  }
}

/// A wrapper that scales down on tap for a lively feel
class _ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _ScaleOnTap({
    required this.child,
    this.onTap,
  });

  @override
  State<_ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<_ScaleOnTap> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset? _initialPosition;
  bool _isDragging = false;
  static const double _dragThreshold = 10.0; // Pixels before considering it a drag

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05, // Scales down to 0.95
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _initialPosition = event.position;
    _isDragging = false;
    _controller.forward();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isDragging || _initialPosition == null) return;

    final distance = (event.position - _initialPosition!).distance;
    if (distance > _dragThreshold) {
      // User is scrolling, not tapping - reset scale
      _isDragging = true;
      _controller.reverse();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _controller.reverse();
    _initialPosition = null;
    _isDragging = false;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _controller.reverse();
    _initialPosition = null;
    _isDragging = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.translucent,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 - _controller.value,
              child: widget.child,
            );
          },
        ),
      ),
    );
  }
}
