import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';

class UserViewRestaurantPage extends StatefulWidget {
  final Map<String, dynamic> restaurantData;

  const UserViewRestaurantPage({super.key, required this.restaurantData});

  @override
  State<UserViewRestaurantPage> createState() => _UserViewRestaurantPageState();
}

class _UserViewRestaurantPageState extends State<UserViewRestaurantPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final PostService _postService = PostService();
  double _averageRating = 0.0;
  int _totalReviews = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _calculateAverageRating();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _calculateAverageRating() async {
    try {
      final ratingsQuery = await FirebaseFirestore.instance
          .collection('ratings')
          .where('restaurantId', isEqualTo: widget.restaurantData['uid'])
          .get();

      if (ratingsQuery.docs.isNotEmpty) {
        double totalRating = 0;
        for (var doc in ratingsQuery.docs) {
          totalRating += (doc.data()['rating'] ?? 0).toDouble();
        }

        setState(() {
          _averageRating = totalRating / ratingsQuery.docs.length;
          _totalReviews = ratingsQuery.docs.length;
        });
      }
    } catch (e) {
      print('Error calculating rating: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 300,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.restaurantData['profileImageUrl'] != null &&
                            widget.restaurantData['profileImageUrl']
                                .toString()
                                .isNotEmpty
                        ? Image.network(
                            widget.restaurantData['profileImageUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildDefaultHeroImage();
                            },
                          )
                        : _buildDefaultHeroImage(),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.restaurantData['username'] ?? 'Restaurant',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on,
                                  color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.restaurantData['address'] ??
                                      'No address',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: Column(
          children: [
            // Rating Section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < _averageRating.floor()
                                ? Icons.star
                                : index < _averageRating
                                    ? Icons.star_half
                                    : Icons.star_border,
                            color: Colors.amber,
                            size: 24,
                          );
                        }),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_averageRating.toStringAsFixed(1)} ($_totalReviews reviews)',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Add Restaurant Review Button
                  ElevatedButton.icon(
                    onPressed: () => _showRestaurantRatingDialog(),
                    icon: const Icon(Icons.rate_review, size: 18),
                    label: const Text('Rate This Restaurant'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.deepPurple[800],
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Colors.deepPurple[800],
                tabs: const [
                  Tab(text: 'Menu'),
                  Tab(text: 'Reviews'),
                  Tab(text: 'Info'),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMenuTab(),
                  _buildReviewsTab(),
                  _buildInfoTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultHeroImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple[400]!,
            Colors.deepPurple[800]!,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant,
          size: 80,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMenuTab() {
    return StreamBuilder<List<Post>>(
      stream: _postService.getUserPosts(widget.restaurantData['uid']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Error loading menu'));
        }

        final menuItems = snapshot.data ?? [];

        if (menuItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No menu items yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 18),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            final item = menuItems[index];
            return _buildMenuItemCard(item);
          },
        );
      },
    );
  }

  Widget _buildMenuItemCard(Post menuItem) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (menuItem.imageUrl != null && menuItem.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  menuItem.imageUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    menuItem.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildRatingButton(menuItem.id),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              menuItem.description,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                StreamBuilder<double>(
                  stream: _getMenuItemRating(menuItem.id),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButton(String postId) {
    return ElevatedButton.icon(
      onPressed: () => _showMenuItemRatingDialog(postId),
      icon: const Icon(Icons.star_border, size: 16),
      label: const Text('Rate'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple[50],
        foregroundColor: Colors.deepPurple[800],
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildReviewsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ratings')
          .where('restaurantId', isEqualTo: widget.restaurantData['uid'])
          // Temporarily remove orderBy to avoid index requirement
          // .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var reviews = snapshot.data?.docs ?? [];

        // Sort in memory instead of in the query
        reviews.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          return bTime.compareTo(aTime); // Descending order
        });

        if (reviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rate_review, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No reviews yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 18),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showRestaurantRatingDialog(),
                  icon: const Icon(Icons.rate_review),
                  label: const Text('Be the first to review!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple[800],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index].data() as Map<String, dynamic>;
            return _buildReviewCard(review);
          },
        );
      },
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple[100],
                  child: Text(
                    (review['userName'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(color: Colors.deepPurple[800]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review['userName'] ?? 'Anonymous',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < (review['rating'] ?? 0)
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                if (review['createdAt'] != null)
                  Text(
                    _formatDate(review['createdAt']),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
              ],
            ),
            if (review['comment'] != null && review['comment'].isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(review['comment']),
            ],
            if (review['postId'] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Menu Item Review',
                  style: TextStyle(
                    color: Colors.deepPurple[800],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            icon: Icons.info_outline,
            title: 'About',
            content: widget.restaurantData['description'] ??
                'Welcome to our restaurant! We serve delicious food with love.',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.email,
            title: 'Contact',
            content: widget.restaurantData['email'] ?? 'No email provided',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.access_time,
            title: 'Hours',
            content:
                widget.restaurantData['hours'] ?? 'Mon-Sun: 9:00 AM - 10:00 PM',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.deepPurple[800]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(content),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Stream<double> _getMenuItemRating(String postId) {
    return FirebaseFirestore.instance
        .collection('ratings')
        .where('postId', isEqualTo: postId)
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

  void _showMenuItemRatingDialog(String postId) {
    int selectedRating = 0;
    String comment = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rate this dish'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () {
                      setState(() {
                        selectedRating = index + 1;
                      });
                    },
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => comment = value,
                decoration: const InputDecoration(
                  hintText: 'Add a comment (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedRating > 0
                  ? () => _submitMenuItemRating(postId, selectedRating, comment)
                  : null,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestaurantRatingDialog() {
    int selectedRating = 0;
    String comment = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title:
              Text('Rate ${widget.restaurantData['username'] ?? 'Restaurant'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () {
                      setState(() {
                        selectedRating = index + 1;
                      });
                    },
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => comment = value,
                decoration: const InputDecoration(
                  hintText: 'Share your experience...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedRating > 0
                  ? () => _submitRestaurantRating(selectedRating, comment)
                  : null,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitMenuItemRating(
      String postId, int rating, String comment) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('ratings').add({
        'postId': postId,
        'restaurantId': widget.restaurantData['uid'],
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous',
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating submitted successfully!')),
      );

      _calculateAverageRating();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting rating: $e')),
      );
    }
  }

  Future<void> _submitRestaurantRating(int rating, String comment) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if user has already rated this restaurant
      final existingRating = await FirebaseFirestore.instance
          .collection('ratings')
          .where('restaurantId', isEqualTo: widget.restaurantData['uid'])
          .where('userId', isEqualTo: user.uid)
          .where('postId', isNull: true)
          .get();

      if (existingRating.docs.isNotEmpty) {
        // Update existing rating
        await existingRating.docs.first.reference.update({
          'rating': rating,
          'comment': comment,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new rating
        await FirebaseFirestore.instance.collection('ratings').add({
          'restaurantId': widget.restaurantData['uid'],
          'userId': user.uid,
          'userName': user.displayName ?? 'Anonymous',
          'rating': rating,
          'comment': comment,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully!')),
      );

      _calculateAverageRating();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting review: $e')),
      );
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      final date = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }
}
