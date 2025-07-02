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
import '../pages/create_menu_item_page.dart';
import '../pages/chatbot_page.dart';

class HomePage extends StatefulWidget {
  final String userRole;

  const HomePage({super.key, required this.userRole});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  final PostService _postService = PostService();
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;

  String _firestoreUsername = 'User';
  String _firestoreUserRole = 'Member'; // default role
  String? _userProfileUrl;
  int _selectedIndex = 0;

  // Filter state variables
  String _searchQuery = '';
  String _selectedLocation = '';
  double _minRating = 0.0;
  double _maxPrice = 200.0;
  List<String> _selectedTags = [];
  String _sortBy = 'newest'; // newest, oldest, rating, price
  bool _showOnlyLiked = false;

  // Manual input controllers
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  bool _useManualPrice = false;
  bool _useManualLocation = false;

  // Available filter options
  List<String> _availableLocations = [];
  List<String> _availableTags = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUsernameAndRoleFromFirestore();
  }

  void _onBottomNavTap(int index) {
    if (index == 2) {
      // Plus button index
      if (_firestoreUserRole == 'Restaurant Owner') {
        _showCreateOptionsDialog();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreatePostPage()),
        );
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUsernameAndRoleFromFirestore();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadUsernameAndRoleFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    print(user);
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _firestoreUsername = data['username'] ?? 'User';
          print("Firestore Username: $data['username']");
          _firestoreUserRole = data['role'] ?? 'Member';
          print("Firestore Role: $data['role']");
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      final posts = await _postService.getAllPosts().first;
      final locations = posts.map((post) => post.location).toSet().toList();
      final tags = posts.expand((post) => post.tags).toSet().toList();

      setState(() {
        _availableLocations = locations;
        _availableTags = tags;
      });
    } catch (e) {
      print('Error loading filter options: $e');
    }
  }

  // Get location recommendations based on available posts
  List<String> _getLocationRecommendations() {
    return _availableLocations.take(5).toList();
  }

  // Show filter popup dialog
  void _showFilterDialog() {
    // Create temporary variables to hold filter state
    String tempSelectedLocation = _selectedLocation;
    double tempMinRating = _minRating;
    double tempMaxPrice = _maxPrice;
    List<String> tempSelectedTags = List.from(_selectedTags);
    String tempSortBy = _sortBy;
    bool tempShowOnlyLiked = _showOnlyLiked;
    bool tempUseManualPrice = _useManualPrice;
    bool tempUseManualLocation = _useManualLocation;

    // Create temporary controllers
    TextEditingController tempLocationController =
        TextEditingController(text: _locationController.text);
    TextEditingController tempPriceController =
        TextEditingController(text: _priceController.text);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filters',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      setDialogState(() {
                        tempSelectedLocation = '';
                        tempMinRating = 0.0;
                        tempMaxPrice = 200.0;
                        tempSelectedTags.clear();
                        tempSortBy = 'newest';
                        tempShowOnlyLiked = false;
                        tempUseManualPrice = false;
                        tempUseManualLocation = false;
                        tempLocationController.clear();
                        tempPriceController.text = '200.0';
                      });
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location Filter with Manual Input Option
                      const Text('Location',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: tempUseManualLocation,
                            onChanged: (value) {
                              setDialogState(() {
                                tempUseManualLocation = value ?? false;
                                if (!tempUseManualLocation) {
                                  tempLocationController.clear();
                                }
                              });
                            },
                          ),
                          const Text('Custom location'),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (tempUseManualLocation)
                        TextField(
                          controller: tempLocationController,
                          decoration: const InputDecoration(
                            hintText: 'Enter location manually',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          onChanged: (value) {
                            setDialogState(() {});
                          },
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: tempSelectedLocation.isEmpty
                              ? null
                              : tempSelectedLocation,
                          decoration: const InputDecoration(
                            hintText: 'All locations',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: '', child: Text('All locations')),
                            ..._availableLocations.map((location) =>
                                DropdownMenuItem(
                                    value: location, child: Text(location))),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              tempSelectedLocation = value ?? '';
                            });
                          },
                        ),

                      // Location Recommendations
                      if (_getLocationRecommendations().isNotEmpty &&
                          !tempUseManualLocation)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            const Text('Popular locations:',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              children:
                                  _getLocationRecommendations().map((location) {
                                return ActionChip(
                                  label: Text(location,
                                      style: const TextStyle(fontSize: 11)),
                                  onPressed: () {
                                    setDialogState(() {
                                      tempSelectedLocation = location;
                                    });
                                  },
                                  backgroundColor: Colors.grey[100],
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),

                      // Rating Filter
                      const Text('Minimum Rating',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Slider(
                        value: tempMinRating,
                        min: 0.0,
                        max: 5.0,
                        divisions: 10,
                        label: tempMinRating.toStringAsFixed(1),
                        onChanged: (value) {
                          setDialogState(() {
                            tempMinRating = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Price Filter with Manual Input Option
                      const Text('Maximum Price',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: tempUseManualPrice,
                            onChanged: (value) {
                              setDialogState(() {
                                tempUseManualPrice = value ?? false;
                                if (!tempUseManualPrice) {
                                  tempPriceController.text =
                                      tempMaxPrice.toString();
                                }
                              });
                            },
                          ),
                          const Text('Custom price'),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (tempUseManualPrice)
                        TextField(
                          controller: tempPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Enter maximum price',
                            prefixText: 'RM ',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          onChanged: (value) {
                            setDialogState(() {});
                          },
                        )
                      else
                        Slider(
                          value: tempMaxPrice,
                          min: 0.0,
                          max: 200.0,
                          divisions: 40,
                          label: 'RM ${tempMaxPrice.toStringAsFixed(0)}',
                          onChanged: (value) {
                            setDialogState(() {
                              tempMaxPrice = value;
                              tempPriceController.text = value.toString();
                            });
                          },
                        ),
                      const SizedBox(height: 16),

                      // Tags Filter
                      const Text('Tags',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _availableTags.map((tag) {
                          final isSelected = tempSelectedTags.contains(tag);
                          return FilterChip(
                            label: Text(tag),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  tempSelectedTags.add(tag);
                                } else {
                                  tempSelectedTags.remove(tag);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Sort Options
                      const Text('Sort By',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: tempSortBy,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'newest', child: Text('Newest First')),
                          DropdownMenuItem(
                              value: 'oldest', child: Text('Oldest First')),
                          DropdownMenuItem(
                              value: 'rating', child: Text('Highest Rating')),
                          DropdownMenuItem(
                              value: 'price', child: Text('Lowest Price')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            tempSortBy = value ?? 'newest';
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Show Only Liked Posts
                      CheckboxListTile(
                        title: const Text('Show only liked posts'),
                        value: tempShowOnlyLiked,
                        onChanged: (value) {
                          setDialogState(() {
                            tempShowOnlyLiked = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Apply the temporary filter values to the actual state
                    setState(() {
                      _selectedLocation = tempSelectedLocation;
                      _minRating = tempMinRating;
                      _maxPrice = tempMaxPrice;
                      _selectedTags = tempSelectedTags;
                      _sortBy = tempSortBy;
                      _showOnlyLiked = tempShowOnlyLiked;
                      _useManualPrice = tempUseManualPrice;
                      _useManualLocation = tempUseManualLocation;
                      _locationController.text = tempLocationController.text;
                      _priceController.text = tempPriceController.text;
                    });
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple[800],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply Filters'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Clean up temporary controllers
      tempLocationController.dispose();
      tempPriceController.dispose();
    });
  }

  List<Post> _filterPosts(List<Post> posts) {
    List<Post> filteredPosts = posts;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filteredPosts = filteredPosts.where((post) {
        return post.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            post.foodName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            post.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            post.restaurantName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Location filter
    String locationToFilter = _useManualLocation
        ? _locationController.text.trim()
        : _selectedLocation;

    if (locationToFilter.isNotEmpty) {
      filteredPosts = filteredPosts
          .where((post) => post.location
              .toLowerCase()
              .contains(locationToFilter.toLowerCase()))
          .toList();
    }

    // Rating filter
    filteredPosts =
        filteredPosts.where((post) => post.rating >= _minRating).toList();

    // Price filter
    double priceToFilter = _useManualPrice
        ? (double.tryParse(_priceController.text) ?? _maxPrice)
        : _maxPrice;

    filteredPosts =
        filteredPosts.where((post) => post.price <= priceToFilter).toList();

    // Tags filter
    if (_selectedTags.isNotEmpty) {
      filteredPosts = filteredPosts.where((post) {
        return _selectedTags.any((tag) => post.tags.contains(tag));
      }).toList();
    }

    // Liked posts filter
    if (_showOnlyLiked) {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        filteredPosts = filteredPosts
            .where((post) => post.likes.contains(currentUserId))
            .toList();
      }
    }

    // Sort posts
    switch (_sortBy) {
      case 'newest':
        filteredPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'oldest':
        filteredPosts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'rating':
        filteredPosts.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'price':
        filteredPosts.sort((a, b) => a.price.compareTo(b.price));
        break;
    }

    return filteredPosts;
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedLocation = '';
      _minRating = 0.0;
      _maxPrice = 200.0;
      _selectedTags.clear();
      _sortBy = 'newest';
      _showOnlyLiked = false;
      _useManualPrice = false;
      _useManualLocation = false;
    });
    _locationController.clear();
    _priceController.text = '200.0';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final List<Widget> _pages = [
      _buildHomeContent(),
      const RestaurantSearchPage(),
      const SizedBox(),
      const ChatPageContent(),
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
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Posts',
          ),
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
                avatar: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.deepPurple[100],
                  backgroundImage: _userProfileUrl != null
                      ? NetworkImage(_userProfileUrl!)
                      : null,
                  child: _userProfileUrl == null
                      ? Text(
                          _firestoreUsername.isNotEmpty
                              ? _firestoreUsername[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
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
      body: _selectedIndex == 2 ? null : _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple[800],
        unselectedItemColor: Colors.grey[600],
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle, size: 40), label: ''),
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search posts, food, restaurants...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        // Posts Section
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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

                      final allPosts = snapshot.data ?? [];
                      final filteredPosts = _filterPosts(allPosts);

                      if (filteredPosts.isEmpty && allPosts.isNotEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No posts match your filters',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your search criteria',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _clearFilters,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple[800],
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Clear Filters'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (allPosts.isEmpty) {
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
                                      builder: (context) =>
                                          const CreatePostPage(),
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
                          await _loadFilterOptions();
                        },
                        child: ListView.builder(
                          itemCount: filteredPosts.length,
                          itemBuilder: (context, index) {
                            final post = filteredPosts[index];
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
          ),
        ),
      ],
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

  void _handleEdit(BuildContext context, Post post) {
    showDialog(
      context: context,
      builder: (context) => EditPostDialog(
        post: post,
        onPostUpdated: () {
          setState(() {});
        },
      ),
    );
  }

  Future<void> _handleDelete(String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _postService.deletePost(postId, currentUser.uid);
        print('Post deleted successfully');
      }
    } catch (e) {
      print('Error deleting post: $e');
    }
  }

  void _handleComment(Post post) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comment feature coming soon!'),
      ),
    );
  }

  // Show create options dialog
  void _showCreateOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Create New',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.post_add, color: Colors.deepPurple[800]),
                title: const Text('Create Post'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreatePostPage(),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading:
                    Icon(Icons.restaurant_menu, color: Colors.deepPurple[800]),
                title: const Text('Create Menu Item'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateMenuItemPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
