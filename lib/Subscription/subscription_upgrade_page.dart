// --- in_app_purchase_view.dart (formerly SubscriptionUpgradePage) ---

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shoe_view/Subscription/product_card.dart';
import 'package:shoe_view/Subscription/subscription_manager.dart';

class SubscriptionUpgradePage extends StatefulWidget {
  const SubscriptionUpgradePage({super.key});

  @override
  State<SubscriptionUpgradePage> createState() =>
      _SubscriptionUpgradePageState();
}

class _SubscriptionUpgradePageState extends State<SubscriptionUpgradePage> {
  // 1. FIX: Removed the duplicate declaration.
  // Changed to nullable to safely handle initialization check in dispose.
  SubscriptionManager? _manager;

  // Track the last message to avoid unnecessary SnackBar updates.
  String? _lastMessage;

  @override
  void initState() {
    super.initState();

    // The safest way to access Provider in initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenForManagerMessages();
    });
  }

  // Listens to the manager's transaction message stream
  void _listenForManagerMessages() {
    // Read the manager once. This is safe inside addPostFrameCallback.
    // We can use context.read because we are not listening for changes here.
    _manager = context.read<SubscriptionManager>();

    // Start listening to the manager
    // We know _manager is not null here, but we check/force non-null access.
    _manager!.addListener(_handleManagerUpdate);
  }

  void _handleManagerUpdate() {
    // 2. FIX: Access the nullable field with a null check or null-aware operator.
    // Using a local variable for clarity and promotion.
    final manager = _manager;

    if (manager == null) return; // Should not happen if logic is correct

    // Check if message exists and is different from the last one
    if (manager.transactionMessage != null &&
        manager.transactionMessage != _lastMessage) {
      _showSnackbar(manager.transactionMessage!);
      _lastMessage = manager.transactionMessage; // Update last message
    }
  }

  @override
  void dispose() {
    // 3. FIX: Check for nullability. This is the correct way for instance fields.
    if (_manager != null) {
      _manager!.removeListener(_handleManagerUpdate);
    }
    super.dispose();
  }

  void _showSnackbar(String message) {
    if (mounted) {
      // Use the builder context or a safe context to show the snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consumer is correct for listening to state changes in the manager
    return Consumer<SubscriptionManager>(
      builder: (context, manager, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Upgrade Your Access'),
            backgroundColor: Colors.blueGrey,
          ),
          body: manager.isLoading
              ? const Center(child: CircularProgressIndicator())
              : !manager.isAvailable
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
                        // --- FIX 4: Use the new availableOffers list ---
                        if (manager.availableOffers.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text('No subscription products found.'),
                            ),
                          )
                        else
                          // Iterate over the list of OfferWithTierDetails
                          ...manager.availableOffers.map((offer) {
                            final isPurchased = manager.purchases.any(
                              // Use the proxy ID getter from OfferWithTierDetails
                              (p) => p.productID == offer.id,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: ProductCard(
                                // Pass the OfferWithTierDetails object to ProductCard for display
                                offer: offer,
                                // CRUCIAL FIX: When calling buySubscription, 
                                // pass the underlying ProductDetails object needed by the IAP plugin.
                                onBuy: (p) => manager.buySubscription(offer.purchaseProductDetails),
                                // Use the proxy ID getter
                                isHighlighted: offer.id.contains('gold'),
                                isPurchased: isPurchased, 
                              ),
                            );
                          }),

                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: manager.queryActivePurchases,
                              child: const Text('Restore Purchases'),
                            ),
                            TextButton(
                              onPressed: manager.manageSubscription,
                              child: const Text('Manage Subscription'),
                            ),
                          ],
                        ),
                      ],
                    ),
        );
      },
    );
  }
}
