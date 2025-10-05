import 'package:flutter/foundation.dart';

@immutable
class Shoe {
  final String documentId; // Firestore document ID (not used as primary key)
  final int itemId;
  final String shipmentId;
  final String shoeDetail;
  final String sizeEur;
  final String sizeUk;
  final String status;
  final double sellingPrice;
  final String instagramLink;
  final String tiktokLink;
  final String localImagePath; // Path to local image file
  final String remoteImageUrl; // URL from Firebase Storage
  final bool isUploaded;
  final bool isConfirmed;

  const Shoe({
    required this.documentId,
    required this.itemId,
    required this.shipmentId,
    required this.shoeDetail,
    required this.sizeEur,
    required this.sizeUk,
    required this.sellingPrice,
    required this.instagramLink,
    required this.tiktokLink,
    required this.status,
    this.localImagePath = '',
    this.remoteImageUrl = '',
    this.isUploaded = false,
    this.isConfirmed = false,
  });

  // Factory constructor for creating a Shoe object from a Firestore map.
  factory Shoe.fromMap(Map<String, dynamic> map) {
    // Safely parse values with fallbacks
    final itemId = int.tryParse(map['ItemID']?.toString() ?? '') ?? 0;
    final documentId = map['DocumentID']?.toString() ?? '';
    final shipmentId = map['ShipmentID']?.toString() ?? '';
    final shoeDetail = map['ShoeDetail']?.toString() ?? '';
    final sizeEur = map['Size']?.toString() ?? '';
    final sizeUk = map['SizeUK']?.toString() ?? '';
    final sellingPrice =
        double.tryParse(map['SellingPrice']?.toString() ?? '') ?? 0.0;
    final remoteImageUrl = map['RemoteImageURL']?.toString() ?? '';
    final isUploaded = map['IsUploaded'] as bool? ?? false;
    final isConfirmed = map['IsConfirmed'] as bool? ?? false;
    final status = map['Status']?.toString() ?? '';
    final links = map['Links'] as List<dynamic>?;

    String instagram = '';
    String tiktok = '';
    // if (links != null && links.isNotEmpty) {
    //   final linkMap = links.first as Map<String, dynamic>?;
    //   if (linkMap != null) {
    //     instagram = linkMap['instagram']?.toString() ?? '';
    //     tiktok = linkMap['tiktok']?.toString() ?? '';
    //   }
    // }
    if (links != null) {
      for (var link in links) {
        final linkStr = link.toString();
        if (linkStr.contains('instagram.com')) {
          instagram = linkStr;
        } else if (linkStr.contains('tiktok.com')) {
          tiktok = linkStr;
        }
      }
    }

    return Shoe(
      documentId: documentId,
      itemId: itemId,
      shipmentId: shipmentId,
      shoeDetail: shoeDetail,
      sizeEur: sizeEur,
      sizeUk: sizeUk,
      sellingPrice: sellingPrice,
      instagramLink: instagram,
      tiktokLink: tiktok,
      remoteImageUrl: remoteImageUrl,
      isUploaded: isUploaded,
      isConfirmed: isConfirmed,
      status: status,
    );
  }

