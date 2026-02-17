import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:provider/provider.dart';

class ShoeImagePicker extends StatelessWidget {
  final File? imageFile;
  final String remoteImageUrl;
  final bool isLoading;
  final void Function(File) onImagePicked;

  const ShoeImagePicker({
    super.key,
    required this.imageFile,
    required this.remoteImageUrl,
    required this.isLoading,
    required this.onImagePicked,
  });

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final isTest = context.read<AppStatusNotifier>().isTest;
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: isTest ? 500 : 300,
    );
    if (picked != null) {
      onImagePicked(File(picked.path));
    }
  }

  Widget _buildImagePreview(BuildContext context) {
    if (imageFile != null) {
      return Image.file(imageFile!, width: 90, height: 90, fit: BoxFit.cover);
    } else if (remoteImageUrl.isNotEmpty) {
      return Image.network(
        remoteImageUrl,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : const CircularProgressIndicator(),
      );
    } else {
      return const Icon(
        Icons.image_not_supported,
        size: 60,
        color: Colors.grey,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.photo_library),
          label: const Text('Pick Image'),
          onPressed: isLoading ? null : () => _pickImage(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.2) : Colors.grey[50],
            // backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.grey[50],
          ),
          ),
        const SizedBox(width: 26),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildImagePreview(context),
          ),
        ),
      ],
    );
  }
}
