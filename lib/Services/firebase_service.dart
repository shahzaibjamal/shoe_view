import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart'; // Needed for debugPrint in non-Flutter environments
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shoe_view/Helpers/app_info.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/shared/constants/app_constants.dart';
import 'package:shoe_view/Services/transaction_history_service.dart';
import '../shoe_model.dart';

/// A service class to handle all interactions with Firebase Firestore and Storage.
class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseService() {
    // Enable offline persistence for Firestore
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // Uses the currently authenticated user ID or a default for canvas testing.
  String get _userId {
    final uid = _auth.currentUser?.uid;
    // NOTE: In a real app, you would require the user to be signed in (uid != null)
    return uid ?? 'default_canvas_user';
  }

  // Method signature from your AuthScreen, moved here for centralization
  Future<Map<String, dynamic>> checkUserAuthorization({
    required String email,
    required String idToken,
    bool isTest = false,
  }) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('checkUserAuthorization')
        .call({'email': email, 'idToken': idToken, 'isTest': isTest});
    return result.data as Map<String, dynamic>;
  }

  /// Returns a real-time stream of Shoe lists for the current authenticated user.
  Stream<List<Shoe>> streamShoes() {
    // Reference to the user's private shoe collection
    final collectionRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('shoes');

    return collectionRef.snapshots().map((snapshot) {
      // Map each document snapshot to a Shoe object
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final shoe = Shoe.fromMap(data);

        final documentId = doc.id;

        // Note: We keep documentId populated just in case, but itemId is now the primary key.
        return shoe.copyWith(documentId: documentId);
      }).toList();
    });
  }

  Future<List<Shoe>> fetchData() async {
    final url = Uri.parse(dotenv.env['TEST_URI_DATA'] ?? '');
    
    if (url.toString().isEmpty) {
      throw Exception('Data URL not configured');
    }

    List<Shoe> shoes = [];
    try {
      final response = await http.get(url).timeout(
        AppConstants.networkTimeout,
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        for (var item in data) {
          try {
            final shoe = Shoe.fromJson(item as Map<String, dynamic>);
            if (shoe.itemId > 0) shoes.add(shoe);
          } catch (e) {
            AppLogger.log('Error mapping shoe: $e');
            // Continue processing other items
          }
        }
      } else {
        throw HttpException('Failed to fetch data: ${response.statusCode}');
      }
    } on TimeoutException {
      rethrow;
    } on HttpException {
      rethrow;
    } catch (e) {
      AppLogger.log('Unexpected error fetching data: $e');
      throw Exception('Failed to fetch shoe data: ${e.toString()}');
    }
    
    return shoes;
  }

  Future<dynamic> updateShoe(
    Shoe shoe,
    String? base64Image, {
    Shoe? oldShoe,
    bool isTest = false,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('updateShoe');
      final result = await callable.call({
        'shoeData': shoe.toMap(),
        'imageBase64': base64Image,
        'isTest': isTest,
      });

      // Calculate diff if updating
      Map<String, dynamic>? changes;
      if (oldShoe != null) {
        changes = oldShoe.diff(shoe);
      }

      // Log transaction
      TransactionHistoryService().log(
        action: shoe.documentId.isEmpty ? 'CREATE' : 'UPDATE',
        entityId: '${shoe.shipmentId}_${shoe.itemId}',
        entityName: shoe.shoeDetail,
        summary: shoe.documentId.isEmpty
            ? 'Added new shoe: ${shoe.shoeDetail}'
            : 'Updated shoe details for ${shoe.shoeDetail}',
        metadata: {
          'itemId': shoe.itemId,
          'shipmentId': shoe.shipmentId,
          if (changes != null) 'changes': changes,
        },
      );

      return result.data;
    } catch (error) {
      AppLogger.log('Error updating shoe: $error');
      return {'success': false, 'message': error.toString()};
    }
  }

  Future<dynamic> deleteShoe(Shoe shoe, {bool isTest = false}) async {
    final callable = FirebaseFunctions.instance.httpsCallable('deleteShoe');

    await callable
        .call({
          'documentId': shoe.documentId,
          'remoteImageUrl': shoe.remoteImageUrl,
          'isTest': isTest,
        })
        .then((value) {
          // Log transaction
          TransactionHistoryService().log(
            action: 'DELETE',
            entityId: '${shoe.shipmentId}_${shoe.itemId}',
            entityName: shoe.shoeDetail,
            summary: 'Deleted shoe: ${shoe.shoeDetail}',
            metadata: {'itemId': shoe.itemId, 'shipmentId': shoe.shipmentId},
          );
          // Handle success
          return value.data;
        })
        .catchError((error) {
          // Handle error
          return 'Error';
        });
    return 'Success';
  }

  Future<dynamic> deleteUserData() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'deleteUserData',
      );

      final result = await callable.call({});
      AppLogger.log(' result  ${result.data}');
      return result.data;
    } catch (error) {
      print('Error updating shoe: $error');
      return 'Error';
    }
  }

  Future<dynamic> verifyInAppPurchase({
    required String productId, // Pass the purchased product ID
    required String purchaseToken, // The serverVerificationData string
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'processInAppPurchase',
    );
    final packageName = await AppInfoUtility.getAppPackageName();
    final payload = {
      'serverReceipt': {
        'packageName': packageName,
        'productId': productId,
        'purchaseToken': purchaseToken,
      },
    };

    try {
      final result = await callable.call(payload);
      return result.data;
    } catch (error) {
      print('Error during purchase verification: $error');
      // Depending on your error handling, you might return 'Error' or rethrow
      return 'Error';
    }
  }

  Future<dynamic> incrementShares({bool isTest = false}) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'incrementUserShares',
      );

      final result = await callable.call({'isTest': isTest});
      AppLogger.log(' result  ${result.data}');
      return result.data;
    } catch (error) {
      print('Error updating shoe: $error');
      return 'Error';
    }
  }

  Future<dynamic> updateUserProfile(Map<String, dynamic> fieldsToUpdate) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'updateUserProfile',
      );

      final result = await callable.call({'updateData': fieldsToUpdate});
      AppLogger.log(' result  ${result.data}');
      return result.data;
    } catch (error) {
      print('Error updating shoe: $error');
      return 'Error';
    }
  }
}
