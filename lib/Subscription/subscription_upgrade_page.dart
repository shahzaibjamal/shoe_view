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
    bool isTest = context.read<AppStatusNotifier>().isTest;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Premium Access', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Consumer<SubscriptionManager>(
        builder: (context, manager, child) {
          if (manager.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!manager.isAvailable) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'Store Unavailable',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'In-App Purchasing is not supported or configured on this device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final offers = isTest 
              ? manager.availableOffers 
              : manager.availableOffers.take(1).toList();

          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),

              if (offers.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No active plans found')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final offer = offers[index];
                        String purchasedOffer = context.read<AppStatusNotifier>().purchasedOffer;
                        final isPurchased = purchasedOffer == offer.basePlanId;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ProductCard(
                            offer: offer,
                            onBuy: (p) => manager.buySubscription(
                              offer.purchaseProductDetails,
                            ),
                            isHighlighted: offer.tierDescription.toLowerCase().contains('gold'),
                            isPurchased: isPurchased,
                            isVerifying: _isVerifying,
                            onUnSub: () => manager.manageSubscription(),
                          ),
                        );
                      },
                      childCount: offers.length,
                    ),
                  ),
                ),

              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                             onPressed: _isVerifying
                                ? null
                                : () async {
                                    setState(() => _isVerifying = true);
                                    await manager.queryActivePurchases();
                                    setState(() => _isVerifying = false);
                                  },
                            style: TextButton.styleFrom(foregroundColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
                            child: _isVerifying 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Restore Purchases'),
                          ),
                          Container(height: 16, width: 1, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 16)),
                          TextButton(
                            onPressed: manager.manageSubscription,
                            style: TextButton.styleFrom(foregroundColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
                            child: const Text('Manage Subscription'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Recurring billing. Cancel anytime.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMiniFeature(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      ],
    );
  }

}
