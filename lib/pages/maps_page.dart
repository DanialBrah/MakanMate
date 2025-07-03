import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import '../models/location_model.dart';

class MapsPage extends StatefulWidget {
  const MapsPage({super.key});

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  List<Location> _locations = [];
  Location? _selectedLocation;
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
    _loadLocations();
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

  Future<void> _loadLocations() async {
    try {
      List<Location> locations;

      if (_userRole == 'Restaurant Owner') {
        // Load owner's locations from Firestore
        locations = await _getOwnerLocations();
      } else {
        // Load all locations for normal users
        locations = await _getAllLocations();
      }

      setState(() {
        _locations = locations;
        _isLoading = false;
      });
      _createMarkers();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading locations: $e');
    }
  }

  Future<List<Location>> _getOwnerLocations() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('locations')
          .where('ownerId', isEqualTo: _userId)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Location.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting owner locations: $e');
      return [];
    }
  }

  Future<List<Location>> _getAllLocations() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('locations').get();

      List<Location> locations = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Location.fromMap(data);
      }).toList();

      // Add sample locations if collection is empty
      if (locations.isEmpty) {
        locations = await _getSampleLocations();
      }

      return locations;
    } catch (e) {
      print('Error getting all locations: $e');
      return await _getSampleLocations();
    }
  }

  Future<List<Location>> _getSampleLocations() async {
    return [
      Location(
        id: '1',
        name: 'Nasi Lemak Wanjo',
        address: 'Kampung Baru, Kuala Lumpur',
        latitude: 3.1589,
        longitude: 101.6942,
        phoneNumber: '+60 3-2691 3317',
      ),
      Location(
        id: '2',
        name: 'Jalan Alor Food Street',
        address: 'Jalan Alor, Bukit Bintang, Kuala Lumpur',
        latitude: 3.1472,
        longitude: 101.7107,
        phoneNumber: '+60 12-345 6789',
      ),
      Location(
        id: '3',
        name: 'Hutong Food Court',
        address: 'Lot 10, Bukit Bintang, Kuala Lumpur',
        latitude: 3.1478,
        longitude: 101.7118,
        phoneNumber: '+60 3-2143 8080',
      ),
      Location(
        id: '4',
        name: 'Restoran Yut Kee',
        address: 'Jalan Kamunting, Kuala Lumpur',
        latitude: 3.1569,
        longitude: 101.6851,
        phoneNumber: '+60 3-2698 8108',
      ),
      Location(
        id: '5',
        name: 'Village Park Restaurant',
        address: 'Damansara Uptown, Petaling Jaya',
        latitude: 3.1319,
        longitude: 101.6261,
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

    // Add location markers
    for (Location location in _locations) {
      markers.add(
        Marker(
          markerId: MarkerId(location.id),
          position: LatLng(location.latitude, location.longitude),
          infoWindow: InfoWindow(
            title: location.name,
            snippet: location.address,
          ),
          onTap: () {
            if (_userRole == 'Restaurant Owner') {
              _showOwnerLocationOptions(location);
            } else {
              _showLocationDetails(location);
            }
          },
        ),
      );
    }

    // Add temporary location marker for location owners setting location
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

  void _showLocationDetails(Location location) {
    setState(() {
      _selectedLocation = location;
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
                    child: _buildLocationCard(location),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showOwnerLocationOptions(Location location) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              location.name,
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
                _startLocationSetting(location);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Details'),
              onTap: () {
                Navigator.pop(context);
                _showEditLocationDialog(location);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startLocationSetting(Location? location) {
    setState(() {
      _isSettingLocation = true;
      _tempLocationForSetting = location != null
          ? LatLng(location.latitude, location.longitude)
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

  void _confirmLocationSetting(Location? location) {
    if (_tempLocationForSetting == null) return;

    if (location != null) {
      _updateLocationLocation(location, _tempLocationForSetting!);
    } else {
      _showNewLocationDialog(_tempLocationForSetting!);
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

  Future<void> _updateLocationLocation(
      Location location, LatLng newLocation) async {
    try {
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(location.id)
          .update({
        'latitude': newLocation.latitude,
        'longitude': newLocation.longitude,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location updated successfully')),
      );

      _loadLocations(); // Reload to show updated location
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating location: $e')),
      );
    }
  }

  void _showNewLocationDialog(LatLng location) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Location Name'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
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
                _saveNewLocation(
                  nameController.text,
                  addressController.text,
                  location,
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

  Future<void> _saveNewLocation(
    String name,
    String address,
    LatLng location,
    String phoneNumber,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('locations').add({
        'name': name,
        'address': address,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'phoneNumber': phoneNumber,
        'ownerId': _userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location added successfully')),
      );

      _loadLocations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding location: $e')),
      );
    }
  }

  void _showEditLocationDialog(Location location) {
    final nameController = TextEditingController(text: location.name);
    final addressController = TextEditingController(text: location.address);
    final phoneController = TextEditingController(text: location.phoneNumber);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Location Name'),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
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
              _updateLocationDetails(location, nameController.text,
                  addressController.text, phoneController.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateLocationDetails(
    Location location,
    String name,
    String address,
    String phone,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(location.id)
          .update({
        'name': name,
        'address': address,
        'phoneNumber': phone,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location updated successfully')),
      );

      _loadLocations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating location: $e')),
      );
    }
  }

  // Enhanced navigation functionality
  Future<void> _getDirections(Location location) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current location not available. Please enable GPS.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _showNavigationOptions(location);
  }

  Future<void> _showNavigationOptions(Location location) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Get Directions to ${location.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Google Maps option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.map, color: Colors.green),
              ),
              title: const Text('Google Maps'),
              subtitle: const Text('Navigate with Google Maps'),
              onTap: () {
                Navigator.pop(context);
                _openGoogleMaps(location);
              },
            ),

            // Apple Maps option (iOS only)
            if (Platform.isIOS)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map_outlined, color: Colors.blue),
                ),
                title: const Text('Apple Maps'),
                subtitle: const Text('Navigate with Apple Maps'),
                onTap: () {
                  Navigator.pop(context);
                  _openAppleMaps(location);
                },
              ),

            // Waze option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.navigation, color: Colors.orange),
              ),
              title: const Text('Waze'),
              subtitle: const Text('Navigate with Waze'),
              onTap: () {
                Navigator.pop(context);
                _openWaze(location);
              },
            ),

            // Generic maps option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.open_in_new, color: Colors.purple),
              ),
              title: const Text('Other Maps App'),
              subtitle: const Text('Open with default maps app'),
              onTap: () {
                Navigator.pop(context);
                _openDefaultMaps(location);
              },
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _openGoogleMaps(Location location) async {
    final url = Platform.isIOS
        ? 'comgooglemaps://?saddr=${_currentPosition!.latitude},${_currentPosition!.longitude}&daddr=${location.latitude},${location.longitude}&directionsmode=driving'
        : 'google.navigation:q=${location.latitude},${location.longitude}&mode=d';

    final fallbackUrl =
        'https://www.google.com/maps/dir/?api=1&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}&destination=${location.latitude},${location.longitude}&travelmode=driving';

    try {
      bool launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await launchUrl(
          Uri.parse(fallbackUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open Google Maps: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openAppleMaps(Location location) async {
    final url =
        'http://maps.apple.com/?saddr=${_currentPosition!.latitude},${_currentPosition!.longitude}&daddr=${location.latitude},${location.longitude}&dirflg=d';

    try {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open Apple Maps: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openWaze(Location location) async {
    final url =
        'waze://?ll=${location.latitude},${location.longitude}&navigate=yes';
    final fallbackUrl =
        'https://waze.com/ul?ll=${location.latitude},${location.longitude}&navigate=yes';

    try {
      bool launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await launchUrl(
          Uri.parse(fallbackUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open Waze: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openDefaultMaps(Location location) async {
    final url = Platform.isIOS
        ? 'http://maps.apple.com/?q=${location.latitude},${location.longitude}'
        : 'geo:${location.latitude},${location.longitude}?q=${location.latitude},${location.longitude}(${Uri.encodeComponent(location.name)})';

    try {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open maps: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _callLocation(Location location) async {
    final url = 'tel:${location.phoneNumber}';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not make phone call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error making phone call: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Calculate distance between current location and target location
  String _calculateDistance(Location location) {
    if (_currentPosition == null) return 'N/A';

    double distanceInMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      location.latitude,
      location.longitude,
    );

    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  Widget _buildLocationCard(Location location) {
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
                        location.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _calculateDistance(location),
                          style: TextStyle(
                            color: Colors.green[800],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                const Text('4.5'),
                const SizedBox(width: 16),
                Icon(Icons.attach_money, color: Colors.green, size: 20),
                const SizedBox(width: 4),
                const Text('RM 10-20'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.red, size: 20),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location.address,
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
                const Text('9:00 AM - 10:00 PM'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, color: Colors.green, size: 20),
                const SizedBox(width: 4),
                Text(
                  location.phoneNumber,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _getDirections(location),
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
                    onPressed: () => _callLocation(location),
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
                  onPressed: () => _viewFullDetails(location),
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

  void _viewFullDetails(Location location) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationDetailPage(
          location: location,
          currentPosition: _currentPosition,
        ),
      ),
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
              _loadLocations();
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
                          hintText: 'Search locations...',
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
                          _searchLocations(value);
                        },
                      ),
                    ),
                  ),

                // Legend overlay
                Positioned(
                  bottom: _selectedLocation != null ? 140 : 20,
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
                            const Text('Restaurants',
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
                            const Text('Your Location',
                                style: TextStyle(fontSize: 12)),
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

                // Info panel for selected location
                if (_selectedLocation != null && !_isSettingLocation)
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
                            child: const Icon(
                              Icons.restaurant,
                              color: Colors.deepPurple,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedLocation!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  _selectedLocation!.address,
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
                                    const SizedBox(width: 4),
                                    const Text('4.5'),
                                    const SizedBox(width: 8),
                                    Text(
                                      _calculateDistance(_selectedLocation!),
                                      style: TextStyle(
                                        color: Colors.green[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
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
                                _selectedLocation = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                // Zoom in/out buttons
                Positioned(
                  bottom: 90,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'zoom_in',
                        mini: true,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.add, color: Colors.deepPurple),
                        onPressed: () async {
                          if (_mapController != null) {
                            final currentZoom =
                                await _mapController!.getZoomLevel();
                            _mapController!.animateCamera(
                              CameraUpdate.zoomTo(currentZoom + 1),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton(
                        heroTag: 'zoom_out',
                        mini: true,
                        backgroundColor: Colors.white,
                        child:
                            const Icon(Icons.remove, color: Colors.deepPurple),
                        onPressed: () async {
                          if (_mapController != null) {
                            final currentZoom =
                                await _mapController!.getZoomLevel();
                            _mapController!.animateCamera(
                              CameraUpdate.zoomTo(currentZoom - 1),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _searchLocations(String query) {
    if (query.isEmpty) return;

    final filteredLocations = _locations.where((location) {
      return location.name.toLowerCase().contains(query.toLowerCase()) ||
          location.address.toLowerCase().contains(query.toLowerCase());
    }).toList();

    if (filteredLocations.isNotEmpty) {
      final location = filteredLocations.first;
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(location.latitude, location.longitude),
            16,
          ),
        );
        _showLocationDetails(location);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No locations found for "$query"')),
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

// Enhanced Location Detail Page with Navigation Features
class LocationDetailPage extends StatelessWidget {
  final Location location;
  final Position? currentPosition;

  const LocationDetailPage({
    super.key,
    required this.location,
    this.currentPosition,
  });

  String _calculateDistance() {
    if (currentPosition == null) return 'N/A';

    double distanceInMeters = Geolocator.distanceBetween(
      currentPosition!.latitude,
      currentPosition!.longitude,
      location.latitude,
      location.longitude,
    );

    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  Future<void> _getDirections(BuildContext context) async {
    if (currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current location not available. Please enable GPS.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _showNavigationOptions(context);
  }

  Future<void> _showNavigationOptions(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Get Directions to ${location.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Google Maps option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.map, color: Colors.green),
              ),
              title: const Text('Google Maps'),
              subtitle: const Text('Navigate with Google Maps'),
              onTap: () {
                Navigator.pop(context);
                _openGoogleMaps();
              },
            ),

            // Apple Maps option (iOS only)
            if (Platform.isIOS)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map_outlined, color: Colors.blue),
                ),
                title: const Text('Apple Maps'),
                subtitle: const Text('Navigate with Apple Maps'),
                onTap: () {
                  Navigator.pop(context);
                  _openAppleMaps();
                },
              ),

            // Waze option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.navigation, color: Colors.orange),
              ),
              title: const Text('Waze'),
              subtitle: const Text('Navigate with Waze'),
              onTap: () {
                Navigator.pop(context);
                _openWaze();
              },
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _openGoogleMaps() async {
    final url = Platform.isIOS
        ? 'comgooglemaps://?saddr=${currentPosition!.latitude},${currentPosition!.longitude}&daddr=${location.latitude},${location.longitude}&directionsmode=driving'
        : 'google.navigation:q=${location.latitude},${location.longitude}&mode=d';

    final fallbackUrl =
        'https://www.google.com/maps/dir/?api=1&origin=${currentPosition!.latitude},${currentPosition!.longitude}&destination=${location.latitude},${location.longitude}&travelmode=driving';

    try {
      bool launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await launchUrl(
          Uri.parse(fallbackUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      print('Could not open Google Maps: $e');
    }
  }

  Future<void> _openAppleMaps() async {
    final url =
        'http://maps.apple.com/?saddr=${currentPosition!.latitude},${currentPosition!.longitude}&daddr=${location.latitude},${location.longitude}&dirflg=d';

    try {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      print('Could not open Apple Maps: $e');
    }
  }

  Future<void> _openWaze() async {
    final url =
        'waze://?ll=${location.latitude},${location.longitude}&navigate=yes';
    final fallbackUrl =
        'https://waze.com/ul?ll=${location.latitude},${location.longitude}&navigate=yes';

    try {
      bool launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await launchUrl(
          Uri.parse(fallbackUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      print('Could not open Waze: $e');
    }
  }

  Future<void> _callLocation() async {
    final url = 'tel:${location.phoneNumber}';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      print('Error making phone call: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(location.name),
        backgroundColor: Colors.deepPurple[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location Image Placeholder
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.restaurant,
                size: 80,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            // Location Info
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
                            location.name,
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
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _calculateDistance(),
                            style: TextStyle(
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 24),
                        const SizedBox(width: 4),
                        const Text('4.5 (123 reviews)'),
                        const SizedBox(width: 16),
                        Icon(Icons.attach_money, color: Colors.green, size: 24),
                        const SizedBox(width: 4),
                        const Text('RM 10-20'),
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
                            location.address,
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
                          location.phoneNumber,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '9:00 AM - 10:00 PM',
                          style: TextStyle(fontSize: 16),
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
                    onPressed: () => _getDirections(context),
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
                    onPressed: _callLocation,
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
