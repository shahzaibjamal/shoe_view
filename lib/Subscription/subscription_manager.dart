import 'dart:async';
import 'dart:convert'; // ADDED: Required for JSON parsing the receipt
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// Note: In a real project, these imports are required for the wrapper classes
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:shoe_view/firebase_service.dart';
import 'package:url_launcher/url_launcher.dart';

const Set<String> _kProductIds = {'tier_premium_access'};
// enum LaunchMode { platformDefault, inAppWebView, externalApplication, externalNonBrowserApplication }
// Future<bool> canLaunchUrl(Uri url) async => true;
// Future<bool> launchUrl(Uri url, {required LaunchMode mode}) async {
//   AppLogger.log('Launching URL: $url with mode: $mode');
//   return true;
// }
// 1. Subscription Tiers (Used to map Base Plan ID to a Description)
final Map<String, String> subscriptionTiers = {
  // Assuming your Base Plan IDs contain these identifiers (e.g., 'monthly_bronze_plan')
  'bronze':
      'The Bronze Tier provides 20 writes and 5 collage shares, perfect for the casual, entry-level user.',
  'silver':
      'The Silver Tier offers 50 writes and 15 collage shares, designed for active users needing more capacity and frequent sharing.',
  'gold':
      'The Gold Tier delivers 500 writes and 50 collage shares, offering maximum capacity and creative freedom for power users and professionals.',
};

// --- FIX 1: Use Composition (Wrapper Class) instead of Inheritance ---

/// A custom wrapper that combines the raw Google Play details with your local marketing data.
class OfferWithTierDetails {
  // Store the actual GooglePlayProductDetails object
  final GooglePlayProductDetails productDetails;

  // Store the local marketing description based on tier
  final String tierDescription;

  // Store key identifiers
  final String basePlanId;
  final SubscriptionOfferDetailsWrapper? offerDetails;
  final String name;

  OfferWithTierDetails({
    required this.productDetails,
    required this.tierDescription,
    required this.basePlanId,
    required this.offerDetails,
    required this.name, // NEW: Requires name
  });

  // Proxy getters for convenience when displaying
  String get id => productDetails.id;
  String get title => productDetails.title;
  double get rawPrice => productDetails.rawPrice;

  // A helper getter for a cleaner price display
  String get displayPrice {
    if (offerDetails != null && offerDetails!.pricingPhases.isNotEmpty) {
      // Typically, the first phase price is the one to show (might be trial, intro, or base)
      return offerDetails!.pricingPhases.first.formattedPrice;
    }
    // Fallback to the generic price field
    return productDetails.price;
  }

  // Helper to get the actual ProductDetails needed for the buy method
  ProductDetails get purchaseProductDetails => productDetails;
}

class SubscriptionManager with ChangeNotifier {
  final FirebaseService _firebaseService;
  final InAppPurchase _iap = InAppPurchase.instance;
  final AppStatusNotifier _appStatusNotifier;

  bool _isAvailable = false;
  bool _isLoading = true;

  // --- FIX 2: Change product list to hold the new custom type ---
  List<OfferWithTierDetails> _offerDetails = [];

  List<PurchaseDetails> _purchases = [];
  String? _transactionMessage;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;

  // --- FIX 3: New getter for products with tier info ---
  List<OfferWithTierDetails> get availableOffers => _offerDetails;

  // Kept for compatibility if external components expect ProductDetails
  List<ProductDetails> get products =>
      _offerDetails.map((e) => e.productDetails).toList();

  List<PurchaseDetails> get purchases => _purchases;
  String? get transactionMessage => _transactionMessage;

  SubscriptionManager(this._firebaseService, this._appStatusNotifier) {
    _initializeIAP();
  }

