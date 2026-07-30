import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VehicleType {
  car,
  fourWD,
  motorcycle,
  walking,
  cycling,
  boat,
  horse,
}

class VehicleProfile {
  final VehicleType type;
  final String name;
  final String icon;
  final double maxSpeed;
  final bool prefersUnsealedRoads;
  final bool showDepthWarnings;
  final List<String> routePreferences;

  const VehicleProfile({
    required this.type,
    required this.name,
    required this.icon,
    this.maxSpeed = 110.0,
    this.prefersUnsealedRoads = false,
    this.showDepthWarnings = false,
    this.routePreferences = const [],
  });

  static const List<VehicleProfile> profiles = [
    VehicleProfile(
      type: VehicleType.car,
      name: 'Car',
      icon: '🚗',
      maxSpeed: 110.0,
      routePreferences: ['sealed', 'highway'],
    ),
    VehicleProfile(
      type: VehicleType.fourWD,
      name: '4WD / Off-road',
      icon: '🚙',
      maxSpeed: 100.0,
      prefersUnsealedRoads: true,
      routePreferences: [' unsealed', '4wd', 'track'],
    ),
    VehicleProfile(
      type: VehicleType.motorcycle,
      name: 'Motorcycle',
      icon: '🏍️',
      maxSpeed: 110.0,
      routePreferences: ['sealed', 'highway'],
    ),
    VehicleProfile(
      type: VehicleType.walking,
      name: 'Walking',
      icon: '🚶',
      maxSpeed: 5.0,
      routePreferences: ['trail', 'walking'],
    ),
    VehicleProfile(
      type: VehicleType.cycling,
      name: 'Cycling',
      icon: '🚴',
      maxSpeed: 30.0,
      routePreferences: ['bike', 'sealed'],
    ),
    VehicleProfile(
      type: VehicleType.boat,
      name: 'Boat',
      icon: '⛵',
      maxSpeed: 50.0,
      showDepthWarnings: true,
      routePreferences: ['water', 'channel'],
    ),
    VehicleProfile(
      type: VehicleType.horse,
      name: 'Horse / Equestrian',
      icon: '🐎',
      maxSpeed: 25.0,
      prefersUnsealedRoads: true,
      routePreferences: ['trail', 'unsealed', 'bridle'],
    ),
  ];

  static VehicleProfile getProfile(VehicleType type) {
    return profiles.firstWhere((p) => p.type == type);
  }
}

class VehicleProfileState {
  final VehicleType selectedType;
  final VehicleProfile? customProfile;

  const VehicleProfileState({
    this.selectedType = VehicleType.fourWD,
    this.customProfile,
  });

  VehicleProfile get currentProfile =>
      customProfile ?? VehicleProfile.getProfile(selectedType);

  VehicleProfileState copyWith({
    VehicleType? selectedType,
    VehicleProfile? customProfile,
  }) {
    return VehicleProfileState(
      selectedType: selectedType ?? this.selectedType,
      customProfile: customProfile ?? this.customProfile,
    );
  }
}

class VehicleProfileNotifier extends StateNotifier<VehicleProfileState> {
  VehicleProfileNotifier() : super(const VehicleProfileState());

  void setVehicleType(VehicleType type) {
    state = state.copyWith(selectedType: type, customProfile: null);
  }

  void setCustomProfile(VehicleProfile profile) {
    state = state.copyWith(customProfile: profile);
  }

  double get maxSpeedWarning => state.currentProfile.maxSpeed * 1.1;

  bool shouldWarnSpeed(double currentSpeed) {
    return currentSpeed > state.currentProfile.maxSpeed;
  }

  bool shouldShowDepthWarning(double depth) {
    return state.currentProfile.showDepthWarnings && depth < 2.0;
  }

  String getRouteAdvice() {
    final profile = state.currentProfile;
    if (profile.type == VehicleType.fourWD) {
      return 'I can route you via unsealed tracks and off-road trails. Watch for washouts after rain.';
    } else if (profile.type == VehicleType.walking) {
      return 'I\'ll highlight walking trails and bush tracks. Stay on marked paths for safety.';
    } else if (profile.type == VehicleType.boat) {
      return 'I\'ll show water routes and warn about shallow areas. Check tide times before departing.';
    } else if (profile.type == VehicleType.horse) {
      return 'I\'ll find suitable trails and avoid main highways where possible. Always watch for footing changes.';
    } else {
      return 'I\'ll route you via sealed roads and highways. Use caution on gravel sections.';
    }
  }
}

final vehicleProfileProvider =
    StateNotifierProvider<VehicleProfileNotifier, VehicleProfileState>((ref) {
  return VehicleProfileNotifier();
});
