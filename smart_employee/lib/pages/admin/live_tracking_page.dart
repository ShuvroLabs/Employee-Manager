// live_tracking_page.dart
// Live Tracking Page
// 
// This page displays real-time locations of all employees
// on a Google Map. Admin can view employee positions,
// geofence boundaries, and employee status.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/geofence_controller.dart';
import '../../services/location_service.dart';
import '../../models/geofence_model.dart';
import '../../widgets/employee_marker_info.dart';

/// Live tracking page for admin
class LiveTrackingPage extends StatefulWidget {
  const LiveTrackingPage({super.key});

  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage> {
  GoogleMapController? _mapController;
  StreamSubscription<List<EmployeeLocation>>? _locationSubscription;
  
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  List<EmployeeLocation> _employeeLocations = [];
  EmployeeLocation? _selectedEmployee;

  static const LatLng _defaultCenter = LatLng(37.7749, -122.4194); // San Francisco

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _loadData() {
    final authState = context.read<AuthController>().state;
    if (authState is! AuthAuthenticated) return;

    final companyId = authState.user.companyId;
    
    // Load geofences
    context.read<GeofenceController>().add(GeofenceLoadAll(companyId: companyId));

    // Subscribe to employee locations
    final locationService = context.read<LocationService>();
    _locationSubscription = locationService
        .streamAllEmployeeLocations(companyId)
        .listen(_updateEmployeeMarkers);
  }

  void _updateEmployeeMarkers(List<EmployeeLocation> locations) {
    setState(() {
      _employeeLocations = locations;
      _markers.clear();

      for (final empLoc in locations) {
        if (empLoc.hasLocation) {
          _markers.add(
            Marker(
              markerId: MarkerId(empLoc.employee.id),
              position: LatLng(
                empLoc.location!.latitude,
                empLoc.location!.longitude,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                empLoc.isOnline
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueOrange,
              ),
              infoWindow: InfoWindow(
                title: empLoc.employee.displayName,
                snippet: empLoc.isOnline ? 'Online' : 'Last seen: ${empLoc.location!.timestamp}',
              ),
              onTap: () {
                setState(() {
                  _selectedEmployee = empLoc;
                });
              },
            ),
          );
        }
      }
    });
  }

  void _updateGeofenceCircles(List<GeofenceModel> geofences) {
    setState(() {
      _circles.clear();
      for (final geofence in geofences) {
        _circles.add(
          Circle(
            circleId: CircleId(geofence.id),
            center: LatLng(geofence.latitude, geofence.longitude),
            radius: geofence.radius,
            fillColor: Colors.blue.withOpacity(0.1),
            strokeColor: Colors.blue,
            strokeWidth: 2,
          ),
        );
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitMapToBounds();
  }

  void _fitMapToBounds() {
    if (_markers.isEmpty || _mapController == null) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final marker in _markers) {
      final pos = marker.position;
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen),
            onPressed: _fitMapToBounds,
          ),
        ],
      ),
      body: BlocListener<GeofenceController, GeofenceState>(
        listener: (context, state) {
          if (state is GeofenceLoaded) {
            _updateGeofenceCircles(state.geofences);
          }
        },
        child: Stack(
          children: [
            // Google Map
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: const CameraPosition(
                target: _defaultCenter,
                zoom: 12,
              ),
              markers: _markers,
              circles: _circles,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),

            // Employee List Panel
            Positioned(
              top: 16,
              left: 16,
              child: Card(
                child: Container(
                  width: 200,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Employees',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _employeeLocations.length,
                          itemBuilder: (context, index) {
                            final empLoc = _employeeLocations[index];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 12,
                                backgroundColor: empLoc.isOnline
                                    ? Colors.green
                                    : Colors.orange,
                                child: const Icon(
                                  Icons.person,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                empLoc.employee.displayName,
                                style: const TextStyle(fontSize: 12),
                              ),
                              subtitle: Text(
                                empLoc.isOnline ? 'Online' : 'Offline',
                                style: const TextStyle(fontSize: 10),
                              ),
                              onTap: () {
                                if (empLoc.hasLocation) {
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLng(LatLng(
                                      empLoc.location!.latitude,
                                      empLoc.location!.longitude,
                                    )),
                                  );
                                  setState(() {
                                    _selectedEmployee = empLoc;
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Selected Employee Info
            if (_selectedEmployee != null)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: EmployeeMarkerInfo(
                  employeeLocation: _selectedEmployee!,
                  onClose: () {
                    setState(() {
                      _selectedEmployee = null;
                    });
                  },
                ),
              ),

            // Legend
            Positioned(
              bottom: _selectedEmployee != null ? 140 : 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem(Colors.green, 'Online'),
                      const SizedBox(height: 4),
                      _buildLegendItem(Colors.orange, 'Offline'),
                      const SizedBox(height: 4),
                      _buildLegendItem(Colors.blue, 'Geofence'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
