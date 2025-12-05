// geofence_management_page.dart
// Geofence Management Page
// 
// This page allows administrators to manage geofences.
// Features include adding, editing, and removing geofences,
// as well as viewing them on a map.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/geofence_controller.dart';
import '../../models/geofence_model.dart';

/// Geofence management page for admin
class GeofenceManagementPage extends StatefulWidget {
  const GeofenceManagementPage({super.key});

  @override
  State<GeofenceManagementPage> createState() => _GeofenceManagementPageState();
}

class _GeofenceManagementPageState extends State<GeofenceManagementPage> {
  GoogleMapController? _mapController;
  final Set<Circle> _circles = {};
  final Set<Marker> _markers = {};
  
  static const LatLng _defaultCenter = LatLng(37.7749, -122.4194);

  @override
  void initState() {
    super.initState();
    _loadGeofences();
  }

  void _loadGeofences() {
    final authState = context.read<AuthController>().state;
    if (authState is AuthAuthenticated) {
      context.read<GeofenceController>().add(
            GeofenceLoadAll(companyId: authState.user.companyId),
          );
    }
  }

  void _updateMapElements(List<GeofenceModel> geofences) {
    _circles.clear();
    _markers.clear();

    for (final geofence in geofences) {
      _circles.add(
        Circle(
          circleId: CircleId(geofence.id),
          center: LatLng(geofence.latitude, geofence.longitude),
          radius: geofence.radius,
          fillColor: _getGeofenceColor(geofence.type).withOpacity(0.2),
          strokeColor: _getGeofenceColor(geofence.type),
          strokeWidth: 2,
        ),
      );

      _markers.add(
        Marker(
          markerId: MarkerId(geofence.id),
          position: LatLng(geofence.latitude, geofence.longitude),
          infoWindow: InfoWindow(
            title: geofence.name,
            snippet: '${geofence.radius}m radius',
          ),
          onTap: () => _showGeofenceDetails(geofence),
        ),
      );
    }
  }

