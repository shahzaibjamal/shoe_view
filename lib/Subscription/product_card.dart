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

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: showPremium 
            ? (isDark ? Colors.amber.withOpacity(0.15) : Colors.amber.shade50)
            : (isDark ? theme.cardColor : Colors.white),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: showPremium 
              ? (isDark ? Colors.amber.withOpacity(0.4) : Colors.amber.shade200) 
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: showPremium ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
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
                        color: showPremium 
                            ? (isDark ? Colors.amber.shade200 : Colors.deepOrange[800]) 
                            : theme.textTheme.titleMedium?.color,
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
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: theme.textTheme.bodyLarge?.color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ month',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
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
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
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
                          ? (isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade50)
                          : (showPremium
                              ? (isDark ? Colors.white : Colors.black)
                              : theme.primaryColor),
                      foregroundColor: isPurchased 
                          ? Colors.red 
                          : (showPremium && isDark ? Colors.black : Colors.white),
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

