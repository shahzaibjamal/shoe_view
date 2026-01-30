// _ProductCard remains unchanged as it receives all data and callbacks via constructor.
import 'package:flutter/material.dart';
import 'package:shoe_view/Subscription/subscription_manager.dart';

class ProductCard extends StatelessWidget {
  final OfferWithTierDetails offer;
  final Function(OfferWithTierDetails) onBuy;
  final Function() onUnSub;
  final bool isHighlighted;
  final dynamic isPurchased;
  final bool isVerifying;
  const ProductCard({
    super.key,
    required this.offer,
    required this.onBuy,
    required this.onUnSub,
    required this.isVerifying,
    this.isHighlighted = false,
    this.isPurchased = false,
  });

  @override
  Widget build(BuildContext context) {
    // Subtle premium feeling for Gold/Highlighted items
    final bool showPremium = isHighlighted;

    return Container(
      decoration: BoxDecoration(
        color: showPremium ? Colors.amber.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: showPremium ? Colors.amber.shade200 : Colors.grey.shade200,
          width: showPremium ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: isPurchased ? null : () => onBuy(offer),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      offer.name.replaceAll(RegExp(r'\(.*\)'), '').trim(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: showPremium ? Colors.deepOrange[800] : Colors.black87,
                      ),
                    ),
                    if (showPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "BEST VALUE",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[900],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      offer.displayPrice,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ month',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  offer.tierDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: isVerifying
                        ? null
                        : (isPurchased ? onUnSub : () => onBuy(offer)),
                    style: FilledButton.styleFrom(
                      backgroundColor: isPurchased
                          ? Colors.red.shade50
                          : (showPremium
                              ? Colors.black
                              : Colors.blue.shade600),
                      foregroundColor: isPurchased ? Colors.red : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isPurchased ? 'Manage Plan' : 'Subscribe Now',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

