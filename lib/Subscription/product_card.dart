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
                    offer.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isHighlighted ? Colors.blueAccent : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  offer.displayPrice,
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
              offer.tierDescription,
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: isVerifying
                    ? null
                    : (isPurchased ? onUnSub : () => onBuy(offer)),
                icon: Icon(isPurchased ? Icons.cancel : Icons.star),
                label: Text(
                  isPurchased
                      ? 'Unsubscribe'
                      : 'Subscribe Now - ${offer.displayPrice}',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                  backgroundColor: isPurchased
                      ? Colors.red.shade600
                      : (isHighlighted
                            ? Colors.blueAccent.shade700
                            : Colors.grey.shade700),
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
