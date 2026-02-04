import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum ShoeSortField { itemId, size, sellingPrice }

@immutable
class Shoe {
  final String documentId; // Firestore document ID (not used as primary key)
  final int itemId;
  final String shipmentId;
  final String shoeDetail;
  final List<String>? sizeEur;
  final List<String>? sizeUk;
  final List<String>? sizeCm;
  final String status;
  final double sellingPrice;
  final double condition;
  final int quantity;
  final String instagramLink;
  final String tiktokLink;
  final String localImagePath; // Path to local image file
  final String remoteImageUrl; // URL from Firebase Storage
  final bool isUploaded;
  final bool isConfirmed;
  final bool isSizeLinked;
  final String notes;
  final String imagesLink;
  final DateTime? lastEdit;
  final DateTime? soldOn;

  const Shoe({
    required this.documentId,
    required this.itemId,
    required this.shipmentId,
    required this.shoeDetail,
    required this.sizeEur,
    required this.sizeUk,
    required this.sizeCm,
    required this.sellingPrice,
    required this.condition,
    required this.quantity,
    required this.instagramLink,
    required this.tiktokLink,
    required this.imagesLink,
    required this.status,
    this.localImagePath = '',
    this.remoteImageUrl = '',
    this.isUploaded = false,
    this.isConfirmed = false,
    this.isSizeLinked = true,
    this.notes = '',
    this.lastEdit,
    this.soldOn,
  });

  // Factory constructor for creating a Shoe object from a Firestore map.
  factory Shoe.fromMap(Map<String, dynamic> map) {
    // Safely parse values with fallbacks
    final itemId = int.tryParse(map['ItemID']?.toString() ?? '') ?? 0;
    final documentId = map['DocumentID']?.toString() ?? '';
    final shipmentId = map['ShipmentID']?.toString() ?? '';
    final shoeDetail = map['ShoeDetail']?.toString() ?? '';
    final sizeEurRaw = map['Size'];
    final sizeUkRaw = map['SizeUK'];
    final sizeCmRaw = map['SizeCM'];

    final sizeEur = (sizeEurRaw is List)
        ? sizeEurRaw.map((e) => e.toString()).toList()
        : sizeEurRaw != null
        ? [sizeEurRaw.toString()]
        : <String>[];

    final sizeUk = (sizeUkRaw is List)
        ? sizeUkRaw.map((e) => e.toString()).toList()
        : sizeUkRaw != null
        ? [sizeUkRaw.toString()]
        : <String>[];

    final sizeCm = (sizeCmRaw is List)
        ? sizeCmRaw.map((e) => e.toString()).toList()
        : sizeCmRaw != null
        ? [sizeCmRaw.toString()]
        : <String>[];

    final sellingPrice =
        double.tryParse(map['SellingPrice']?.toString() ?? '') ?? 0.0;
    final condition =
        double.tryParse(map['Condition']?.toString() ?? '') ?? 0.0;
    final remoteImageUrl = map['RemoteImageURL']?.toString() ?? '';
    final isUploaded = map['IsUploaded'] as bool? ?? false;
    final isConfirmed = map['IsConfirmed'] as bool? ?? false;
    final isSizeLinked = map['IsSizeLinked'] as bool? ?? false;
    final status = map['Status']?.toString() ?? '';
    final links = map['Links'] as List<dynamic>?;
    final quantity = map['Quantity'] as int? ?? 1;
    final notes = map['Notes']?.toString() ?? '';
    final imagesLink = map['ImagesLink']?.toString() ?? '';
    final lastEditRaw = map['LastEdit'];
    final soldOnRaw = map['SoldOn'];

    DateTime? lastEdit;
    if (lastEditRaw is Timestamp) {
      lastEdit = lastEditRaw.toDate();
    } else if (lastEditRaw is String) {
      lastEdit = DateTime.tryParse(lastEditRaw);
    }

    DateTime? soldOn;
    if (soldOnRaw is Timestamp) {
      soldOn = soldOnRaw.toDate();
    } else if (soldOnRaw is String) {
      soldOn = DateTime.tryParse(soldOnRaw);
    }

    String instagram = '';
    String tiktok = '';
    if (links != null && links.isNotEmpty) {
      final linkMap = links.first as Map<String, dynamic>?;
      if (linkMap != null) {
        instagram = linkMap['instagram']?.toString() ?? '';
        tiktok = linkMap['tiktok']?.toString() ?? '';
      }
    }

    return Shoe(
      documentId: documentId,
      itemId: itemId,
      shipmentId: shipmentId,
      shoeDetail: shoeDetail,
      sizeEur: sizeEur,
      sizeUk: sizeUk,
      sizeCm: sizeCm,
      sellingPrice: sellingPrice,
      condition: condition,
      instagramLink: instagram,
      tiktokLink: tiktok,
      remoteImageUrl: remoteImageUrl,
      isUploaded: isUploaded,
      isConfirmed: isConfirmed,
      status: status,
      quantity: quantity,
      isSizeLinked: isSizeLinked,
      notes: notes,
      imagesLink: imagesLink,
      lastEdit: lastEdit,
      soldOn: soldOn,
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
      'SizeCM': sizeCm,
      'SellingPrice': sellingPrice,
      'Condition': condition,
      'RemoteImageURL': remoteImageUrl,
      'Links': [
        {'instagram': instagramLink, 'tiktok': tiktokLink},
      ],
      'IsUploaded': isUploaded,
      'IsConfirmed': isConfirmed,
      'Status': status,
      'Quantity': quantity,
      'IsSizeLinked': isSizeLinked,
      'Notes': notes,
      'ImagesLink': imagesLink,
      'LastEdit': lastEdit?.toIso8601String(),
      'SoldOn': soldOn?.toIso8601String(),
    };
  }

