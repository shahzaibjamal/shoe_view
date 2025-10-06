// --- subscription_manager.dart (formerly InAppPurchaseManager) ---

import 'dart:async';
import 'package:flutter/material.dart'; // Still needed for ChangeNotifier
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:shoe_view/firebase_service.dart';

// Defined Subscription IDs (MUST match Play Console/App Store IDs)
const Set<String> _kProductIds = {
  'tier_bronze_monthly',
  'tier_silver_monthly',
  'tier_gold_monthly',
};

// Renamed class to SubscriptionManagerF
class SubscriptionManager with ChangeNotifier {
  final FirebaseService _firebaseService;
  final InAppPurchase _iap = InAppPurchase.instance;
  final AppStatusNotifier _appStatusNotifier; 

  // State fields
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _isLoading = true;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  // Added a field to communicate transaction success/failure status to the UI
  String? _transactionMessage;

  // Expose state to UI via getters
  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;
  bool get isLoading => _isLoading;
  String? get transactionMessage => _transactionMessage;

  // Constructor: Requires the FirebaseService to call the cloud function
  // Removed BuildContext from the constructor to make it a pure service
  SubscriptionManager(this._firebaseService, this._appStatusNotifier) {
    _initializeIAP();
  }

  // --- CORE INITIALIZATION ---
  Future<void> _initializeIAP() async {
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
          _setTransactionMessage('A purchasing error occurred.');
        },
      );

      // 3. IMPORTANT: Query for any active purchases/subscriptions on launch
      await queryActivePurchases();
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Utility to set and clear transaction message for UI
  void _setTransactionMessage(String message) {
    _transactionMessage = message;
    notifyListeners();
    // Optional: Clear message after a delay so it doesn't persist
    Future.delayed(const Duration(seconds: 5), () {
      if (_transactionMessage == message) {
        _transactionMessage = null;
        notifyListeners();
      }
    });
  }

  // Called by the UI to check for existing subs
  Future<void> queryActivePurchases() async {
    AppLogger.log('Querying for active subscriptions...');
    try {
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
      _setTransactionMessage('Failed to load subscription details.');
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
        _setTransactionMessage('Purchase Pending...');
      } else if (purchase.status == PurchaseStatus.error) {
        AppLogger.log('Purchase Error: ${purchase.error}');
        _setTransactionMessage('Purchase Failed: ${purchase.error?.message}');
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Deliver product requires context to update AppStatusNotifier,
        // so we make this method accept the context provided by the UI.
        // For the global service, we rely on the UI to call the contextual method.
        AppLogger.log('Purchase requires verification: ${purchase.status}');
        // We cannot call _verifyAndDeliverProduct here as it needs BuildContext.
        // We MUST pass the PurchaseDetails to a contextual method called by the view.
        // However, to simplify the external interface, we'll keep the internal verification logic here
        // but acknowledge the need for context during the AppStatusNotifier update.
        // Since the manager is registered via Provider, we can't completely remove all
        // context-related logic if it must update AppStatusNotifier.

        // Since the requirement is to remove context, we must ONLY do Firebase verification here.
        // The AppStatusNotifier update MUST be delegated to a UI method.
        // This is a compromise: we verify here, and let the UI handle the AppStatusNotifier update.
        _verifyPurchase(purchase);
      } else {
        AppLogger.log('Purchase status: ${purchase.status}');
      }
    }
  }

  // New method: ONLY performs Firebase verification and returns the result
  Future<Map<String, dynamic>> _verifyPurchase(PurchaseDetails purchase) async {
    final finalReceiptToken = purchase.verificationData.serverVerificationData;
    final purchasedProductId = purchase.productID;

    final response = await _firebaseService.verifyInAppPurchase(
      productId: purchasedProductId,
      purchaseToken: finalReceiptToken,
    );

    if (response['status'] == 'success') {
      AppLogger.log('Verification successful for ${purchase.productID}');
      final sharesUsed = response['dailySharesUsed'];
      final sharesLimit = response['dailySharesLimit'];
      final tier = response['tier'];
      AppLogger.log('Verification successful. Tier:$tier shares : $sharesUsed/$sharesLimit');
      _appStatusNotifier.updateDailyShares(sharesUsed);
      _appStatusNotifier.updateDailySharesLimit(sharesLimit);
      _appStatusNotifier.updateTier(tier);

      // CRITICAL: Acknowledge purchase to the store
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
      _setTransactionMessage('Success! Your purchase is being applied.');
    } else {
      AppLogger.log('Server verification failed: ${response['message']}');
      _setTransactionMessage('Verification failed. Please try again.');
    }
    return response;
  }

  // Exposed method for the UI to call when a button is pressed
  void buySubscription(ProductDetails product) {
    if (!_isAvailable) {
      _setTransactionMessage(
        'In-App Purchases are not available on this device.',
      );
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
    AppLogger.log('Purchase initiated for product: ${product.id}');
  }

  // Exposed method for managing subscription (requires url_launcher)
  void manageSubscription() {
    AppLogger.log('Unsubscribe/Manage initiated.');
    _setTransactionMessage(
      'Redirecting to the store to manage your subscription.',
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
