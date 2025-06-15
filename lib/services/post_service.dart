import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/post_model.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create a new post
  Future<String> createPost(Post post, {File? imageFile}) async {
    try {
      String? imageUrl;

      // Upload image if provided
      if (imageFile != null) {
        imageUrl = await _uploadImage(imageFile, post.userId);
      }

      // Create post with image URL
      final postWithImage = post.copyWith(imageUrl: imageUrl);

      // Add post to Firestore
      final docRef =
          await _firestore.collection('posts').add(postWithImage.toMap());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  // Upload image to Firebase Storage
  Future<String> _uploadImage(File imageFile, String userId) async {
    try {
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('post_images').child(fileName);

      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Get all posts (ordered by creation date, newest first)
  Stream<List<Post>> getAllPosts() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Post.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

// Get posts by user (without ordering to avoid index requirement)
  Stream<List<Post>> getUserPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      List<Post> posts = snapshot.docs.map((doc) {
        return Post.fromMap(doc.data(), doc.id);
      }).toList();

      // Sort in memory instead of in the query
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return posts;
    });
  }

  // Toggle like on a post
  Future<void> toggleLike(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);

        if (!postDoc.exists) {
          throw Exception('Post not found');
        }

        final post = Post.fromMap(postDoc.data()!, postDoc.id);
        List<String> likes = List.from(post.likes);

        if (likes.contains(userId)) {
          likes.remove(userId); // Unlike
        } else {
          likes.add(userId); // Like
        }

        transaction.update(postRef, {'likes': likes});
      });
    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }

  // Add comment to post
  Future<void> addComment(String postId, Comment comment) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);

      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);

        if (!postDoc.exists) {
          throw Exception('Post not found');
        }

        final post = Post.fromMap(postDoc.data()!, postDoc.id);
        List<Comment> comments = List.from(post.comments);
        comments.add(comment);

        transaction.update(
            postRef, {'comments': comments.map((c) => c.toMap()).toList()});
      });
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  // Delete post
  Future<void> deletePost(String postId, String userId) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final postDoc = await postRef.get();

      if (!postDoc.exists) {
        throw Exception('Post not found');
      }

      final post = Post.fromMap(postDoc.data()!, postDoc.id);

      // Check if user owns the post
      if (post.userId != userId) {
        throw Exception('Unauthorized to delete this post');
      }

      // Delete image from storage if exists
      if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(post.imageUrl!);
          await ref.delete();
        } catch (e) {
          // Image deletion failed, but continue with post deletion
          print('Failed to delete image: $e');
        }
      }

      // Delete post document
      await postRef.delete();
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  // Update post
  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('posts').doc(postId).update(updates);
    } catch (e) {
      throw Exception('Failed to update post: $e');
    }
  }

  // Search posts by food name or restaurant
  Stream<List<Post>> searchPosts(String query) {
    return _firestore
        .collection('posts')
        .where('foodName', isGreaterThanOrEqualTo: query)
        .where('foodName', isLessThanOrEqualTo: query + '\uf8ff')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Post.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Get posts by tag
  Stream<List<Post>> getPostsByTag(String tag) {
    return _firestore
        .collection('posts')
        .where('tags', arrayContains: tag)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Post.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }


  // OR if you want a separate implementation:
  Stream<List<Post>> getPostsByUserId(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      List<Post> posts = snapshot.docs.map((doc) {
        return Post.fromMap(doc.data(), doc.id);
      }).toList();

      // Sort in memory instead of in the query
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return posts;
    });
  }

  // Get a single post stream
  Stream<Post> getPostStream(String postId) {
    return _firestore.collection('posts').doc(postId).snapshots().map((doc) {
      if (doc.exists) {
        return Post.fromMap(doc.data()!, doc.id);
      }
      throw Exception('Post not found');
    });
  }

  Future<void> deleteComment(String postId, String commentId) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final post = await postRef.get();

      if (!post.exists) return;

      List<Map<String, dynamic>> comments =
          List<Map<String, dynamic>>.from(post.data()?['comments'] ?? []);

      comments.removeWhere((comment) => comment['id'] == commentId);

      await postRef.update({
        'comments': comments,
      });
    } catch (e) {
      print('Error deleting comment: $e');
      rethrow;
    }
  }

  Future<void> updateComment(String postId, Comment updatedComment) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final post = await postRef.get();

      if (!post.exists) return;

      List<Map<String, dynamic>> comments =
          List<Map<String, dynamic>>.from(post.data()?['comments'] ?? []);

      final index =
          comments.indexWhere((comment) => comment['id'] == updatedComment.id);
      if (index != -1) {
        comments[index] = updatedComment.toMap();

        await postRef.update({
          'comments': comments,
        });
      }
    } catch (e) {
      print('Error updating comment: $e');
      rethrow;
    }
  }
}
