import 'dart:async';
import 'package:flutter/material.dart';
// Note: You must add the in_app_purchase package to your pubspec.yaml
// import 'package:in_app_purchase/in_app_purchase.dart'; 
// import 'package:provider/provider.dart'; 
// import 'package:shoe_view/app_status_notifier.dart';

// --- Conceptual Imports (Assume these are available) ---
class InAppPurchase {
  static final InAppPurchase instance = InAppPurchase._internal();
  factory InAppPurchase() => instance;
  InAppPurchase._internal();

  Future<bool> isAvailable() async => true; // Mocked check
  Stream<List<PurchaseDetails>> get purchaseStream => Stream.empty(); // Mocked stream
  Future<ProductDetailsResponse> queryProductDetails(Set<String> productIds) async {
    // Mock response with dummy data matching your new tiered model
    final List<ProductDetails> mockProducts = [
      ProductDetails(
        id: 'tier_bronze_monthly', // $1 Tier
        title: 'Bronze Access',
        description: 'Store up to 50 shoes and share data 10 times per day.',
        price: '\$1.00',
        rawPrice: 1.00,
        currencyCode: 'USD',
        // Example of an introductory offer for the lowest tier
        introductoryPrice: '\$0.50 for the first month',
      ),
      ProductDetails(
        id: 'tier_silver_monthly', // $2 Tier
        title: 'Silver Access',
        description: 'Store up to 100 shoes and share data 20 times per day.',
        price: '\$2.00',
        rawPrice: 2.00,
        currencyCode: 'USD',
      ),
      ProductDetails(
        id: 'tier_gold_monthly', // $3 Tier
        title: 'Gold Access (Best Value)',
        description: 'Store up to 500 shoes and unlock UNLIMITED sharing.',
        price: '\$3.00',
        rawPrice: 3.00,
        currencyCode: 'USD',
        // Example of a purchase offer to encourage existing users to upgrade
        introductoryPrice: 'Upgrade now and save 10% on the first month.',
      ),
    ];
    return ProductDetailsResponse(
      productDetails: mockProducts,
      notFoundIDs: [],
    );
  }
  // Mocked method to initiate purchase
  Future<void> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    // In a real app, this launches the native billing UI
  }
  void completePurchase(PurchaseDetails purchaseDetails) {}
}
class ProductDetailsResponse {
  final List<ProductDetails> productDetails;
  final List<String> notFoundIDs;
  ProductDetailsResponse({required this.productDetails, required this.notFoundIDs});
}
class ProductDetails {
  final String id;
  final String title;
  final String description;
  final String price;
  final double rawPrice;
  final String currencyCode;
  final String? introductoryPrice; // Mocked field for offers
  ProductDetails({required this.id, required this.title, required this.description, required this.price, required this.rawPrice, required this.currencyCode, this.introductoryPrice});
}
class PurchaseDetails {}
class PurchaseParam {
  final ProductDetails productDetails;
  PurchaseParam({required this.productDetails});
}

// ----------------------------------------------------


// Defined Subscription IDs (MUST match Play Console/App Store IDs)
const Set<String> _kProductIds = {
  'tier_bronze_monthly',
  'tier_silver_monthly',
  'tier_gold_monthly',
};

class SubscriptionUpgradePage extends StatefulWidget {
  const SubscriptionUpgradePage({super.key});

  @override
  State<SubscriptionUpgradePage> createState() => _SubscriptionUpgradePageState();
}

class _SubscriptionUpgradePageState extends State<SubscriptionUpgradePage> {
  // Use the conceptual InAppPurchase class above
  final InAppPurchase _iap = InAppPurchase.instance; 
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _loading = true;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

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
    _isAvailable = await _iap.isAvailable();

