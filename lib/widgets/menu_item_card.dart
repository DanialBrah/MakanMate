import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MenuItemCard extends StatelessWidget {
  final Map<String, dynamic> menuItem;
  final String restaurantId;
  final Function(String) onRateItem;

  const MenuItemCard({
    super.key,
    required this.menuItem,
    required this.restaurantId,
    required this.onRateItem,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (menuItem['imageUrl'] != null && menuItem['imageUrl'].isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  menuItem['imageUrl'],
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    color: Colors.grey[200],
                    child: const Icon(Icons.restaurant_menu, size: 50),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    menuItem['name'] ?? 'Unnamed Item',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => onRateItem(menuItem['id']),
                  icon: const Icon(Icons.star_border, size: 16),
                  label: const Text('Rate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple[50],
                    foregroundColor: Colors.deepPurple[800],
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              menuItem['description'] ?? 'No description',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                StreamBuilder<double>(
                  stream: _getMenuItemRating(menuItem['id']),
                  builder: (context, snapshot) {
                    final rating = snapshot.data ?? 0.0;
                    return Text(
                      rating > 0 ? rating.toStringAsFixed(1) : 'Not rated',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
                const Spacer(),
                Text(
                  '\$${(menuItem['price'] ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            if (menuItem['categories'] != null &&
                (menuItem['categories'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 4,
                  children: (menuItem['categories'] as List)
                      .map<Widget>((category) => Chip(
                            label: Text(category.toString()),
                            backgroundColor: Colors.deepPurple[50],
                            labelStyle: const TextStyle(fontSize: 12),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Stream<double> _getMenuItemRating(String menuItemId) {
    return FirebaseFirestore.instance
        .collection('ratings')
        .where('menuItemId', isEqualTo: menuItemId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return 0.0;

      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['rating'] ?? 0).toDouble();
      }
      return total / snapshot.docs.length;
    });
  }
}
