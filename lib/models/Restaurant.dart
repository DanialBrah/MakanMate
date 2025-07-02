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
