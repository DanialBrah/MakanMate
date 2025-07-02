import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert'; // ✅ Needed for base64 encoding

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  String? _photoBase64; // More accurate name
  File? _newProfileImageFile;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _photoBase64 = user.photoBase64;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          _usernameController.text = data['username'] ?? '';
          // Load photoUrl from Firestore if it exists (this might be more up-to-date)
          _photoBase64 = data['photoBase64'] ?? _photoBase64;
        }
      }

      setState(() {}); // Refresh UI after loading photo URL
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      setState(() {
        _newProfileImageFile = File(pickedImage.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final newUsername = _usernameController.text.trim();
        final newEmail = _emailController.text.trim();

        String? newPhotoBase64 = _photoBase64;

        // Convert image to base64 if new image selected
        if (_newProfileImageFile != null) {
          final bytes = await _newProfileImageFile!.readAsBytes();
          newPhotoBase64 = base64Encode(bytes);
        }

        // Update Firestore user document
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'username': newUsername,
          'email': newEmail,
          'photoBase64': newPhotoBase64,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update all posts by this user with new profile info
        final postsRef = FirebaseFirestore.instance.collection('posts');
        final querySnapshot =
            await postsRef.where('userId', isEqualTo: user.uid).get();

        // Use batch write for better performance
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in querySnapshot.docs) {
          batch.update(doc.reference, {
            'userName': newUsername,
            'userPhotoBase64': newPhotoBase64,
          });
        }
        await batch.commit();

        // Update all ratings by this user with new profile photo
        final ratingsRef = FirebaseFirestore.instance.collection('ratings');
        final ratingsSnapshot =
            await ratingsRef.where('userId', isEqualTo: user.uid).get();

        final ratingsBatch = FirebaseFirestore.instance.batch();
        for (final doc in ratingsSnapshot.docs) {
          ratingsBatch.update(doc.reference, {
            'userName': newUsername,
            'userPhotoBase64': newPhotoBase64,
          });
        }
        await ratingsBatch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile and posts updated')),
          );
          Navigator.pop(context, true); // ✅ Return true to notify success
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Failed to update profile: ${e.message}';
      if (e.code == 'requires-recent-login') {
        errorMessage =
            'Please log out and log back in before updating your email address.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    late final ImageProvider displayImage;
    if (_newProfileImageFile != null) {
      displayImage = FileImage(_newProfileImageFile!);
    } else if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      try {
        displayImage = MemoryImage(base64Decode(_photoBase64!));
      } catch (_) {
        displayImage = const AssetImage('assets/steak.jpg');
      }
    } else {
      displayImage = const AssetImage('assets/steak.jpg');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.deepPurple[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: displayImage,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.deepPurple[800],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: _pickImage,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter your username'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple[800],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Saving...'),
                        ],
                      )
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on User {
  String? get photoBase64 => null;
}
