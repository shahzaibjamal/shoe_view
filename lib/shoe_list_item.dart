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

  const ShoeListItem({
    super.key,
    required this.shoe,
    required this.onEdit,
    required this.onDelete,
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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent, // Keep this transparent
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          // Wrap the entire content in a ClipRRect
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: ShoeNetworkImage(
              width: width,
              height: height,
              imageUrl: imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          vertical: 8.0,
          horizontal: 16.0,
        ),

        // Leading: Image or Placeholder (wrapped in GestureDetector)
        leading: GestureDetector(
          onTap: shoe.remoteImageUrl.isNotEmpty
              ? () => _showFullScreenImage(context, shoe.remoteImageUrl)
              : null,
          child: SizedBox(
            width: 60,
            height: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: _buildShoeImage(shoe.localImagePath, shoe.remoteImageUrl),
            ),
          ),
        ),

        // Title: Name and IDs
        title: Text(
          shoe.shoeDetail,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),

        // Subtitle: Details (IDs, Sizes, Price)
        subtitle: Text(
          'ID: ${shoe.itemId} | Shipment: ${shoe.shipmentId}\n'
          'EUR: ${shoe.sizeEur}, UK: ${shoe.sizeUk} | Price: Rs.${shoe.sellingPrice.toStringAsFixed(2)}',
          style: TextStyle(color: Colors.grey[600]),
        ),

        // Trailing: Edit and Delete buttons
        trailing: SizedBox(
          width: 150,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit Button
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueGrey),
                tooltip: 'Edit Shoe',
                onPressed: () => onEdit(shoe.localImagePath),
              ),
              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete Shoe',
                onPressed: onDelete,
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.black87),
                tooltip: 'Share Shoe',
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text:
                          'Name: ${shoe.shoeDetail}\n'
                          'Size: EUR ${shoe.sizeEur}, UK ${shoe.sizeUk}\n'
                          'Price: Rs.${shoe.sellingPrice.toStringAsFixed(2)}\n'
                          'Instagram: ${shoe.instagramLink}\n'
                          'TikTok: ${shoe.tiktokLink}\n',
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Details copied to clipboard! ${shoe.shoeDetail}.',
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
