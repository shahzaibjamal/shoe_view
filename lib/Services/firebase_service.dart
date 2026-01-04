import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart'; // Needed for debugPrint in non-Flutter environments
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shoe_view/Helpers/app_info.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import '../shoe_model.dart'; // Assuming this contains the Shoe class with itemId

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
    final url = Uri.parse(
      'https://script.google.com/macros/s/AKfycbwBgB963HyYAYmTdgURQwdj3yat23MerEc3FHbfiFL04DSv9_yMizJlYoDhl_HTk1xBAg/exec',
    );
    List<Shoe> shoes = [];
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        for (var item in data) {
          try {
            final shoe = Shoe.fromJson(item);
            //            if (shoe.status != 'Sold') {
            if (shoe.itemId > 0) shoes.add(shoe);
            //            }
          } catch (e) {
            debugPrint('Error mapping shoe: $e');
          }
        }

        // You can now use the data as a Map or List
      } else {
        print('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception: $e');
    }
    return shoes;
  }

  Future<dynamic> updateShoe(
    Shoe shoe,
    String? base64Image, {
    bool isTest = false,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('updateShoe');
      final result = await callable.call({
        'shoeData': shoe.toMap(),
        'imageBase64': base64Image,
        'isTest': isTest,
      });
      return result.data;
    } catch (error) {
      print('Error updating shoe: $error');
      return 'Error';
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