  Future<void> _initializeIAP() async {
    _isAvailable = await _iap.isAvailable();

    if (_isAvailable) {
      await _loadProducts();

      _subscription = _iap.purchaseStream.listen(
        _listenToPurchaseUpdated,
        onDone: () => _subscription?.cancel(),
        onError: (error) {
          AppLogger.log('IAP Stream Error: $error');
          _setTransactionMessage('A purchasing error occurred.');
        },
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        queryActivePurchases();
      });
    } else {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // notifyListeners();
      });
    }
  }

  // --- FIX 4: Implemented logic to map offer details to local data ---
  Future<void> _loadProducts() async {
    _isLoading = true;
    notifyListeners();

    final response = await _iap.queryProductDetails(_kProductIds);

    if (response.error != null) {
      AppLogger.log('Failed to load products: ${response.error}');
      _setTransactionMessage('Failed to load subscription details.');
      _isLoading = false;
      notifyListeners();
      return;
    }

    final List<OfferWithTierDetails> combinedOffers = [];

    // The query returns ONE GooglePlayProductDetails object for EACH offer/base plan
    for (var pd in response.productDetails) {
      if (pd is GooglePlayProductDetails) {
        final productDetailsWrapper = pd.productDetails;

        if (productDetailsWrapper.productType == ProductType.subs) {
          final fullListOfOffers =
              productDetailsWrapper.subscriptionOfferDetails;
          final currentOfferIndex = pd.subscriptionIndex;

          if (fullListOfOffers != null &&
              currentOfferIndex != null &&
              currentOfferIndex < fullListOfOffers.length) {
            final SubscriptionOfferDetailsWrapper currentOffer =
                fullListOfOffers[currentOfferIndex];

            final basePlanId = currentOffer.basePlanId;
            AppLogger.log('Processing Offer. Base Plan ID: $basePlanId');

            // --- FIX: Filter out offers without pricing (often indicates inactive/deactivated) ---
            if (currentOffer.pricingPhases.isEmpty) {
              AppLogger.log(
                'Skipping offer for $basePlanId: No pricing phase found (likely inactive/deactivated)',
              );
              continue; // Skip this deactivated offer
            }

            // --- Mapping Logic for Name and Description ---
            String tierKey = 'default';

            // Derive Tier
            if (basePlanId.toLowerCase().contains('bronze')) {
              tierKey = 'Bronze';
            } else if (basePlanId.toLowerCase().contains('silver')) {
              tierKey = 'Silver';
            } else if (basePlanId.toLowerCase().contains('gold')) {
              tierKey = 'Gold';
            }

            // NEW: Generate user-friendly name
            final String offerName =
                '$tierKey Tier'; // e.g., "Monthly Gold Tier"

            final String description =
                subscriptionTiers[tierKey.toLowerCase()] ??
                pd.description; // Fallback to store description

            combinedOffers.add(
              OfferWithTierDetails(
                productDetails: pd,
                tierDescription: description,
                basePlanId: basePlanId,
                offerDetails: currentOffer,
                name: offerName, // NEW: Add the generated name
              ),
            );
          }
        }
      }
    }

    // Sort the final list by price (e.g., to ensure consistent display order)
    combinedOffers.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

    _offerDetails = combinedOffers;

    _isLoading = false;
    notifyListeners();
  }
  // --- End _loadProducts fix ---

  Future<void> queryActivePurchases() async {
    AppLogger.log('Querying for active subscriptions...');
    _purchases.clear();

    try {
      await _iap.restorePurchases();
      AppLogger.log('Restore purchases command sent.');
    } catch (e) {
      AppLogger.log('Error querying past purchases: $e');
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        _setTransactionMessage('Purchase Pending...');
      } else if (purchase.status == PurchaseStatus.error) {
        AppLogger.log('Purchase Error: ${purchase.error}');
        _setTransactionMessage('Purchase Failed: ${purchase.error?.message}');
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        AppLogger.log('Purchase requires verification: ${purchase.status}');
        _verifyPurchase(purchase);
      } else {
        AppLogger.log('Unhandled purchase status: ${purchase.status}');
      }
    }
  }

  Future<Map<String, dynamic>> _verifyPurchase(PurchaseDetails purchase) async {
    _setTransactionMessage('Verifying purchase on server...');
    final token = purchase.verificationData.serverVerificationData;
    final productId = purchase.productID;

    final response = await _firebaseService.verifyInAppPurchase(
      productId: productId,
      purchaseToken: token,
    );

    if (response['status'] == 'success') {
      AppLogger.log('Verification successful for $productId');

      final sharesUsed = response['dailySharesUsed'];
      final sharesLimit = response['dailySharesLimit'];
      final tier = response['tier'];
      final purchasedOffer = response['purchasedOffer'];
      _purchases.clear();
      _purchases.add(purchase);
      notifyListeners();

      _appStatusNotifier.updateDailyShares(sharesUsed);
      _appStatusNotifier.updateDailySharesLimit(sharesLimit);
      _appStatusNotifier.updateTier(tier);
      _appStatusNotifier.updatePurchasedOffer(purchasedOffer);

      if (purchase.pendingCompletePurchase) {
        AppLogger.log('completing transaction');
        _iap.completePurchase(purchase);
      }

      _setTransactionMessage('Success! Your subscription is active.');
    } else {
      AppLogger.log('Verification failed: ${response['message']}');
      _setTransactionMessage('Verification failed. Please try again.');
    }

    return response;
  }

  void buySubscription(ProductDetails product) {
    if (!_isAvailable) {
      _setTransactionMessage(
        'In-App Purchases are not available on this device.',
      );
      return;
    }

    // Note: When calling this, you should pass OfferWithTierDetails.purchaseProductDetails
    // or cast the OfferWithTierDetails object if you must.
    final purchaseParam = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);

    AppLogger.log('Purchase initiated for product: ${product.id}');
  }

  void manageSubscription() async {
    _setTransactionMessage('Opening store to manage your subscription...');

    // Use the appropriate URL based on the platform for subscription management.
    final String urlString =
        defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS
        ? 'https://apps.apple.com/account/subscriptions' // iOS/macOS subscription management link
        : 'https://play.google.com/store/account/subscriptions'; // Android subscription management link

    final url = Uri.parse(urlString);

    try {
      // Use platformDefault mode for stability, as it lets the OS decide
      // the best way (browser/store app) to open the link.
      final launched = await launchUrl(url, mode: LaunchMode.platformDefault);

      if (!launched) {
        AppLogger.log(
          'Could not launch subscription management URL: launchUrl returned false for $urlString',
        );
        // Providing clearer instruction to the user
        _setTransactionMessage(
          'Unable to open subscription management page. Please manually check your $urlString.',
        );
      }
    } catch (e) {
      // Catching the PlatformException/channel-error directly
      AppLogger.log('Error launching URL ($urlString): $e');
      // Providing clearer instruction to the user
      _setTransactionMessage(
        'An error occurred while trying to open the store. Error: $e. Please check your $urlString manually.',
      );
    }
  }

  void _setTransactionMessage(String message) {
    _transactionMessage = message;
    notifyListeners();

    Future.delayed(const Duration(seconds: 5), () {
      if (_transactionMessage == message) {
        _transactionMessage = null;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
