import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';

class LocationDialogView {
  static void showNewLocationDialog({
    required BuildContext context,
    required double latitude,
    required double longitude,
    VoidCallback? onLocationAdded,
  }) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final descriptionController = TextEditingController();
    final latitudeController = TextEditingController(text: latitude.toString());
    final longitudeController =
        TextEditingController(text: longitude.toString());
    final locationService = LocationService();

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Location'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Location Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Location name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Address is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: latitudeController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^-?\d*\.?\d*')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Latitude is required';
                          final lat = double.tryParse(value);
                          if (lat == null || lat < -90 || lat > 90)
                            return 'Invalid latitude';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: longitudeController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^-?\d*\.?\d*')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Longitude is required';
                          final lng = double.tryParse(value);
                          if (lng == null || lng < -180 || lng > 180)
                            return 'Invalid longitude';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                try {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  final location = Location(
                    name: nameController.text.trim(),
                    address: addressController.text.trim(),
                    description: descriptionController.text.trim(),
                    latitude: double.parse(latitudeController.text),
                    longitude: double.parse(longitudeController.text),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  await locationService.addLocation(location);

                  if (context.mounted) Navigator.pop(context); // close loading
                  if (context.mounted) Navigator.pop(context); // close form
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Location added successfully!'),
                          backgroundColor: Colors.green),
                    );
                  }

                  onLocationAdded?.call();
                } catch (e) {
                  if (context.mounted) Navigator.pop(context); // close loading
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error adding location: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static void showEditLocationDialog({
    required BuildContext context,
    required Location location,
    VoidCallback? onLocationUpdated,
  }) {
    final nameController = TextEditingController(text: location.name);
    final addressController = TextEditingController(text: location.address);
    final descriptionController =
        TextEditingController(text: location.description);
    final latitudeController =
        TextEditingController(text: location.latitude.toString());
    final longitudeController =
        TextEditingController(text: location.longitude.toString());
    final locationService = LocationService();

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Location'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Location Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Location name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Address is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: latitudeController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Latitude is required';
                          final lat = double.tryParse(value);
                          if (lat == null || lat < -90 || lat > 90)
                            return 'Invalid latitude';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: longitudeController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Longitude is required';
                          final lng = double.tryParse(value);
                          if (lng == null || lng < -180 || lng > 180)
                            return 'Invalid longitude';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                try {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  final updatedLocation = location.copyWith(
                    name: nameController.text.trim(),
                    address: addressController.text.trim(),
                    description: descriptionController.text.trim(),
                    latitude: double.parse(latitudeController.text),
                    longitude: double.parse(longitudeController.text),
                    updatedAt: DateTime.now(),
                  );

                  await locationService.updateLocation(
                      location.id!, updatedLocation);

                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Location updated successfully!'),
                          backgroundColor: Colors.green),
                    );
                  }

                  onLocationUpdated?.call();
                } catch (e) {
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error updating location: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
