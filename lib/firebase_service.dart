import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart'; // Needed for debugPrint in non-Flutter environments
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'shoe_model.dart'; // Assuming this contains the Shoe class with itemId

/// A service class to handle all interactions with Firebase Firestore and Storage.
class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Uses the currently authenticated user ID or a default for canvas testing.
  String get _userId {
    final uid = _auth.currentUser?.uid;
    // NOTE: In a real app, you would require the user to be signed in (uid != null)
    return uid ?? 'default_canvas_user';
  }

  // --- Read/Stream Operations ---

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
            if (shoe.status != 'Sold' && shoe.isUploaded && shoe.isConfirmed) {
              shoes.add(shoe);
            }
          } catch (e) {
            debugPrint('Error mapping shoe: $e');
          }
        }
        print('Received: $data');
        // You can now use the data as a Map or List
      } else {
        print('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception: $e');
    }
    return shoes;
  }

  // --- Image Upload ---

  /// Uploads the given [file] to Firebase Storage.
  Future<String?> uploadImage(File file, String documentId) async {
    try {
      // Create a unique path using user ID, shoe ID, and a timestamp for uniqueness
      final uploadPath =
          'shoes/$_userId/${documentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage.ref().child(uploadPath);
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      final uploadTask = storageRef.putFile(file, metadata);
      final snapshot = await uploadTask.whenComplete(() {});

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image to storage: $e');
      return null;
    }
  }

  // --- Create/Update Operations ---

  /// Saves or updates the shoe data in Firestore and uploads a new image if provided.
  /// This function now uses the **shoe.itemId** as the Firestore document ID.
  Future<void> saveShoe(Shoe shoe, {File? localImageFile}) async {
    // 1. Validate the primary key
    if (shoe.documentId.isEmpty) {
      debugPrint('Error: Cannot save shoe with invalid Document ID.');
      return;
    }

    String remoteUrl = shoe.remoteImageUrl;

    // 2. Image Upload (if a new local file is provided)
    if (localImageFile != null) {
      final uploadedUrl = await uploadImage(localImageFile, shoe.documentId);
      if (uploadedUrl != null) {
        remoteUrl = uploadedUrl;
      }
    }

    // 3. Prepare data for Firestore
    final dataToSave = shoe
        .copyWith(
          remoteImageUrl: remoteUrl,
          localImagePath: '', // Clear local path after (or attempt at) upload
        )
        .toMap();

    // 4. Determine the document reference using the **documentId**
    final docId = shoe.documentId.toString();
    final docRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('shoes')
        .doc(docId); // Document ID is now based on documentId

    // 5. Use Set with merge: true to handle both creation and update (upsert)
    // This simplifies the logic by removing the need for an existence check.
    await docRef.set(dataToSave, SetOptions(merge: true));
    debugPrint(
      'Shoe data saved successfully for Document ID: ${shoe.documentId} (Doc ID: $docId)',
    );
  }

  // --- Delete Operation ---

  /// Deletes the image from Cloud Storage and the document from Firestore.
  /// Now uses the **shoe.documentId** for the document reference.
  Future<void> deleteShoe(Shoe shoe) async {
    if (shoe.documentId.isEmpty) {
      debugPrint('Error: Cannot delete shoe without a valid Document ID.');
      return;
    }

    final docId = shoe.documentId;

    // 1. Delete Firestore document
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('shoes')
        .doc(docId) // Document ID is based on documentId
        .delete();

    // 2. Delete storage image (only if a remote URL exists)
    if (_isNetworkImage(shoe.remoteImageUrl)) {
      try {
        final storageRef = _storage.refFromURL(shoe.remoteImageUrl);
        await storageRef.delete();
        debugPrint('Image deleted from storage: ${shoe.remoteImageUrl}');
      } catch (e) {
        // Log, but do not block deletion if the storage object is already gone
        debugPrint('Error deleting image from storage (may not exist): $e');
      }
    }
    debugPrint(
      'Shoe document deleted successfully for Document ID: ${shoe.documentId} (Doc ID: $docId)',
    );
  }

  /// Utility to check if a path is a network URL.
  bool _isNetworkImage(String path) {
    return path.startsWith('http');
  }

  Future<String> updateShoe(Shoe shoe, String base64Image) async {
    final callable = FirebaseFunctions.instance.httpsCallable('updateShoe');
    await callable
        .call({
          'shoeData': shoe.toMap(),
          'imageBase64': base64Image,
          'userId': _userId,
        })
        .then((value) {
          // Handle success
          print(value.data);
          print(value.data['success']);
          print(value.data['newDocumentId']);
          return value.data['success'];
        })
        .catchError((error) {
          // Handle error
          return 'Error';
        });
    return 'Failed';
  }

  Future<String> deleteShoeFromCloud(Shoe shoe) async {
    final callable = FirebaseFunctions.instance.httpsCallable('deleteShoe');
    print('${shoe.documentId} ${shoe.remoteImageUrl}');
    await callable
        .call({
          'documentId': shoe.documentId,
          'remoteImageUrl': shoe.remoteImageUrl,
          'userId': _userId,
        })
        .then((value) {
          // Handle success
          print(value.data);
          return value.data['success'];
        })
        .catchError((error) {
          // Handle error
          return 'Error';
        });
    return 'Success';
  }
}
