// _ProductCard remains unchanged as it receives all data and callbacks via constructor.
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class ProductCard extends StatelessWidget {
  final ProductDetails product;
  final Function(ProductDetails) onBuy;
  final bool isHighlighted;
  const ProductCard({super.key, 
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