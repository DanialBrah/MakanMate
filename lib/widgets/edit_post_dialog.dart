import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/post_model.dart';
import '../services/post_service.dart';

class EditPostDialog extends StatefulWidget {
  final Post post;
  final VoidCallback? onPostUpdated;

  const EditPostDialog({
    super.key,
    required this.post,
    this.onPostUpdated,
  });

  @override
  State<EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<EditPostDialog> {
  final _formKey = GlobalKey<FormState>();
  final PostService _postService = PostService();

  late TextEditingController _titleController;
  late TextEditingController _foodNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _restaurantNameController;
  late TextEditingController _priceController;
  late TextEditingController _tagsController;

  double _rating = 1.0;
  bool _isLoading = false;
  File? _newImageFile;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _titleController = TextEditingController(text: widget.post.title);
    _foodNameController = TextEditingController(text: widget.post.foodName);
    _descriptionController =
        TextEditingController(text: widget.post.description);
    _locationController = TextEditingController(text: widget.post.location);
    _restaurantNameController =
        TextEditingController(text: widget.post.restaurantName);
    _priceController =
        TextEditingController(text: widget.post.price.toString());
    _tagsController = TextEditingController(text: widget.post.tags.join(', '));
    _rating = widget.post.rating;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _foodNameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _restaurantNameController.dispose();
    _priceController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickNewImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _newImageFile = File(image.path);
      });
    }
  }

  Future<void> _updatePost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if user owns the post
      if (widget.post.userId != currentUser.uid) {
        throw Exception('Unauthorized to edit this post');
      }

      // Parse tags
      List<String> tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      // Prepare update data
      Map<String, dynamic> updates = {
        'title': _titleController.text.trim(),
        'foodName': _foodNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'restaurantName': _restaurantNameController.text.trim(),
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'rating': _rating,
        'tags': tags,
      };

      await _postService.updatePost(widget.post.id, updates,
          imageFile: _newImageFile);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Call callback if provided
        widget.onPostUpdated?.call();

        // Close dialog
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Post',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        onTap: _pickNewImage,
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[200],
                            image: _newImageFile != null
                                ? DecorationImage(
                                    image: FileImage(_newImageFile!),
                                    fit: BoxFit.cover,
                                  )
                                : widget.post.imageUrl != null
                                    ? DecorationImage(
                                        image:
                                            NetworkImage(widget.post.imageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                          ),
                          child: _newImageFile == null &&
                                  widget.post.imageUrl == null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.add_a_photo,
                                          color: Colors.grey, size: 40),
                                      SizedBox(height: 8),
                                      Text('Tap to add image'),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title Field
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Food Name Field
                      TextFormField(
                        controller: _foodNameController,
                        decoration: const InputDecoration(
                          labelText: 'Food Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the food name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description Field
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Restaurant Name Field
                      TextFormField(
                        controller: _restaurantNameController,
                        decoration: const InputDecoration(
                          labelText: 'Restaurant Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the restaurant name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Location Field
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the location';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Price Field
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the price';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid price';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Rating Slider
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rating: ${_rating.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Slider(
                            value: _rating,
                            min: 1.0,
                            max: 5.0,
                            divisions: 8,
                            activeColor: Colors.deepPurple[800],
                            onChanged: (value) {
                              setState(() {
                                _rating = value;
                              });
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(5, (index) {
                              return Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tags Field
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                          border: OutlineInputBorder(),
                          hintText: 'spicy, vegetarian, halal',
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _updatePost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple[800],
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Update'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