  // Creates an empty Shoe instance for new entries.
  const Shoe.empty()
    : documentId = '',
      itemId = 0,
      shipmentId = '',
      shoeDetail = '',
      sizeEur = const [],
      sizeUk = const [],
      sizeCm = const [],
      sellingPrice = 0.0,
      condition = 0.0,
      quantity = 0,
      instagramLink = '',
      tiktokLink = '',
      localImagePath = '',
      remoteImageUrl = '',
      status = '',
      isUploaded = false,
      isConfirmed = false,
      isSizeLinked = true,
      notes = '',
      imagesLink = '',
      lastEdit = null,
      soldOn = null;

  // Creates an updated copy of the object.
  Shoe copyWith({
    String? documentId,
    int? itemId,
    String? shipmentId,
    String? shoeDetail,
    List<String>? sizeEur,
    List<String>? sizeUk,
    List<String>? sizeCm,
    double? sellingPrice,
    double? condition,
    int? quantity,
    String? instagramLink,
    String? tiktokLink,
    String? localImagePath,
    String? remoteImageUrl,
    String? status,
    bool? isUploaded,
    bool? isConfirmed,
    bool? isSizeLinked,
    String? notes,
    String? imagesLink,
    DateTime? lastEdit,
    DateTime? soldOn,
  }) {
    return Shoe(
      documentId: documentId ?? this.documentId,
      itemId: itemId ?? this.itemId,
      shipmentId: shipmentId ?? this.shipmentId,
      shoeDetail: shoeDetail ?? this.shoeDetail,
      sizeEur: sizeEur ?? this.sizeEur,
      sizeUk: sizeUk ?? this.sizeUk,
      sizeCm: sizeCm ?? this.sizeCm,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      condition: condition ?? this.condition,
      quantity: quantity ?? this.quantity,
      instagramLink: instagramLink ?? this.instagramLink,
      tiktokLink: tiktokLink ?? this.tiktokLink,
      localImagePath: localImagePath ?? this.localImagePath,
      remoteImageUrl: remoteImageUrl ?? this.remoteImageUrl,
      isUploaded: isUploaded ?? this.isUploaded,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      isSizeLinked: isSizeLinked ?? this.isSizeLinked,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      imagesLink: imagesLink ?? this.imagesLink,
      lastEdit: lastEdit ?? this.lastEdit,
      soldOn: soldOn ?? this.soldOn,
    );
  }

