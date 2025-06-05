import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  String? _photoUrl;
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
      _photoUrl = user.photoURL;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          _usernameController.text = data['username'] ?? '';
          // Load photoUrl from Firestore if it exists (this might be more up-to-date)
          _photoUrl = data['photoUrl'] ?? _photoUrl;
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

  Future<String?> _uploadProfileImage(String uid) async {
    if (_newProfileImageFile == null) return null;

    final ref = FirebaseStorage.instance.ref().child('users/$uid/profile.jpg');

    try {
      // Upload the file and wait for completion
      final uploadTask = ref.putFile(_newProfileImageFile!);
      final snapshot = await uploadTask;

      // Get download URL from the completed upload task snapshot
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Upload error: $e');
      throw Exception('Failed to upload image: $e');
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

        String? newPhotoUrl = _photoUrl;

        // Upload new image if selected
        if (_newProfileImageFile != null) {
          newPhotoUrl = await _uploadProfileImage(user.uid);
          if (newPhotoUrl == null) {
            throw Exception('Failed to upload profile image');
          }
        }

        // Update Firebase Auth profile
        await user.updateDisplayName(newUsername);
        if (newPhotoUrl != null && newPhotoUrl != user.photoURL) {
          await user.updatePhotoURL(newPhotoUrl);
        }

        // Update email if changed
        if (newEmail != user.email) {
          await user.updateEmail(newEmail);
        }

        // Update Firestore user document
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'username': newUsername,
          'email': newEmail,
          'photoUrl': newPhotoUrl,
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
            'userPhotoUrl': newPhotoUrl,
          });
        }
        await batch.commit();

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
    final displayImage = _newProfileImageFile != null
        ? FileImage(_newProfileImageFile!)
        : (_photoUrl != null
            ? NetworkImage(_photoUrl!)
            : const AssetImage('assets/steak.jpg')) as ImageProvider;

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