  Color _getGeofenceColor(GeofenceType type) {
    switch (type) {
      case GeofenceType.office:
        return Colors.blue;
      case GeofenceType.branch:
        return Colors.green;
      case GeofenceType.warehouse:
        return Colors.orange;
      case GeofenceType.clientSite:
        return Colors.purple;
      case GeofenceType.custom:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofence Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location),
            onPressed: _showAddGeofenceDialog,
          ),
        ],
      ),
      body: BlocConsumer<GeofenceController, GeofenceState>(
        listener: (context, state) {
          if (state is GeofenceLoaded) {
            setState(() {
              _updateMapElements(state.geofences);
            });
          } else if (state is GeofenceAdded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Geofence added successfully')),
            );
          } else if (state is GeofenceError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              // Map
              Expanded(
                flex: 2,
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: _defaultCenter,
                    zoom: 12,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  circles: _circles,
                  markers: _markers,
                  onLongPress: (position) {
                    _showAddGeofenceDialogAtPosition(position);
                  },
                ),
              ),

              // Geofence List
              Expanded(
                child: state is GeofenceLoaded
                    ? ListView.builder(
                        itemCount: state.geofences.length,
                        itemBuilder: (context, index) {
                          final geofence = state.geofences[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getGeofenceColor(geofence.type)
                                  .withOpacity(0.2),
                              child: Icon(
                                _getGeofenceIcon(geofence.type),
                                color: _getGeofenceColor(geofence.type),
                              ),
                            ),
                            title: Text(geofence.name),
                            subtitle: Text(
                              '${geofence.radius}m • ${geofence.type.name}',
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'view',
                                  child: ListTile(
                                    leading: Icon(Icons.visibility),
                                    title: Text('View on Map'),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit),
                                    title: Text('Edit'),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading:
                                        Icon(Icons.delete, color: Colors.red),
                                    title: Text('Delete',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                switch (value) {
                                  case 'view':
                                    _mapController?.animateCamera(
                                      CameraUpdate.newLatLngZoom(
                                        LatLng(geofence.latitude,
                                            geofence.longitude),
                                        16,
                                      ),
                                    );
                                    break;
                                  case 'edit':
                                    _showEditGeofenceDialog(geofence);
                                    break;
                                  case 'delete':
                                    _confirmDeleteGeofence(geofence);
                                    break;
                                }
                              },
                            ),
                            onTap: () => _showGeofenceDetails(geofence),
                          );
                        },
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _getGeofenceIcon(GeofenceType type) {
    switch (type) {
      case GeofenceType.office:
        return Icons.business;
      case GeofenceType.branch:
        return Icons.store;
      case GeofenceType.warehouse:
        return Icons.warehouse;
      case GeofenceType.clientSite:
        return Icons.location_city;
      case GeofenceType.custom:
        return Icons.location_on;
    }
  }

  void _showAddGeofenceDialog() {
    _showAddGeofenceDialogAtPosition(null);
  }

  void _showAddGeofenceDialogAtPosition(LatLng? position) {
    final nameController = TextEditingController();
    final latController =
        TextEditingController(text: position?.latitude.toString() ?? '');
    final lngController =
        TextEditingController(text: position?.longitude.toString() ?? '');
    final radiusController = TextEditingController(text: '100');
    GeofenceType selectedType = GeofenceType.office;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Geofence'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<GeofenceType>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: GeofenceType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value ?? GeofenceType.office;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latController,
                        decoration: const InputDecoration(labelText: 'Latitude'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: lngController,
                        decoration:
                            const InputDecoration(labelText: 'Longitude'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: radiusController,
                  decoration:
                      const InputDecoration(labelText: 'Radius (meters)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final authState = context.read<AuthController>().state;
                if (authState is! AuthAuthenticated) return;

                context.read<GeofenceController>().add(
                      GeofenceAdd(
                        companyId: authState.user.companyId,
                        name: nameController.text.trim(),
                        latitude: double.tryParse(latController.text) ?? 0,
                        longitude: double.tryParse(lngController.text) ?? 0,
                        radius: double.tryParse(radiusController.text) ?? 100,
                        type: selectedType,
                        createdBy: authState.user.id,
                      ),
                    );
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGeofenceDetails(GeofenceModel geofence) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              geofence.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            _buildDetailRow('Type', geofence.type.name),
            _buildDetailRow('Radius', '${geofence.radius} meters'),
            _buildDetailRow(
              'Location',
              '${geofence.latitude.toStringAsFixed(6)}, ${geofence.longitude.toStringAsFixed(6)}',
            ),
            _buildDetailRow(
              'Auto Check-in',
              geofence.autoCheckIn ? 'Enabled' : 'Disabled',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showEditGeofenceDialog(geofence);
                    },
                    child: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          LatLng(geofence.latitude, geofence.longitude),
                          16,
                        ),
                      );
                    },
                    child: const Text('View on Map'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value),
        ],
      ),
    );
  }

  void _showEditGeofenceDialog(GeofenceModel geofence) {
    final nameController = TextEditingController(text: geofence.name);
    final radiusController =
        TextEditingController(text: geofence.radius.toString());
    GeofenceType selectedType = geofence.type;
    bool autoCheckIn = geofence.autoCheckIn;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Geofence'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<GeofenceType>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: GeofenceType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedType = value ?? GeofenceType.office;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: radiusController,
                decoration: const InputDecoration(labelText: 'Radius (meters)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Auto Check-in'),
                value: autoCheckIn,
                onChanged: (value) {
                  setDialogState(() {
                    autoCheckIn = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final updated = geofence.copyWith(
                  name: nameController.text.trim(),
                  radius: double.tryParse(radiusController.text) ?? 100,
                  type: selectedType,
                  autoCheckIn: autoCheckIn,
                );
                context.read<GeofenceController>().add(
                      GeofenceUpdate(geofence: updated),
                    );
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteGeofence(GeofenceModel geofence) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Geofence'),
        content:
            Text('Are you sure you want to delete "${geofence.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<GeofenceController>().add(
                    GeofenceRemove(geofenceId: geofence.id),
                  );
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