  factory Shoe.fromJson(Map<String, dynamic> map) {
    // Safely parse values with fallbacks
    final itemId = int.tryParse(map['Item ID']?.toString() ?? '') ?? 0;
    final shipmentId = map['Shipment ID']?.toString() ?? '';
    final shoeDetail = map['Shoe Detail']?.toString() ?? '';
    String? eur = map['Size']?.toString().trim();
    String? uk = map['Size UK']?.toString().trim();
    String? cm = map['Size (cm)']?.toString().trim();

    final sizeEur = (eur != null && eur.isNotEmpty) ? [eur] : null;
    final sizeUk = (uk != null && uk.isNotEmpty) ? [uk] : null;
    final sizeCm = (cm != null && cm.isNotEmpty) ? [cm] : null;

    final status = map['Status']?.toString() ?? '';
    final sellingPrice =
        double.tryParse(map['Selling Price']?.toString() ?? '') ?? 0.0;
    final condition =
        double.tryParse(map['Condition']?.toString() ?? '') ?? 0.0;
    String imageUrl = map['MediaThumbnail']?.toString() ?? '';
    final notes = map['Notes']?.toString() ?? '';
    final imagesLink = map['Pics']?.toString() ?? '';
    /******************************************************/
    final desiredWidth = 1200;
    final uri = Uri.parse(imageUrl);
    final queryParameters = Map<String, String>.from(uri.queryParameters);
    queryParameters['sz'] = 'w$desiredWidth';
    final newUri = uri.replace(queryParameters: queryParameters);
    imageUrl = newUri.toString();

    /******************************************************/
    final isUploaded = map['Uploaded'] as bool? ?? false;
    final isConfirmed = map['Video Created'] as bool? ?? false;
    final isSizeLinked = map['IsSizeLinked'] as bool? ?? false;
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
      documentId: '',
      itemId: itemId,
      shipmentId: shipmentId,
      shoeDetail: shoeDetail,
      sizeEur: sizeEur,
      sizeUk: sizeUk,
      sizeCm: sizeCm,
      sellingPrice: sellingPrice,
      condition: condition,
      quantity: 1,
      instagramLink: instagram,
      tiktokLink: tiktok,
      remoteImageUrl: imageUrl,
      isUploaded: isUploaded,
      isConfirmed: isConfirmed,
      status: status,
      isSizeLinked: isSizeLinked,
      notes: notes,
      imagesLink: imagesLink,
      lastEdit: map['LastEdit'] != null ? DateTime.tryParse(map['LastEdit'].toString()) : null,
      soldOn: map['SoldOn'] != null ? DateTime.tryParse(map['SoldOn'].toString()) : null,
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

      // var newShoe = shoe.copyWith(
      //   itemId: shoe.itemId,
      //   shipmentId: shoe.shipmentId,
      //   shoeDetail: shoe.shoeDetail,
      //   sizeEur: shoe.sizeEur,
      //   sizeUk: shoe.sizeUk,
      //   condition: shoe.condition,
      //   imagesLink: shoe.imagesLink,
      //   documentId: shoe.documentId,
      //   instagramLink: shoe.instagramLink,
      //   tiktokLink: shoe.tiktokLink,
      //   isConfirmed: shoe.isConfirmed,
      //   isSizeLinked: shoe.isSizeLinked,
      //   isUploaded: shoe.isUploaded,
      //   localImagePath: shoe.localImagePath,
      //   notes: shoe.notes,
      //   quantity: shoe.quantity,
      //   remoteImageUrl: shoe.remoteImageUrl,
      //   sellingPrice: shoe.sellingPrice,
      //   status: shoe.status,
      // );

