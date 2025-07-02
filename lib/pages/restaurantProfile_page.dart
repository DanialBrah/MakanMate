import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/auth_service.dart';
import '../widgets/post_card.dart';
import '../pages/createpost_page.dart';
import '../widgets/edit_post_dialog.dart';
import 'edit_profile_page.dart';
import 'create_menu_item_page.dart';
import 'dart:convert';

class RestaurantProfilePage extends StatefulWidget {
  const RestaurantProfilePage({super.key});

  @override
  State<RestaurantProfilePage> createState() => _RestaurantProfilePageState();
}

class _RestaurantProfilePageState extends State<RestaurantProfilePage>
    with SingleTickerProviderStateMixin {
  final PostService _postService = PostService();
  final AuthService _authService = AuthService();
  late TabController _tabController;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  double _averageRating = 0.0;
  int _totalReviews = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Changed to 4 tabs
    _loadUserData();
    _calculateAverageRating();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await _authService.getUserData();
      if (userDoc != null && userDoc.exists) {
        setState(() {
          _userData = userDoc.data() as Map<String, dynamic>?;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load user data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _calculateAverageRating() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final ratingsQuery = await FirebaseFirestore.instance
            .collection('ratings')
            .where('restaurantId', isEqualTo: user.uid)
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
      }
    } catch (e) {
      print('Error calculating rating: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _signOut();
              },
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    final userName = _userData?['username'] ?? user?.displayName ?? 'User';
    final userEmail = _userData?['email'] ?? user?.email ?? '';
    final userRole = _userData?['role'] ?? 'Restaurant Owner';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) {
              if (value == 'signout') {
                _showSignOutDialog();
              } else if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const EditProfilePage()),
                ).then((result) {
                  if (result == true) {
                    Navigator.pop(
                        context, true); // Pass back result to HomePage
                  }
                });
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.black, size: 20),
                    SizedBox(width: 8),
                    Text('Edit Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Sign Out', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Profile Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Profile Picture
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.deepPurple[800],
                  backgroundImage: _userData?['photoBase64'] != null &&
                          (_userData!['photoBase64'] as String).isNotEmpty
                      ? MemoryImage(base64Decode(_userData!['photoBase64']))
                      : null,
                  child: _userData?['photoBase64'] == null ||
                          (_userData!['photoBase64'] as String).isEmpty
                      ? Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),

                const SizedBox(height: 16),

                // User Name
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // User Email
                Text(
                  userEmail,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),

                // User Role Chip
                Chip(
                  label: Text(
                    userRole,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Colors.deepPurple[800],
                ),
                const SizedBox(height: 16),

                // Rating Display
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
                const SizedBox(height: 20),

                // Stats Row
                StreamBuilder<List<Post>>(
                  stream: user != null
                      ? _postService.getUserPosts(user.uid)
                      : Stream.value([]),
                  builder: (context, snapshot) {
                    final posts = snapshot.data ?? [];
                    final totalLikes = posts.fold<int>(
                      0,
                      (sum, post) => sum + post.likes.length,
                    );

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn('Posts', posts.length.toString()),
                        _buildStatColumn('Likes', totalLikes.toString()),
                        _buildStatColumn('Joined', _getJoinedDate()),
                      ],
                    );
                  },
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
                Tab(icon: Icon(Icons.grid_on), text: 'Posts'),
                Tab(icon: Icon(Icons.restaurant_menu), text: 'Menu'),
                Tab(icon: Icon(Icons.rate_review), text: 'Reviews'),
                Tab(icon: Icon(Icons.bookmark_border), text: 'Saved'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(),
                _buildMenuTab(),
                _buildReviewsTab(),
                _buildSavedTab(),
              ],
            ),
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //         builder: (context) => const CreatePostPage(),
      //       ),
      //     );
      //   },
      //   backgroundColor: Colors.deepPurple[800],
      //   child: const Icon(Icons.add, color: Colors.white),
      // ),
    );
  }

  Widget _buildMenuTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to view menu'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('restaurants')
          .doc(user.uid)
          .collection('menu')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final menuItems = snapshot.data?.docs ?? [];

        return Scaffold(
          body: menuItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No menu items yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first menu item!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) {
                    final item =
                        menuItems[index].data() as Map<String, dynamic>;
                    return _buildMenuItemCard(item, menuItems[index].id);
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateMenuItemPage(),
                ),
              );
            },
            backgroundColor: Colors.deepPurple[800],
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildMenuItemCard(Map<String, dynamic> item, String itemId) {
    ImageProvider? imageProvider;
    if (item['photoBase64'] != null && item['photoBase64'].isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(item['photoBase64']));
      } catch (_) {
        imageProvider = null;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (imageProvider != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image(
                      image: imageProvider,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (imageProvider == null)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[300],
                    ),
                    child: const Icon(Icons.image_not_supported, size: 32),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Unnamed Item',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['description'] ?? 'No description',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${(item['price'] ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editMenuItem(item, itemId);
                    } else if (value == 'delete') {
                      _deleteMenuItem(itemId);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (item['categories'] != null &&
                (item['categories'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 4,
                  children: (item['categories'] as List)
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

  void _editMenuItem(Map<String, dynamic> item, String itemId) {
    // Navigate to edit menu item page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateMenuItemPage(
          existingItem: item,
          itemId: itemId,
        ),
      ),
    );
  }

  Future<void> _deleteMenuItem(String itemId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Menu Item'),
        content: const Text('Are you sure you want to delete this menu item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(user.uid)
            .collection('menu')
            .doc(itemId)
            .delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu item deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Widget _buildStatColumn(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getJoinedDate() {
    if (_userData?['createdAt'] != null) {
      final createdAt = _userData!['createdAt'] as Timestamp;
      final date = createdAt.toDate();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[date.month - 1]} ${date.year}';
    }
    return 'Recently';
  }

  Widget _buildPostsTab() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text('Please sign in to view your posts'),
      );
    }

    return StreamBuilder<List<Post>>(
      stream: _postService.getUserPosts(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share your first recipe!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreatePostPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Post'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: PostCard(
                  post: post,
                  onLike: () => _handleLike(post.id),
                  onComment: () => _handleComment(post),
                  onEdit: () => _handleEdit(context, post),
                  onDelete: () => _handleDelete(post.id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to view reviews'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ratings')
          .where('restaurantId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var reviews = snapshot.data?.docs ?? [];

        reviews.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
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
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index].data() as Map<String, dynamic>;

            // ✅ Extract user photo base64 here
            final userPhotoBase64 = review['userPhotoBase64'] as String?;

            return _buildReviewCard(review, userPhotoBase64);
          },
        );
      },
    );
  }

  Widget _buildReviewCard(
      Map<String, dynamic> review, String? userPhotoBase64) {
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
                  radius: 24,
                  backgroundColor: Colors.deepPurple[100],
                  backgroundImage: (review['userPhotoBase64'] != null &&
                          (review['userPhotoBase64'] as String).isNotEmpty)
                      ? MemoryImage(base64Decode(review['userPhotoBase64']))
                      : null,
                  child: (review['userPhotoBase64'] == null ||
                          (review['userPhotoBase64'] as String).isEmpty)
                      ? Text(
                          (review['userName'] ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            color: Colors.deepPurple[800],
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
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

  Widget _buildSavedTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Saved posts',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLike(String postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _postService.toggleLike(postId, user.uid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to like post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleComment(Post post) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comment feature coming soon!'),
      ),
    );
  }

  // Handle edit functionality
  void _handleEdit(BuildContext context, Post post) {
    showDialog(
      context: context,
      builder: (context) => EditPostDialog(
        post: post,
        onPostUpdated: () {
          // Refresh the posts list
          setState(() {});
        },
      ),
    );
  }

  // Handle delete functionality
  Future<void> _handleDelete(String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _postService.deletePost(postId, currentUser.uid);
        // Show success message
        print('Post deleted successfully');
      }
    } catch (e) {
      print('Error deleting post: $e');
      // Show error message to user
    }
  }
}
