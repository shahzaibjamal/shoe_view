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
    // 🎯 Logic: "Take up a lot of screenspace".
    // We use safe constraints (e.g., 70% height, 90% width)
    // and let the image determine its own aspect ratio within that box.
    final double maxHeight = MediaQuery.of(context).size.height * 0.70;
    final double maxWidth = MediaQuery.of(context).size.width * 0.90;

    // Use read here as it's a callback, not reactive build
    final appStatus = context.read<AppStatusNotifier>();
    String code = appStatus.currencyCode;
    String currency = ShoeQueryUtils.getSymbolFromCode(code);
    final bool isMultiSizeModeEnabled = appStatus.isMultiSizeModeEnabled;
    // Get the formatted strings
    final String eurSizes = ShoeQueryUtils.formatSizes(shoe.sizeEur);
    final String ukSizes = shoe.sizeUk?.isNotEmpty == true ? shoe.sizeUk!.first : '';

    final String sizeDisplay;
    if (isMultiSizeModeEnabled) {
      // If multi-size is ON, only display EUR sizes
      sizeDisplay = 'EUR: $eurSizes';
    } else {
      // If multi-size is OFF (single-size), display both EUR and UK
      sizeDisplay = 'EUR: $eurSizes, UK: $ukSizes';
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
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
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Image with border
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: maxWidth,
                                maxHeight: maxHeight,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: ShoeNetworkImage(
                                  imageUrl: imageUrl,
                                  width: null,
                                  height: null,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Info section
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  Text(
                                    shoe.shoeDetail,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Size: $sizeDisplay',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Price: $currency${shoe.sellingPrice.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ),
                  // Close button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
        child: ListTile(
          isThreeLine: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10.0,
            horizontal: 12.0,
          ),
          leading: Container(
            width: 60,
            height: 60,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: _buildShoeImage(
              shoe.localImagePath,
              shoe.remoteImageUrl,
            ),
          ),
          title: Text(
            shoe.shoeDetail,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ID: ${shoe.itemId} | Shipment: ${shoe.shipmentId}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              Text(
                sizeDisplay,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              Text(
                'Price: $currency${shoe.sellingPrice.toStringAsFixed(0)}/-',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
trailing: SizedBox(
  width: 120, // give enough width for 4 icons
  child: Wrap(
    spacing: 8,        // horizontal spacing between icons
    runSpacing: 4,     // vertical spacing if wrapping occurs
    alignment: WrapAlignment.center,
    children: [
      IconButton(
        icon: const Icon(Icons.content_copy_rounded, size: 22),
        onPressed: () {
          HapticFeedback.lightImpact();
          onCopyDataPressed(shoe);
        },
        tooltip: 'Copy',
      ),
      IconButton(
        icon: const Icon(Icons.share_rounded, size: 22),
        onPressed: () {
          HapticFeedback.lightImpact();
          onShareDataPressed(shoe);
        },
        tooltip: 'Share',
      ),
      IconButton(
        icon: const Icon(Icons.edit_rounded, size: 22, color: Colors.blueGrey),
        onPressed: () {
          HapticFeedback.lightImpact();
          onEdit();
        },
        tooltip: 'Edit',
      ),
      IconButton(
        icon: Icon(Icons.delete_outline_rounded, size: 22, color: Colors.red[400]),
        onPressed: () {
          HapticFeedback.mediumImpact();
          onDelete();
        },
        tooltip: 'Delete',
      ),
    ],
  ),
),
        ),
        ),
      ),
    );
  }
}
