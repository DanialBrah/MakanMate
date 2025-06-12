import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String title;
  final String foodName;
  final String description;
  final double rating;
  final String? imageUrl; // Optional image
  final String location;
  final List<String> tags;
  final List<String> likes;
  final List<Comment> comments;
  final String restaurantName;
  final double price;
  final String userId;
  final String userName;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.title,
    required this.foodName,
    required this.description,
    required this.rating,
    this.imageUrl,
    required this.location,
    required this.tags,
    required this.likes,
    required this.comments,
    required this.restaurantName,
    required this.price,
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  // Convert Post to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'foodName': foodName,
      'description': description,
      'rating': rating,
      'imageUrl': imageUrl,
      'location': location,
      'tags': tags,
      'likes': likes,
      'comments': comments.map((comment) => comment.toMap()).toList(),
      'restaurantName': restaurantName,
      'price': price,
      'userId': userId,
      'userName': userName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create Post from Firestore document
  factory Post.fromMap(Map<String, dynamic> map, String documentId) {
    return Post(
      id: documentId,
      title: map['title'] ?? '',
      foodName: map['foodName'] ?? '',
      description: map['description'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      imageUrl: map['imageUrl'],
      location: map['location'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      likes: List<String>.from(map['likes'] ?? []),
      comments: (map['comments'] as List<dynamic>? ?? [])
          .map((commentMap) => Comment.fromMap(commentMap))
          .toList(),
      restaurantName: map['restaurantName'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Copy with method for updates
  Post copyWith({
    String? id,
    String? title,
    String? foodName,
    String? description,
    double? rating,
    String? imageUrl,
    String? location,
    List<String>? tags,
    List<String>? likes,
    List<Comment>? comments,
    String? restaurantName,
    double? price,
    String? userId,
    String? userName,
    DateTime? createdAt,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      foodName: foodName ?? this.foodName,
      description: description ?? this.description,
      rating: rating ?? this.rating,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      tags: tags ?? this.tags,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      restaurantName: restaurantName ?? this.restaurantName,
      price: price ?? this.price,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;
  final double? rating; // Make rating optional

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    this.rating, // Remove required keyword
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'rating': rating, // This will be null if not provided
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      content: map['content'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rating: map['rating']?.toDouble(), // Handle nullable rating
    );
  }
}
