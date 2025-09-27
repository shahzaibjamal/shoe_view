import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

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
    if (remoteImageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: remoteImageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
        errorWidget: (context, url, error) => const Icon(Icons.error, size: 40),
      );
    }
    // Priority 2: Local File Path (from ImagePicker, not yet uploaded)
    else if (imagePath.isNotEmpty) {
      try {
        return Image.file(
          File(imagePath),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        );
      } catch (e) {
        // Fallback if the path is invalid or file is missing
        return const Icon(Icons.broken_image, size: 40);
      }
    }
    // Fallback: No image available
    return const Icon(Icons.image_not_supported, size: 40, color: Colors.grey);
  }

  // Full Screen Image View
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error, size: 80, color: Colors.red),
                  )
                : const Icon(
                    Icons.image_not_supported,
                    size: 80,
                    color: Colors.grey,
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
          width: 120,
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
