import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../pages/createpost_page.dart';
import '../pages/userprofile_page.dart';
import '../pages/restaurantProfile_page.dart';
import '../widgets/post_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/edit_post_dialog.dart';
import '../pages/RestaurantSearchPage.dart';

class HomePage extends StatefulWidget {
  final String userRole;

  const HomePage({super.key, required this.userRole});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PostService _postService = PostService();
  String _firestoreUsername = 'User';
  String _firestoreUserRole = 'Member'; // default role
  int _selectedIndex = 0;

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUsernameAndRoleFromFirestore();
  }

  Future<void> _loadUsernameAndRoleFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _firestoreUsername = data['username'] ?? 'User';
          _firestoreUserRole = data['role'] ?? 'Member';
        });
      }
    }
  }

  @override
Widget build(BuildContext context) {
  final List<Widget> _pages = [
    _buildHomeContent(),
    const RestaurantSearchPage(),
    const SizedBox(),
    // const ChatPageContent(),
    // const MapPageContent(),
  ];

  return Scaffold(
    backgroundColor: Colors.grey[50],
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text('Hello $_firestoreUsername!',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold)),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: GestureDetector(
            onTap: () {
              if (_firestoreUserRole == 'User') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserProfilePage(),
                  ),
                ).then((result) {
                  if (result == true) {
                    _loadUsernameAndRoleFromFirestore();
                  }
                });
              } else if (_firestoreUserRole == 'Restaurant Owner') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RestaurantProfilePage(),
                  ),
                ).then((result) {
                  if (result == true) {
                    _loadUsernameAndRoleFromFirestore();
                  }
                });
              }
            },
            child: Chip(
              label: Text(
                _firestoreUserRole,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.deepPurple[800],
            ),
          ),
        ),
      ],
    ),
    body: _selectedIndex == 2
        ? const CreatePostPage()
        : _pages[_selectedIndex],
    bottomNavigationBar: BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.deepPurple[800],
      unselectedItemColor: Colors.grey[600],
      currentIndex: _selectedIndex,
      onTap: _onBottomNavTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
        BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 40), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
      ],
    ),
  );
}

Widget _buildHomeContent() {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What Would You Like\nTo Make Today?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Posts For You',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<Post>>(
            stream: _postService.getAllPosts(),
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
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple[800],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
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
                        'Be the first to share a recipe!',
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
          ),
        ),
      ],
    ),
  );
}


  Future<String> _getUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'User';

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data() != null) {
      return doc['username'] ?? 'User';
    } else {
      return 'User';
    }
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

  void _handleComment(Post post) {
    // TODO: Implement comment functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comment feature coming soon!'),
      ),
    );
  }
}
