import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class AppLocation {
  final double latitude;
  final double longitude;
  final String city;
  final String address;

  const AppLocation({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.address,
  });
}

class LocationService {
  Future<AppLocation> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location service is disabled. Please enable GPS.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied. Please enable it from settings.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final places = await placemarkFromCoordinates(position.latitude, position.longitude);
    final place = places.isNotEmpty ? places.first : null;

    final city = [
      place?.locality,
      place?.subAdministrativeArea,
      place?.administrativeArea,
    ].whereType<String>().map((value) => value.trim()).firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => 'Current Location',
        );

    final address = [
      place?.name,
      place?.subLocality,
      place?.locality,
      place?.administrativeArea,
      place?.postalCode,
      place?.country,
    ].whereType<String>().map((value) => value.trim()).where((value) => value.isNotEmpty).join(', ');

    return AppLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      city: city,
      address: address.isEmpty ? city : address,
    );
  }
}
