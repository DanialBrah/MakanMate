// services/location_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';

class LocationService {
  static const String _collectionName = 'locations';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get reference to locations collection
  CollectionReference get _locationsCollection =>
      _firestore.collection(_collectionName);

  // Add a new location
  Future<String> addLocation(Location location) async {
    try {
      DocumentReference docRef =
          await _locationsCollection.add(location.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add location: $e');
    }
  }

  // Get all locations
  Future<List<Location>> getAllLocations() async {
    try {
      QuerySnapshot querySnapshot = await _locationsCollection
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Location.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get locations: $e');
    }
  }

  // Get locations stream for real-time updates
  Stream<List<Location>> getLocationsStream() {
    return _locationsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Location.fromFirestore(doc)).toList());
  }

  // Get location by ID
  Future<Location?> getLocationById(String id) async {
    try {
      DocumentSnapshot doc = await _locationsCollection.doc(id).get();
      if (doc.exists) {
        return Location.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get location: $e');
    }
  }

  // Update location
  Future<void> updateLocation(String id, Location location) async {
    try {
      await _locationsCollection.doc(id).update(
            location.copyWith(updatedAt: DateTime.now()).toMap(),
          );
    } catch (e) {
      throw Exception('Failed to update location: $e');
    }
  }

  // Delete location
  Future<void> deleteLocation(String id) async {
    try {
      await _locationsCollection.doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete location: $e');
    }
  }

  // Get locations within a radius (for map functionality)
  Future<List<Location>> getLocationsNear({
    required double latitude,
    required double longitude,
    required double radiusInKm,
  }) async {
    try {
      List<Location> allLocations = await getAllLocations();

      return allLocations.where((location) {
        double distance = _calculateDistance(
          latitude,
          longitude,
          location.latitude,
          location.longitude,
        );
        return distance <= radiusInKm;
      }).toList();
    } catch (e) {
      throw Exception('Failed to get nearby locations: $e');
    }
  }

  // Helper method to calculate distance between two points
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double p = pi / 180;
    double a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}
