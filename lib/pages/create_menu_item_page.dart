import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class CreateMenuItemPage extends StatefulWidget {
  final Map<String, dynamic>? existingItem;
  final String? itemId;

  const CreateMenuItemPage({super.key, this.existingItem, this.itemId});

  @override
  State<CreateMenuItemPage> createState() => _CreateMenuItemPageState();
}

class _CreateMenuItemPageState extends State<CreateMenuItemPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  List<String> _categories = [];
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _nameController.text = widget.existingItem!['name'] ?? '';
      _descriptionController.text = widget.existingItem!['description'] ?? '';
      _priceController.text = (widget.existingItem!['price'] ?? 0).toString();
      _categories = List<String>.from(widget.existingItem!['categories'] ?? []);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final storageRef = FirebaseStorage.instance.ref().child(
        'restaurants/${user.uid}/menu/${DateTime.now().millisecondsSinceEpoch}.jpg');

    final uploadTask = storageRef.putFile(_imageFile!);
    final snapshot = await uploadTask.whenComplete(() {});
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _saveMenuItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final imageUrl = await _uploadImage();

      final menuItemData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': double.parse(_priceController.text),
        'categories': _categories,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (imageUrl != null) {
        menuItemData['imageUrl'] = imageUrl;
      } else if (widget.existingItem != null &&
          widget.existingItem!['imageUrl'] != null) {
        menuItemData['imageUrl'] = widget.existingItem!['imageUrl'];
      }

      if (widget.existingItem != null && widget.itemId != null) {
        // Update existing item
        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(user.uid)
            .collection('menu')
            .doc(widget.itemId)
            .update(menuItemData);
      } else {
        // Create new item
        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(user.uid)
            .collection('menu')
            .add(menuItemData);
      }

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving menu item: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addCategory() {
    if (_categoryController.text.isNotEmpty) {
      setState(() {
        _categories.add(_categoryController.text);
        _categoryController.clear();
      });
    }
  }

  void _removeCategory(String category) {
    setState(() {
      _categories.remove(category);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.existingItem != null ? 'Edit Menu Item' : 'Add Menu Item'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveMenuItem,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _imageFile != null
                            ? Image.file(_imageFile!, fit: BoxFit.cover)
                            : widget.existingItem != null &&
                                    widget.existingItem!['imageUrl'] != null
                                ? Image.network(
                                    widget.existingItem!['imageUrl'],
                                    fit: BoxFit.cover,
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo, size: 48),
                                      SizedBox(height: 8),
                                      Text('Add Photo'),
                                    ],
                                  ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(),
                        prefixText: '\$',
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a price';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Categories',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories
                          .map((category) => Chip(
                                label: Text(category),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () => _removeCategory(category),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _categoryController,
                            decoration: const InputDecoration(
                              labelText: 'Add Category',
                              border: OutlineInputBorder(),
                            ),
                            onFieldSubmitted: (_) => _addCategory(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addCategory,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
