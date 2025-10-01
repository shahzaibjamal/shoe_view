import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:shoe_view/Image/shoe_network_image.dart';

import 'shoe_model.dart';

class ShoeListItem extends StatelessWidget {
  final Shoe shoe;
  final Function(String originalLocalPath) onEdit;
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
    return CachedNetworkImage(
      imageUrl: remoteImageUrl,
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
      errorWidget: (context, url, error) => const Icon(Icons.error, size: 40),
    );
    // Priority 2: Local File Path (from ImagePicker, not yet uploaded)
  }

  // Full Screen Image View
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    final height = MediaQuery.of(context).size.height * 0.75;
    final width = MediaQuery.of(context).size.width * 0.75;
    showDialog(
      context: context,
      barrierColor: const Color.fromARGB(200, 0, 0, 0),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent, // Keep this transparent
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          // Wrap the entire content in a ClipRRect
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: ShoeNetworkImage(
                  width: width,
                  height: height,
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
              Text(
                textAlign: TextAlign.center,
                '${shoe.shoeDetail}\nID: ${shoe.itemId} | #${shoe.shipmentId}\nEUR: ${shoe.sizeEur}, UK: ${shoe.sizeUk} \nPrice: Rs.${shoe.sellingPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
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
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Stack(
        children: [
          // The main content of the card
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
              'EUR: ${shoe.sizeEur}, UK: ${shoe.sizeUk} \nPrice: Rs.${shoe.sellingPrice.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),

          // Position the buttons in the top-right corner
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
                        onPressed: () => onEdit(shoe.localImagePath),
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
                        onPressed: () {
                          onCopyDataPressed(shoe);
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.share_rounded,
                          color: Colors.black87,
                        ),
                        tooltip: 'Share Shoe',
                        onPressed: () {
                          onShareDataPressed(shoe);
                        },
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
