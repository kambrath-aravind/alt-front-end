import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  /// Check permissions and get the current device location.
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return null;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: Duration(seconds: 5),
    ));
  }

  /// Converts a zip code string to a Position.
  /// If the zip code is empty or invalid, falls back to returning null to trigger online pricing.
  Future<Position?> getFallbackLocation(String zipCode) async {
    try {
      if (zipCode.isNotEmpty) {
        final locations = await locationFromAddress(zipCode);
        if (locations.isNotEmpty) {
          final loc = locations.first;
          return Position(
            longitude: loc.longitude,
            latitude: loc.latitude,
            timestamp: DateTime.now(),
            accuracy: 100.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
        }
      }
    } catch (e) {
      // Ignore geocoding errors and proceed
    }

    return null;
  }
}
