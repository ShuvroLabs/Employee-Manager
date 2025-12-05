// location_service.dart
// Location Service
// 
// This service provides location-related functionality including:
// - Real-time location streaming from employees
// - Location permission handling
// - Distance calculations for geofence checks
// - Integration with geolocator package

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'native_channel_service.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';

/// Location service for managing employee location tracking
class LocationService {
  final NativeChannelService _nativeChannelService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  LocationService(this._nativeChannelService);

  /// Get current location using Geolocator
  Future<Position?> getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return null;
        }
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
    } catch (e) {
      // ignore: avoid_print
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings for permissions
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Stream of employee locations for real-time tracking (Admin)
  Stream<List<EmployeeLocation>> streamAllEmployeeLocations(String companyId) {
    return _firestore
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .where('role', isEqualTo: 'employee')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final employees = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      final locations = <EmployeeLocation>[];
      
      for (final employee in employees) {
        // Get latest location for each employee
        final locationSnapshot = await _firestore
            .collection('locations')
            .where('employeeId', isEqualTo: employee.id)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (locationSnapshot.docs.isNotEmpty) {
          final location = LocationModel.fromFirestore(
            locationSnapshot.docs.first,
          );
          locations.add(EmployeeLocation(
            employee: employee,
            location: location,
          ));
        } else {
          locations.add(EmployeeLocation(
            employee: employee,
            location: null,
          ));
        }
      }

      return locations;
    });
  }

  /// Get real-time location updates for a specific employee
  Stream<LocationModel?> streamEmployeeLocation(String employeeId) {
    return _firestore
        .collection('locations')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return LocationModel.fromFirestore(snapshot.docs.first);
    });
  }

  /// Calculate distance between two points in meters
  double calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Check if a position is inside a geofence
  bool isInsideGeofence({
    required double latitude,
    required double longitude,
    required double geofenceLatitude,
    required double geofenceLongitude,
    required double geofenceRadius,
  }) {
    final distance = calculateDistance(
      startLatitude: latitude,
      startLongitude: longitude,
      endLatitude: geofenceLatitude,
      endLongitude: geofenceLongitude,
    );
    return distance <= geofenceRadius;
  }

  /// Save location to Firestore
  Future<void> saveLocation(LocationModel location) async {
    await _firestore
        .collection('locations')
        .doc(location.id)
        .set(location.toFirestore());
  }

  /// Get location history for an employee
  Future<List<LocationModel>> getLocationHistory({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    Query query = _firestore
        .collection('locations')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('timestamp', descending: true);

    if (startDate != null) {
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'timestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => LocationModel.fromFirestore(doc))
        .toList();
  }

  /// Get native channel service stream
  Stream<Map<String, dynamic>> get nativeLocationStream =>
      _nativeChannelService.locationStream;
}

/// Model combining employee and their current location
class EmployeeLocation {
  final UserModel employee;
  final LocationModel? location;

  EmployeeLocation({
    required this.employee,
    this.location,
  });

  bool get hasLocation => location != null;

  bool get isOnline {
    if (location == null) return false;
    // Consider online if location is within last 5 minutes
    return DateTime.now().difference(location!.timestamp).inMinutes < 5;
  }
}