    if (_isAvailable) {
      await _loadProducts();
      // Only set up the listener if IAP is available
      final purchaseUpdated = _iap.purchaseStream;
      _subscription = purchaseUpdated.listen((purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      }, onDone: () {
        _subscription?.cancel();
      }, onError: (error) {
        // Handle error, maybe show a toast
        _showSnackbar('IAP Stream Error: $error');
      });
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

    final ProductDetailsResponse response =
        await _iap.queryProductDetails(_kProductIds);

    if (mounted) {
      if (response.error != null) {
        _showSnackbar('Failed to load products: ${response.error}');
      }
      
      // Handle products not found (crucial for debugging IDs)
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Products Not Found: ${response.notFoundIDs.join(', ')}');
      }

      setState(() {
        _products = response.productDetails;
        _loading = false;
      });
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        _showSnackbar('Purchase Pending...');
      } else if (purchase.status == PurchaseStatus.error) {
        _showSnackbar('Purchase Error: ${purchase.error}');
        // Optional: Call _iap.consumePurchase(purchase) or _iap.completePurchase(purchase) 
        // depending on the type of error and IAP configuration.
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        
        // **IMPORTANT SECURITY STEP**
        // 1. Send the purchase token (purchase.verificationData.serverVerificationData) 
        // to your Firebase Cloud Function (or other secure backend).
        // 2. Your backend MUST verify the token with Google Play/Apple servers.
        // 3. Upon successful verification, your backend updates the user's tier 
        //    (currentTier, expiryDate) in Firestore.
        _verifyAndDeliverProduct(purchase);
        
        // 4. Acknowledge/Complete the purchase to Google Play
        // The purchase will remain in a PENDING state until this is called (for non-consumables).
        _iap.completePurchase(purchase); 
      }
    }
  }

  // Placeholder for calling your secure backend logic
  void _verifyAndDeliverProduct(PurchaseDetails purchase) async {
    // Get the product ID to determine which tier was purchased
    final productId = purchase.productID; 
    
    // 1. Call Firebase Cloud Function (Conceptual)
    // await firebaseService.callVerificationFunction(purchase); 
    
    // 2. On Success: Update the local state (AppStatusNotifier)
    // final notifier = Provider.of<AppStatusNotifier>(context, listen: false);
    // if (productId == 'tier_gold_monthly') {
    //    notifier.updateTier('gold');
    // } else if (productId == 'tier_silver_monthly') {
    //    notifier.updateTier('silver');
    // } else if (productId == 'tier_bronze_monthly') {
    //    notifier.updateTier('bronze');
    // }

    _showSnackbar('Success! Your tier is being activated securely.');
    Navigator.of(context).pop(); // Close the purchase screen
  }

  void _buySubscription(ProductDetails product) {
    if (!_isAvailable) {
      _showSnackbar('In-App Purchases are not available on this device.');
      return;
    }
    
    // Start the purchase flow
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    // Note: Use buyNonConsumable for subscriptions as they are non-consumable
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    
                    // Display Products (using ProductCard widget below)
                    ..._products.map((product) => _ProductCard(
                        product: product,
                        onBuy: _buySubscription,
                        // Highlight the highest tier (Gold)
                        isHighlighted: product.id.contains('gold'), 
                    )).toList(),
                    
                    const SizedBox(height: 30),
                    const Text(
                      'Note: All plans are auto-renewing monthly subscriptions.',
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
        side: isHighlighted ? const BorderSide(color: Colors.amber, width: 3) : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  product.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isHighlighted ? Colors.blueAccent : Colors.black87,
                  ),
                ),
                Text(
                  product.price,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isHighlighted ? Colors.blueAccent : Colors.black,
                  ),
                ),
              ],
            ),
            if (product.introductoryPrice != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Offer: ${product.introductoryPrice!}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              product.description,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => onBuy(product),
                icon: const Icon(Icons.arrow_upward),
                label: Text(
                  'Subscribe Now - ${product.price}',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  backgroundColor: isHighlighted ? Colors.amber : Colors.blueGrey,
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
