import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Default location (Kuala Lumpur, Malaysia)
  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(3.139, 101.6869),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _getCurrentLocation();
    _loadRestaurants();
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
      // Load sample restaurants or from a separate restaurants collection
      List<Restaurant> restaurants = await _getSampleRestaurants();

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

  Future<List<Restaurant>> _getSampleRestaurants() async {
    // You can replace this with actual Firestore queries to a restaurants collection
    // or integrate with Google Places API for real restaurant data
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
            _showRestaurantDetails(restaurant);
          },
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
          ],
        ),
      ),
    );
  }

  void _getDirections(Restaurant restaurant) {
    // Implement directions functionality
    // You can use url_launcher to open Google Maps with directions
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Getting directions to ${restaurant.name}...')),
    );
  }

  void _callRestaurant(Restaurant restaurant) {
    // Implement call functionality
    // You can use url_launcher to make a phone call
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Restaurant Map',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
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

                // Search bar overlay
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
                      ],
                    ),
                  ),
                ),

                // Info panel for selected restaurant
                if (_selectedRestaurant != null)
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

// Restaurant model class
class Restaurant {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String cuisine;
  final double rating;
  final String priceRange;
  final bool isOpen;
  final String openingHours;
  final String phoneNumber;

  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.cuisine,
    required this.rating,
    required this.priceRange,
    required this.isOpen,
    required this.openingHours,
    required this.phoneNumber,
  });

  factory Restaurant.fromMap(Map<String, dynamic> map) {
    return Restaurant(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      cuisine: map['cuisine'] ?? '',
      rating: map['rating']?.toDouble() ?? 0.0,
      priceRange: map['priceRange'] ?? '',
      isOpen: map['isOpen'] ?? false,
      openingHours: map['openingHours'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'cuisine': cuisine,
      'rating': rating,
      'priceRange': priceRange,
      'isOpen': isOpen,
      'openingHours': openingHours,
      'phoneNumber': phoneNumber,
    };
  }
}
