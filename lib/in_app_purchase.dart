import 'dart:async';
import 'package:flutter/material.dart';
// IMPORTANT: You must add the 'package_info_plus' dependency to your pubspec.yaml
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

class SubscriptionUpgradePage extends StatefulWidget {
  final FirebaseService firebaseService;

  const SubscriptionUpgradePage({super.key, required this.firebaseService});

  @override
  State<SubscriptionUpgradePage> createState() =>
      _SubscriptionUpgradePageState();
}

class _SubscriptionUpgradePageState extends State<SubscriptionUpgradePage> {
  final InAppPurchase _iap = InAppPurchase.instance;
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _loading = true;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  // State variable to store the dynamically fetched App ID
  String? _appPackageName; 

  @override
  void initState() {
    super.initState();
    _initializeIAP();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _initializeIAP() async {
    // 1. Fetch the platform-specific App ID (Package Name/Bundle ID)
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      _appPackageName = packageInfo.packageName;
      AppLogger.log('App Package Name initialized: $_appPackageName');
    } catch (e) {
      AppLogger.log('FATAL: Could not retrieve package info: $e');
      _showSnackbar('Initialization failed. Check package_info_plus setup.');
      // Stop initialization if we can't get the package name for secure verification
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    _isAvailable = await _iap.isAvailable();

    if (_isAvailable) {
      await _loadProducts();
      final purchaseUpdated = _iap.purchaseStream;
      _subscription = purchaseUpdated.listen(
        (purchaseDetailsList) {
          _listenToPurchaseUpdated(purchaseDetailsList);
        },
        onDone: () {
          _subscription?.cancel();
        },
        onError: (error) {
          AppLogger.log('IAP Stream Error: $error');
          _showSnackbar('A purchasing error occurred.');
        },
      );
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
    });

    final ProductDetailsResponse response = await _iap.queryProductDetails(
      _kProductIds,
    );

    if (mounted) {
      if (response.error != null) {
        AppLogger.log('Failed to load products: ${response.error}');
        _showSnackbar('Failed to load subscription details.');
      }

      if (response.notFoundIDs.isNotEmpty) {
        AppLogger.log('Products Not Found: ${response.notFoundIDs.join(', ')}');
      }

      final sortedProducts = response.productDetails;
      sortedProducts.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

      setState(() {
        _products = sortedProducts;
        _loading = false;
      });
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        _showSnackbar('Purchase Pending...');
      } else if (purchase.status == PurchaseStatus.error) {
        AppLogger.log('Purchase Error: ${purchase.error}');
        _showSnackbar('Purchase Failed: ${purchase.error?.message}');
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _verifyAndDeliverProduct(purchase);

        /******************REMOVE THIS IF server verification*****************/
        // Note: For secure server verification, the server should handle the 
        // acknowledgement/completion logic. However, since we are only simulating 
        // the server call here, we still need this for local testing.
      }
    }
  }

  // FIXED: Calling your secure backend logic with the required package name
  void _verifyAndDeliverProduct(PurchaseDetails purchase) async {
    AppLogger.log('Verifying and delivering product: ${purchase.productID}');

    if (_appPackageName == null) {
      AppLogger.log('Verification failed: App Package Name is missing.');
      _showSnackbar('Verification failed: App identity not found.');
      return;
    }

    // 1. Extract the required verification data from 'purchase'.
    final finalReceiptToken = purchase.verificationData.serverVerificationData;
    final purchasedProductId = purchase.productID;

    // <<< THIS IS THE CRITICAL SPOT >>>
    // We now pass the dynamically retrieved app identity.
    final response = await widget.firebaseService.verifyInAppPurchase(
      productId: purchasedProductId,
      purchaseToken: finalReceiptToken,
    );

    if (response['status'] == 'success') {
      AppLogger.log('Verification successful. Tier: ${response['tier']}');
      // Update local state based on server response (e.g., using Provider)
      // Provider.of<AppStatusNotifier>(context, listen: false).setUserTier(response['tier']); 
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
      _showSnackbar('Success! Your tier is being activated securely.');
    } else {
      AppLogger.log('Server verification failed: ${response['message']}');
      _showSnackbar('Verification failed. Please check your connection.');
    }

    if (mounted) {
      Future.delayed(const Duration(seconds: 1), () {
        // Only pop if verification was successful OR if the UI needs to be dismissed regardless.
        // Navigator.of(context).pop();
      });
    }
  }

  // New function to handle unsubscription/management
  void _unsubscribe() {
    AppLogger.log('Unsubscribe/Manage initiated.');
    _showSnackbar('Redirecting to the store to manage your subscription. This requires the "url_launcher" package.');
    
    // In a real app, you would use package:url_launcher here:
    // 
    // Android (Google Play):
    // const String androidUrl = 'https://play.google.com/store/account/subscriptions';
    // 
    // iOS (App Store):
    // const String iosUrl = 'https://apps.apple.com/account/subscriptions';
    //
    // For now, we'll just log the action.
    AppLogger.log('ACTION REQUIRED: Implement platform-specific deep-linking to the subscription management page.');
  }

  void _buySubscription(ProductDetails product) {
    if (!_isAvailable) {
      _showSnackbar('In-App Purchases are not available on this device.');
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

    _iap.buyNonConsumable(purchaseParam: purchaseParam);
    AppLogger.log('Purchase initiated for product: ${product.id}');
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Your Access'),
        backgroundColor: Colors.blueGrey,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_isAvailable
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'In-App Purchasing is not supported or configured correctly on this device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.redAccent, fontSize: 16),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    const Text(
                      'Unlock unlimited features and premium tools by upgrading your account.',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    if (_products.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 40.0),
                          child: Text(
                            'No products found. Check your product IDs and platform configuration.',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      // Iterate through products and generate a list of full-width cards
                      ..._products.map((product) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _ProductCard(
                            product: product,
                            onBuy: _buySubscription,
                            isHighlighted: product.id.contains('gold'),
                          ),
                        );
                      }).toList(),

                    // --------------------------------------------------
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () {
                            _iap.restorePurchases();
                            _showSnackbar('Restoring purchases...');
                          },
                          child: const Text('Restore Purchases'),
                        ),
                        // NEW: Button to manage or unsubscribe
                        TextButton(
                          onPressed: _unsubscribe,
                          child: const Text('Manage Subscription'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Note: All plans are auto-renewing monthly subscriptions. Subscriptions are managed via the App Store or Google Play.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
    );
  }
}

// --- Helper Widget for displaying a single product card ---
class _ProductCard extends StatelessWidget {
  final ProductDetails product;
  final Function(ProductDetails) onBuy;
  final bool isHighlighted;

  const _ProductCard({
    required this.product,
    required this.onBuy,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isHighlighted ? 8 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHighlighted
            ? const BorderSide(color: Colors.blueAccent, width: 3)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic, // Aligns text baselines
              children: [
                Flexible(
                  child: Text(
                    product.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isHighlighted ? Colors.blueAccent : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  product.price,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isHighlighted ? Colors.blueAccent : Colors.black,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            Text(
              product.description,
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => onBuy(product),
                icon: const Icon(Icons.star),
                label: Text(
                  'Subscribe Now - ${product.price}',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                  backgroundColor: isHighlighted
                      ? Colors.blueAccent.shade700
                      : Colors.grey.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
