import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shoe_view/Helpers/shoe_query_utils.dart';
import 'package:shoe_view/Image/shoe_network_image.dart';
import 'package:shoe_view/app_status_notifier.dart';

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
      return ShoeNetworkImage(
        imageUrl: remoteImageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
      );
    }
    // Fallback/Priority 2 can go here if needed
    return const SizedBox(
      width: 60,
      height: 60,
      child: Icon(Icons.image_not_supported),
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

    showDialog(
      context: context,
      barrierColor: const Color.fromARGB(200, 0, 0, 0),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent, // Keep this transparent
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🎯 Fix: Use ConstrainedBox to let image size itself naturally up to a limit.
              // We pass borderRadius to ShoeNetworkImage so it paints rounded corners 
              // immediately (even during fade-in/loading), solving the square-pop glitch.
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                  ),
                  child: ShoeNetworkImage(
                    imageUrl: imageUrl,
                    width: null,
                    height: null,
                    fit: BoxFit.contain,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.black54,
                child: Text(
                  textAlign: TextAlign.center,
                  '${shoe.shoeDetail}\nID: ${shoe.itemId} | #${shoe.shipmentId}\n$sizeDisplay \nPrice: $currency ${shoe.sellingPrice.toStringAsFixed(0)}/-',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Stack(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            leading: GestureDetector(
              onTap: shoe.remoteImageUrl.isNotEmpty
                  ? () => _showFullScreenImage(context, shoe.remoteImageUrl)
                  : null,
              child: SizedBox(
                width: 60,
                height: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: _buildShoeImage(
                    shoe.localImagePath,
                    shoe.remoteImageUrl,
                  ),
                ),
              ),
            ),
            title: Text(
              shoe.shoeDetail,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              'ID: ${shoe.itemId} | Shipment: ${shoe.shipmentId}\n'
              '$sizeDisplay \nPrice: $currency${shoe.sellingPrice.toStringAsFixed(0)}/-',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueGrey),
                        tooltip: 'Edit Shoe',
                        onPressed: onEdit,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete Shoe',
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.black87),
                        tooltip: 'Copy Shoe Data',
                        onPressed: () => onCopyDataPressed(shoe),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.share_rounded,
                          color: Colors.black87,
                        ),
                        tooltip: 'Share Shoe',
                        onPressed: () => onShareDataPressed(shoe),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