  // Converts the Shoe object to a Map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'DocumentID': documentId,
      'ItemID': itemId,
      'ShipmentID': shipmentId,
      'ShoeDetail': shoeDetail,
      'Size': sizeEur,
      'SizeUK': sizeUk,
      'SellingPrice': sellingPrice,
      'RemoteImageURL': remoteImageUrl,
      'Links': [
        {'instagram': instagramLink, 'tiktok': tiktokLink},
      ],
      'IsUploaded': isUploaded,
      'IsConfirmed': isConfirmed,
      'Status': status,
    };
  }

  // Creates an empty Shoe instance for new entries.
  const Shoe.empty()
    : documentId = '',
      itemId = 0,
      shipmentId = '',
      shoeDetail = '',
      sizeEur = '',
      sizeUk = '',
      sellingPrice = 0.0,
      instagramLink = '',
      tiktokLink = '',
      localImagePath = '',
      remoteImageUrl = '',
      status = '',
      isUploaded = false,
      isConfirmed = false;

  // Creates an updated copy of the object.
  Shoe copyWith({
    String? documentId,
    int? itemId,
    String? shipmentId,
    String? shoeDetail,
    String? sizeEur,
    String? sizeUk,
    double? sellingPrice,
    String? instagramLink,
    String? tiktokLink,
    String? localImagePath,
    String? remoteImageUrl,
    String? status,
    bool? isUploaded,
    bool? isConfirmed,
  }) {
    return Shoe(
      documentId: documentId ?? this.documentId,
      itemId: itemId ?? this.itemId,
      shipmentId: shipmentId ?? this.shipmentId,
      shoeDetail: shoeDetail ?? this.shoeDetail,
      sizeEur: sizeEur ?? this.sizeEur,
      sizeUk: sizeUk ?? this.sizeUk,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      instagramLink: instagramLink ?? this.instagramLink,
      tiktokLink: tiktokLink ?? this.tiktokLink,
      localImagePath: localImagePath ?? this.localImagePath,
      remoteImageUrl: remoteImageUrl ?? this.remoteImageUrl,
      isUploaded: isUploaded ?? this.isUploaded,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      status: status ?? this.status,
    );
  }

  factory Shoe.fromJson(Map<String, dynamic> map) {
    // Safely parse values with fallbacks
    final itemId = int.tryParse(map['Item ID']?.toString() ?? '') ?? 0;
    final shipmentId = map['Shipment ID']?.toString() ?? '';
    final shoeDetail = map['Shoe Detail']?.toString() ?? '';
    final sizeEur = map['Size']?.toString() ?? '';
    final sizeUk = map['Size UK']?.toString() ?? '';
    final status = map['Status']?.toString() ?? '';
    final sellingPrice =
        double.tryParse(map['Selling Price']?.toString() ?? '') ?? 0.0;
    String imageUrl = map['MediaThumbnail']?.toString() ?? '';

/******************************************************/
    final desiredWidth = 600;
    final uri = Uri.parse(imageUrl);
    final queryParameters = Map<String, String>.from(uri.queryParameters);
    queryParameters['sz'] = 'w$desiredWidth';
    final newUri = uri.replace(queryParameters: queryParameters);
    imageUrl = newUri.toString();
/******************************************************/
    final isUploaded = map['Uploaded'] as bool? ?? false;
    final isConfirmed = map['Video Created'] as bool? ?? false;
    final links = map['Links'] as List<dynamic>?;

    String instagram = '';
    String tiktok = '';

    if (links != null) {
      for (var link in links) {
        final linkStr = link.toString();
        if (linkStr.contains('instagram.com')) {
          instagram = linkStr;
        } else if (linkStr.contains('tiktok.com')) {
          tiktok = linkStr;
        }
      }
    }

    return Shoe(
      documentId:'',
      itemId: itemId,
      shipmentId: shipmentId,
      shoeDetail: shoeDetail,
      sizeEur: sizeEur,
      sizeUk: sizeUk,
      sellingPrice: sellingPrice,
      instagramLink: instagram,
      tiktokLink: tiktok,
      remoteImageUrl: imageUrl,
      isUploaded: isUploaded,
      isConfirmed: isConfirmed,
      status: status,
    );
  }

  String updateDriveImageUrl(String originalUrl, int desiredWidth) {
    try {
      // 1. Parse the original URL
      final uri = Uri.parse(originalUrl);

      // 2. Extract the existing query parameters as a mutable map
      final queryParameters = Map<String, String>.from(uri.queryParameters);

      // 3. Update the 'sz' parameter with the new width (e.g., 'w800')
      // We use 'w' prefix for width control.
      queryParameters['sz'] = 'w$desiredWidth';

      // 4. Reconstruct the new URL
      final newUri = uri.replace(queryParameters: queryParameters);

      return newUri.toString();
    } catch (e) {
      // Return the original URL on failure
      print('Error modifying image URL: $e');
      return originalUrl;
    }
  }
}
