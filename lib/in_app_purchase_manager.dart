import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:shoe_view/firebase_service.dart';

// Defined Subscription IDs (MUST match Play Console/App Store IDs)
const Set<String> _kProductIds = {
  'tier_bronze_monthly',
  'tier_silver_monthly',
  'tier_gold_monthly',
};

// This class will be registered globally (e.g., via Provider) and handles all IAP lifecycle events.
class InAppPurchaseManager with ChangeNotifier {
  final FirebaseService _firebaseService;
  final InAppPurchase _iap = InAppPurchase.instance;
  final BuildContext _context;

  // State fields
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _isLoading = true;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Expose state to UI via getters
  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;
  bool get isLoading => _isLoading;

  // Constructor: Requires the FirebaseService to call the cloud function
  InAppPurchaseManager(this._firebaseService, this._context) {
    _initializeIAP();
  }

  // --- CORE INITIALIZATION ---
  Future<void> _initializeIAP() async {
    // 1. Fetch the platform-specific App ID
   _isAvailable = await _iap.isAvailable();

    if (_isAvailable) {
      await _loadProducts();

      // 2. Listen to the purchase stream for purchases/restorations
      final purchaseUpdated = _iap.purchaseStream;
      _subscription = purchaseUpdated.listen(
        _listenToPurchaseUpdated,
        onDone: () => _subscription?.cancel(),
        onError: (error) {
          AppLogger.log('IAP Stream Error: $error');
          // Notification should be handled by the UI based on state changes
        },
      );

      // 3. IMPORTANT: Query for any active purchases/subscriptions on launch
      await queryActivePurchases();
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Called by the UI on app launch, or whenever status needs to be checked (e.g., on app resume)
  Future<void> queryActivePurchases() async {
    AppLogger.log('Querying for active subscriptions...');
    try {
      // This triggers the purchaseStream with PurchaseStatus.restored for active subs
      await _iap.restorePurchases();
      AppLogger.log('Restore purchases command sent.');
    } catch (e) {
      AppLogger.log('Error querying past purchases: $e');
    }
  }

  // --- PRODUCT LOADING ---
  Future<void> _loadProducts() async {
    _isLoading = true;
    notifyListeners();

    final ProductDetailsResponse response = await _iap.queryProductDetails(
      _kProductIds,
    );

    if (response.error != null) {
      AppLogger.log('Failed to load products: ${response.error}');
    }

    if (response.notFoundIDs.isNotEmpty) {
      AppLogger.log('Products Not Found: ${response.notFoundIDs.join(', ')}');
    }

    final sortedProducts = response.productDetails;
    sortedProducts.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

    _products = sortedProducts;
    _isLoading = false;
    notifyListeners();
  }

  // --- PURCHASE FLOW ---
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        _showSnackbar('Purchase Pending...');
      } else if (purchase.status == PurchaseStatus.error) {
        AppLogger.log('Purchase Error: ${purchase.error}');
        _showSnackbar('Purchase Failed: ${purchase.error?.message}');
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Verify with backend
        _verifyAndDeliverProduct(purchase);
      } else {
        AppLogger.log('Purchase status: ${purchase.status}');
      }
    }
  }

  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchase) async {
    AppLogger.log('Verifying and delivering product: ${purchase.productID}...');

    final finalReceiptToken = purchase.verificationData.serverVerificationData;
    final purchasedProductId = purchase.productID;

    final response = await _firebaseService.verifyInAppPurchase(
      productId: purchasedProductId,
      purchaseToken: finalReceiptToken,
    );

    if (response['status'] == 'success') {
      AppLogger.log('Verification successful. Tier: ${response['tier']}');
      _showSnackbar('Success! Your tier is being activated securely.');
      final sharesUsed = response['dailySharesUsed'];
      final sharesLimit = response['dailySharesLimit'];
      AppLogger.log(
        'Verification successful. Tier: ${response['tier']} shares : ${sharesUsed}/${sharesLimit}',
      );
      _context.read<AppStatusNotifier>().updateDailyShares(sharesUsed);
      _context.read<AppStatusNotifier>().updateDailySharesLimit(sharesLimit);

      // Acknowledge purchase to the store
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
      // IMPORTANT: You should update your AppStatusNotifier or user state here
      // e.g., Provider.of<AppStatusNotifier>(context, listen: false).setUserTier(response['tier']);
    } else {
      AppLogger.log('Server verification failed: ${response['message']}');
      _showSnackbar('Verification failed. Please check your connection.');
    }
  }

  // Exposed method for the UI to call when a button is pressed
  void buySubscription(ProductDetails product) {
    if (!_isAvailable) {
      _showSnackbar('In-App Purchases are not available on this device.');
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
    AppLogger.log('Purchase initiated for product: ${product.id}');
  }

  // Exposed method for managing subscription (requires url_launcher)
  void manageSubscription() {
    AppLogger.log('Unsubscribe/Manage initiated.');
    _showSnackbar('Redirecting to the store to manage your subscription.');
    // Implement platform-specific deep-linking using package:url_launcher here
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // --- UTILITY: Simplified Snackbar for Service ---
  // NOTE: This assumes you have access to a global or context-independent way
  // to show SnackBar, often handled via a Navigator key or a dedicated MessageService.
  // For this example, we'll keep the log and assume the UI handles feedback.
  void _showSnackbar(String message) {
    AppLogger.log('IAP Manager Alert: $message');
  }
}
