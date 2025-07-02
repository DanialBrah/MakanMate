import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/restaurant.dart';

class MapsPage extends StatefulWidget {
  const MapsPage({super.key});

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  List<Restaurant> _restaurants = [];
  Restaurant? _selectedRestaurant;
  bool _isLoading = true;
  String _mapStyle = '';
  String _userRole = '';
  String _userId = '';
  bool _isSettingLocation = false;
  LatLng? _tempLocationForSetting;

  // Default location (Kuala Lumpur, Malaysia)
  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(3.139, 101.6869),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _getCurrentUser();
    _getCurrentLocation();
    _loadRestaurants();
  }

  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;

      // Get user role from Firestore
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _userRole = userDoc.data()?['role'] ?? 'user';
          });
        }
      } catch (e) {
        print('Error getting user role: $e');
        setState(() {
          _userRole = 'user'; // Default to user role
        });
      }
    }
  }

  Future<void> _loadMapStyle() async {
    _mapStyle = '''
    [
      {
        "featureType": "poi",
        "elementType": "labels",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      }
    ]
    ''';
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied'),
          ),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ),
        );
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _loadRestaurants() async {
    try {
      List<Restaurant> restaurants;

      if (_userRole == 'Restaurant Owner') {
        // Load owner's restaurants from Firestore
        restaurants = await _getOwnerRestaurants();
      } else {
        // Load all restaurants for normal users
        restaurants = await _getAllRestaurants();
      }

      setState(() {
        _restaurants = restaurants;
        _isLoading = false;
      });
      _createMarkers();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading restaurants: $e');
    }
  }

  Future<List<Restaurant>> _getOwnerRestaurants() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('restaurants')
          .where('ownerId', isEqualTo: _userId)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Restaurant.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting owner restaurants: $e');
      return [];
    }
  }

  Future<List<Restaurant>> _getAllRestaurants() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('restaurants').get();

      List<Restaurant> restaurants = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Restaurant.fromMap(data);
      }).toList();

      // Add sample restaurants if collection is empty
      if (restaurants.isEmpty) {
        restaurants = await _getSampleRestaurants();
      }

      return restaurants;
    } catch (e) {
      print('Error getting all restaurants: $e');
      return await _getSampleRestaurants();
    }
  }

  Future<List<Restaurant>> _getSampleRestaurants() async {
    return [
      Restaurant(
        id: '1',
        name: 'Nasi Lemak Wanjo',
        address: 'Kampung Baru, Kuala Lumpur',
        latitude: 3.1516,
        longitude: 101.6942,
        cuisine: 'Malaysian',
        rating: 4.5,
        priceRange: 'RM 5-15',
        isOpen: true,
        openingHours: '7:00 AM - 3:00 PM',
        phoneNumber: '+60 3-2691 3317',
      ),
      Restaurant(
        id: '2',
        name: 'Jalan Alor Food Street',
        address: 'Jalan Alor, Bukit Bintang, Kuala Lumpur',
        latitude: 3.1472,
        longitude: 101.7107,
        cuisine: 'Street Food',
        rating: 4.2,
        priceRange: 'RM 8-25',
        isOpen: true,
        openingHours: '6:00 PM - 4:00 AM',
        phoneNumber: '+60 12-345 6789',
      ),
      Restaurant(
        id: '3',
        name: 'Hutong Food Court',
        address: 'Lot 10, Bukit Bintang, Kuala Lumpur',
        latitude: 3.1478,
        longitude: 101.7118,
        cuisine: 'Food Court',
        rating: 4.0,
        priceRange: 'RM 6-20',
        isOpen: true,
        openingHours: '10:00 AM - 10:00 PM',
        phoneNumber: '+60 3-2143 8080',
      ),
      Restaurant(
        id: '4',
        name: 'Restoran Yut Kee',
        address: 'Jalan Kamunting, Kuala Lumpur',
        latitude: 3.1569,
        longitude: 101.6851,
        cuisine: 'Hainanese',
        rating: 4.3,
        priceRange: 'RM 8-18',
        isOpen: true,
        openingHours: '8:00 AM - 4:30 PM',
        phoneNumber: '+60 3-2698 8108',
      ),
      Restaurant(
        id: '5',
        name: 'Village Park Restaurant',
        address: 'Damansara Uptown, Petaling Jaya',
        latitude: 3.1319,
        longitude: 101.6261,
        cuisine: 'Malaysian Chinese',
        rating: 4.1,
        priceRange: 'RM 12-30',
        isOpen: false,
        openingHours: '11:00 AM - 3:00 AM',
        phoneNumber: '+60 3-7726 3022',
      ),
    ];
  }

  Future<void> _createMarkers() async {
    Set<Marker> markers = {};

    // Add current location marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'You are here',
          ),
        ),
      );
    }

    // Add restaurant markers
    for (Restaurant restaurant in _restaurants) {
      markers.add(
        Marker(
          markerId: MarkerId(restaurant.id),
          position: LatLng(restaurant.latitude, restaurant.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            restaurant.isOpen
                ? BitmapDescriptor.hueRed
                : BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: restaurant.name,
            snippet: '${restaurant.cuisine} • ${restaurant.priceRange}',
          ),
          onTap: () {
            if (_userRole == 'Restaurant Owner') {
              _showOwnerRestaurantOptions(restaurant);
            } else {
              _showRestaurantDetails(restaurant);
            }
          },
        ),
      );
    }

    // Add temporary location marker for restaurant owners setting location
    if (_tempLocationForSetting != null && _isSettingLocation) {
      markers.add(
        Marker(
          markerId: const MarkerId('temp_location'),
          position: _tempLocationForSetting!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(
            title: 'New Restaurant Location',
            snippet: 'Tap to confirm',
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _showRestaurantDetails(Restaurant restaurant) {
    setState(() {
      _selectedRestaurant = restaurant;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.8,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: _buildRestaurantCard(restaurant),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showOwnerRestaurantOptions(Restaurant restaurant) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              restaurant.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_location),
              title: const Text('Update Location'),
              onTap: () {
                Navigator.pop(context);
                _startLocationSetting(restaurant);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Details'),
              onTap: () {
                Navigator.pop(context);
                _showEditRestaurantDialog(restaurant);
              },
            ),
            ListTile(
              leading: Icon(
                restaurant.isOpen ? Icons.store : Icons.store_mall_directory,
                color: restaurant.isOpen ? Colors.green : Colors.red,
              ),
              title:
                  Text(restaurant.isOpen ? 'Mark as Closed' : 'Mark as Open'),
              onTap: () {
                Navigator.pop(context);
                _toggleRestaurantStatus(restaurant);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startLocationSetting(Restaurant? restaurant) {
    setState(() {
      _isSettingLocation = true;
      _tempLocationForSetting = restaurant != null
          ? LatLng(restaurant.latitude, restaurant.longitude)
          : _currentPosition != null
              ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
              : const LatLng(3.139, 101.6869);
    });
    _createMarkers();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap on the map to set restaurant location'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _confirmLocationSetting(Restaurant? restaurant) {
    if (_tempLocationForSetting == null) return;

    if (restaurant != null) {
      _updateRestaurantLocation(restaurant, _tempLocationForSetting!);
    } else {
      _showNewRestaurantDialog(_tempLocationForSetting!);
    }

    setState(() {
      _isSettingLocation = false;
      _tempLocationForSetting = null;
    });
    _createMarkers();
  }

  void _cancelLocationSetting() {
    setState(() {
      _isSettingLocation = false;
      _tempLocationForSetting = null;
    });
    _createMarkers();
  }

  Future<void> _updateRestaurantLocation(
      Restaurant restaurant, LatLng newLocation) async {
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurant.id)
          .update({
        'latitude': newLocation.latitude,
        'longitude': newLocation.longitude,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Restaurant location updated successfully')),
      );

      _loadRestaurants(); // Reload to show updated location
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating location: $e')),
      );
    }
  }

  void _showNewRestaurantDialog(LatLng location) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final cuisineController = TextEditingController();
    final priceRangeController = TextEditingController();
    final openingHoursController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Restaurant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Restaurant Name'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextField(
                controller: cuisineController,
                decoration: const InputDecoration(labelText: 'Cuisine Type'),
              ),
              TextField(
                controller: priceRangeController,
                decoration: const InputDecoration(
                    labelText: 'Price Range (e.g., RM 10-30)'),
              ),
              TextField(
                controller: openingHoursController,
                decoration: const InputDecoration(labelText: 'Opening Hours'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _saveNewRestaurant(
                  location,
                  nameController.text,
                  addressController.text,
                  cuisineController.text,
                  priceRangeController.text,
                  openingHoursController.text,
                  phoneController.text,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNewRestaurant(
    LatLng location,
    String name,
    String address,
    String cuisine,
    String priceRange,
    String openingHours,
    String phone,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('restaurants').add({
        'name': name,
        'address': address,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'cuisine': cuisine,
        'rating': 0.0,
        'priceRange': priceRange,
        'isOpen': true,
        'openingHours': openingHours,
        'phoneNumber': phone,
        'ownerId': _userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restaurant added successfully')),
      );

      _loadRestaurants();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding restaurant: $e')),
      );
    }
  }

  void _showEditRestaurantDialog(Restaurant restaurant) {
    final nameController = TextEditingController(text: restaurant.name);
    final addressController = TextEditingController(text: restaurant.address);
    final cuisineController = TextEditingController(text: restaurant.cuisine);
    final priceRangeController =
        TextEditingController(text: restaurant.priceRange);
    final openingHoursController =
        TextEditingController(text: restaurant.openingHours);
    final phoneController = TextEditingController(text: restaurant.phoneNumber);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Restaurant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Restaurant Name'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextField(
                controller: cuisineController,
                decoration: const InputDecoration(labelText: 'Cuisine Type'),
              ),
              TextField(
                controller: priceRangeController,
                decoration: const InputDecoration(labelText: 'Price Range'),
              ),
              TextField(
                controller: openingHoursController,
                decoration: const InputDecoration(labelText: 'Opening Hours'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateRestaurantDetails(
                restaurant,
                nameController.text,
                addressController.text,
                cuisineController.text,
                priceRangeController.text,
                openingHoursController.text,
                phoneController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateRestaurantDetails(
    Restaurant restaurant,
    String name,
    String address,
    String cuisine,
    String priceRange,
    String openingHours,
    String phone,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurant.id)
          .update({
        'name': name,
        'address': address,
        'cuisine': cuisine,
        'priceRange': priceRange,
        'openingHours': openingHours,
        'phoneNumber': phone,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restaurant updated successfully')),
      );

      _loadRestaurants();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating restaurant: $e')),
      );
    }
  }

  Future<void> _toggleRestaurantStatus(Restaurant restaurant) async {
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(restaurant.id)
          .update({
        'isOpen': !restaurant.isOpen,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restaurant marked as ${!restaurant.isOpen ? 'open' : 'closed'}',
          ),
        ),
      );

      _loadRestaurants();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating restaurant status: $e')),
      );
    }
  }

  Widget _buildRestaurantCard(Restaurant restaurant) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        restaurant.cuisine,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.deepPurple[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: restaurant.isOpen ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    restaurant.isOpen ? 'OPEN' : 'CLOSED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  restaurant.rating.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Icon(Icons.attach_money, color: Colors.green, size: 20),
                Text(
                  restaurant.priceRange,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.red, size: 20),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    restaurant.address,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.blue, size: 20),
                const SizedBox(width: 4),
                Text(
                  restaurant.openingHours,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, color: Colors.green, size: 20),
                const SizedBox(width: 4),
                Text(
                  restaurant.phoneNumber,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _getDirections(restaurant),
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple[800],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callRestaurant(restaurant),
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (_userRole != 'Restaurant Owner') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _viewFullDetails(restaurant),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('View Full Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _viewFullDetails(Restaurant restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantDetailPage(restaurant: restaurant),
      ),
    );
  }

  void _getDirections(Restaurant restaurant) {
    // Implement directions functionality using url_launcher
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Getting directions to ${restaurant.name}...')),
    );
  }

  void _callRestaurant(Restaurant restaurant) {
    // Implement call functionality using url_launcher
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling ${restaurant.name}...')),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    controller.setMapStyle(_mapStyle);

    if (_currentPosition != null) {
      controller.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    }
  }

  void _onMapTap(LatLng location) {
    if (_isSettingLocation) {
      setState(() {
        _tempLocationForSetting = location;
      });
      _createMarkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _userRole == 'Restaurant Owner' ? 'My Restaurants' : 'Restaurant Map',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_userRole == 'Restaurant Owner' && !_isSettingLocation)
            IconButton(
              icon: const Icon(Icons.add_location, color: Colors.black),
              onPressed: () => _startLocationSetting(null),
              tooltip: 'Add restaurant location',
            ),
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.black),
            onPressed: _getCurrentLocation,
            tooltip: 'Get current location',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              _loadRestaurants();
              _getCurrentLocation();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading map...'),
                ],
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  onTap: _onMapTap,
                  initialCameraPosition: _currentPosition != null
                      ? CameraPosition(
                          target: LatLng(_currentPosition!.latitude,
                              _currentPosition!.longitude),
                          zoom: 14,
                        )
                      : _defaultLocation,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                ),

                // Location setting controls for restaurant owners
                if (_isSettingLocation)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Setting Restaurant Location',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap on the map to set the location',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _confirmLocationSetting(null),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Confirm'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _cancelLocationSetting,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // Search bar overlay (only for normal users)
                if (_userRole != 'Restaurant Owner' && !_isSettingLocation)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search restaurants...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (value) {
                          _searchRestaurants(value);
                        },
                      ),
                    ),
                  ),

                // Legend overlay
                Positioned(
                  bottom: _selectedRestaurant != null ? 140 : 20,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Open', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('Closed',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('You', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        if (_isSettingLocation) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('New Location',
                                  style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Info panel for selected restaurant
                if (_selectedRestaurant != null && !_isSettingLocation)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.deepPurple[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.restaurant,
                              color: Colors.deepPurple[800],
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedRestaurant!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _selectedRestaurant!.address,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.star,
                                        color: Colors.amber, size: 16),
                                    Text(
                                      ' ${_selectedRestaurant!.rating}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedRestaurant!.priceRange,
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _selectedRestaurant!.isOpen
                                            ? Colors.green
                                            : Colors.red,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _selectedRestaurant!.isOpen
                                            ? 'OPEN'
                                            : 'CLOSED',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _selectedRestaurant = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _searchRestaurants(String query) {
    if (query.isEmpty) return;

    final filteredRestaurants = _restaurants.where((restaurant) {
      return restaurant.name.toLowerCase().contains(query.toLowerCase()) ||
          restaurant.address.toLowerCase().contains(query.toLowerCase()) ||
          restaurant.cuisine.toLowerCase().contains(query.toLowerCase());
    }).toList();

    if (filteredRestaurants.isNotEmpty) {
      final restaurant = filteredRestaurants.first;
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(restaurant.latitude, restaurant.longitude),
            16,
          ),
        );
        _showRestaurantDetails(restaurant);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No restaurants found for "$query"')),
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

// Separate page for detailed restaurant view (for normal users)
class RestaurantDetailPage extends StatelessWidget {
  final Restaurant restaurant;

  const RestaurantDetailPage({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(restaurant.name),
        backgroundColor: Colors.deepPurple[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant Image Placeholder
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.restaurant,
                size: 80,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Restaurant Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                restaurant.isOpen ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            restaurant.isOpen ? 'OPEN' : 'CLOSED',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      restaurant.cuisine,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.deepPurple[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 24),
                        const SizedBox(width: 4),
                        Text(
                          restaurant.rating.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.attach_money, color: Colors.green, size: 24),
                        Text(
                          restaurant.priceRange,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Contact Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            restaurant.address,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.phone, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          restaurant.phoneNumber,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          restaurant.openingHours,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Implement directions
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Get Directions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Implement call
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('Call Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Reviews Section (Placeholder)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reviews',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Reviews feature coming soon!',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
