// --- in_app_purchase_view.dart (formerly SubscriptionUpgradePage) ---

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shoe_view/Helpers/app_logger.dart';
import 'package:shoe_view/Subscription/product_card.dart';
import 'package:shoe_view/Subscription/subscription_manager.dart';
import 'package:shoe_view/app_status_notifier.dart';

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
  bool _isVerifying = false;
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
    bool isTest = context.read<AppStatusNotifier>().isTest;
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
                      ...(isTest
                              ? manager.availableOffers
                              : manager.availableOffers.take(1))
                          .map((offer) {
                            String purchasedOffer = context
                                .read<AppStatusNotifier>()
                                .purchasedOffer;
                            final isPurchased =
                                purchasedOffer == offer.basePlanId;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: ProductCard(
                                // Pass the OfferWithTierDetails object to ProductCard for display
                                offer: offer,
                                onBuy: (p) => manager.buySubscription(
                                  offer.purchaseProductDetails,
                                ),
                                isHighlighted: offer.tierDescription.contains(
                                  'gold',
                                ),
                                isPurchased: isPurchased,
                                isVerifying: _isVerifying,
                                onUnSub: () => manager.manageSubscription(),
                              ),
                            );
                          }),

                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: _isVerifying
                              ? null
                              : () async {
                                  setState(() => _isVerifying = true);
                                  await manager.queryActivePurchases();
                                  setState(() => _isVerifying = false);
                                },
                          child: _isVerifying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Restore Purchases'),
                        ),
                        TextButton(
                          onPressed: _isVerifying
                              ? null
                              : manager.manageSubscription,
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
