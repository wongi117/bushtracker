import 'dart:math';

/// Offline AI Service - Local survival intelligence that works without internet
/// Provides contextual survival responses based on location, time, and situation
class OfflineAIService {
  
  // Survival response templates for common scenarios
  static final Map<String, List<String>> _survivalResponses = {
    'greeting': [
      "Future Gen AI online. I'm your local survival intelligence. How can I assist?",
      "Systems active. I'm Future Gen AI, your backup in the bush. What do you need?",
      "Future Gen AI ready. No signal, no problem. I'm running offline. What's your status?",
    ],
    'location': [
      "Your position is locked. I've got your coordinates cached for emergency reference.",
      "GPS signal acquired. Your location is tracked and encrypted on device.",
      "Position confirmed. I'll remember exactly where you are, even without network.",
    ],
    'navigate': [
      "Navigation mode active. Follow your breadcrumb trail or set a waypoint.",
      "I can guide you using stored terrain data and your movement history. Ready when you are.",
      "No maps needed - I've recorded your path. Say 'breadcrumb return' to reverse your trail.",
    ],
    'weather': [
      "Monitor the sky. In the outback, weather can change fast. I've got your back if conditions shift.",
      "Weather watch active. I'll alert you to temperature extremes and sunset timing.",
      "Keep an eye on the horizon. I'm tracking environmental conditions locally.",
    ],
    'water': [
      "Water is critical. Conserve what you have. I can help you navigate to known water sources if cached.",
      "Hydration alert: In this heat, you need 4-5 liters per day. Mark your water locations as waypoints.",
      "Water sources nearby? Check your offline map. I've cached known creeks and tanks in this region.",
    ],
    'sos': [
      "Emergency mode activated. Broadcasting SOS via mesh network. Stay put if safe.",
      "SOS beacon active. All nearby BushTrack devices will receive your position. Help is coordinated.",
      "Emergency signal sent through mesh. Your location is shared with every compatible device in range.",
    ],
    'camp': [
      "Camp finder engaged. Looking for flat ground, water proximity, and shelter from wind.",
      "I'll help you find camp. Seek higher ground, avoid creek beds, and mark your location.",
      "Camp recommendations: Check for dead trees (widowmakers), flat ground, and escape routes.",
    ],
    'compass': [
      "AR Compass active. Follow the bearing I've calculated. Your phone's sensors are calibrated.",
      "Navigation sensors online. The compass compensates for magnetic declination in this region.",
      "Keep the compass centered. I'll update your bearing as you move toward your target.",
    ],
    'mesh': [
      "Mesh network active. Looking for nearby BushTrack devices to extend your communication range.",
      "Your device is beaconing. Other explorers nearby will see you on their mesh network.",
      "Mesh sync running. Even without towers, we can coordinate with other devices in visual range.",
    ],
    'panic': [
      "Breathe. You're not alone. I'm tracking your position. Let's solve this step by step.",
      "Stay calm. Panic kills. Assess: Shelter, water, signal. I can help with all three.",
      "Ground yourself. Feel your feet. Hear my voice. We'll get through this together.",
    ],
    'default': [
      "I'm Future Gen AI, your offline survival AI. Ask me about navigation, camps, weather, or emergency procedures.",
      "Running in local mode. I can help with: finding camp, navigation, breadcrumbs, SOS, and mesh networking.",
      "Future Gen AI offline intelligence at your service. What survival information do you need?",
    ],
  };

  /// Generate a contextual offline response
  static String generateResponse(String input, {
    LocationStats? locationStats,
    OfflineMeshState? meshState,
  }) {
    final lowerInput = input.toLowerCase();
    
    // Check for emergency first
    if (lowerInput.contains('help') || lowerInput.contains('emergency') || lowerInput.contains('sos')) {
      return _getRandomResponse('sos');
    }
    
    // Check for panic/distress
    if (lowerInput.contains('scared') || lowerInput.contains('lost') || lowerInput.contains('panic') || 
        lowerInput.contains('afraid') || lowerInput.contains('stuck')) {
      return _getRandomResponse('panic');
    }
    
    // Check for navigation intents
    if (lowerInput.contains('navigate') || lowerInput.contains('direction') || 
        lowerInput.contains('where') || lowerInput.contains('go to') ||
        lowerInput.contains('breadcrumb') || lowerInput.contains('backtrack')) {
      return _getRandomResponse('navigate');
    }
    
    // Check for location queries
    if (lowerInput.contains('where am i') || lowerInput.contains('location') || 
        lowerInput.contains('position') || lowerInput.contains('coordinates')) {
      String response = _getRandomResponse('location');
      if (locationStats?.coordsDecimal != null) {
        response += " Your current position: ${locationStats!.coordsDecimal}.";
      }
      return response;
    }
    
    // Check for weather
    if (lowerInput.contains('weather') || lowerInput.contains('rain') || 
        lowerInput.contains('hot') || lowerInput.contains('cold') || lowerInput.contains('temperature')) {
      return _getRandomResponse('weather');
    }
    
    // Check for water
    if (lowerInput.contains('water') || lowerInput.contains('thirsty') || 
        lowerInput.contains('drink') || lowerInput.contains('hydration')) {
      return _getRandomResponse('water');
    }
    
    // Check for camp
    if (lowerInput.contains('camp') || lowerInput.contains('sleep') || 
        lowerInput.contains('tent') || lowerInput.contains('shelter') || lowerInput.contains('rest')) {
      return _getRandomResponse('camp');
    }
    
    // Check for compass/navigation tools
    if (lowerInput.contains('compass') || lowerInput.contains('bearing') || 
        lowerInput.contains('direction') || lowerInput.contains('north')) {
      return _getRandomResponse('compass');
    }
    
    // Check for mesh/network
    if (lowerInput.contains('mesh') || lowerInput.contains('network') || 
        lowerInput.contains('connect') || lowerInput.contains('signal') || lowerInput.contains('communication')) {
      String response = _getRandomResponse('mesh');
      if (meshState != null) {
        final peerCount = meshState.connectedEndpoints.length;
        if (peerCount > 0) {
          response += " Currently connected to $peerCount nearby device(s).";
        } else {
          response += " No peers in range yet. Keep moving or wait for other BushTrack users.";
        }
      }
      return response;
    }
    
    // Check for greeting
    if (lowerInput.contains('hello') || lowerInput.contains('hi ') || 
        lowerInput.contains('hey') || lowerInput.contains('gday') || lowerInput.contains('good day')) {
      return _getRandomResponse('greeting');
    }
    
    // Default response
    return _getRandomResponse('default');
  }
  
  static String _getRandomResponse(String category) {
    final responses = _survivalResponses[category] ?? _survivalResponses['default']!;
    final random = Random();
    return responses[random.nextInt(responses.length)];
  }
  
  /// Generate proactive survival alerts based on conditions
  static String? generateProactiveAlert({
    required DateTime lastMovement,
    double? batteryLevel,
    DateTime? sunsetTime,
    double? temperature,
  }) {
    final now = DateTime.now();
    final timeSinceMovement = now.difference(lastMovement);
    
    // No movement for 4 hours
    if (timeSinceMovement.inHours >= 4) {
      return "You haven't moved in ${timeSinceMovement.inHours} hours. Are you okay? Tap OK or I'll send your location to your emergency contact.";
    }
    
    // Low battery
    if (batteryLevel != null && batteryLevel < 20) {
      return "Battery low at ${batteryLevel.round()}%. Activating power saving mode. GPS interval increased to 2 minutes.";
    }
    
    // Sunset approaching
    if (sunsetTime != null) {
      final timeUntilSunset = sunsetTime.difference(now);
      if (timeUntilSunset.inMinutes <= 60 && timeUntilSunset.inMinutes > 0) {
        return "Sunset in ${timeUntilSunset.inMinutes} minutes. Recommend finding camp in next 30 minutes.";
      }
    }
    
    // Temperature extreme
    if (temperature != null && temperature > 40) {
      return "Current heat index: ${temperature.round()}°C. Drink water. Seek shade.";
    }
    
    return null;
  }
  
  /// Calculate survival tips based on time of day
  static String getTimeBasedTip() {
    final hour = DateTime.now().hour;
    
    if (hour >= 5 && hour < 9) {
      return "Morning: Good time to travel. Temperatures rising. Carry extra water.";
    } else if (hour >= 9 && hour < 16) {
      return "Midday: Peak heat. Seek shade. Hydrate every 15 minutes. Avoid strenuous activity.";
    } else if (hour >= 16 && hour < 19) {
      return "Afternoon: Good traveling window. Watch for wildlife near water sources.";
    } else {
      return "Evening/Night: Temperature dropping. Set camp while you can still see. Check for widowmakers.";
    }
  }
}

/// Simple MeshState stub for offline service (avoid conflict with real MeshState)
class OfflineMeshState {
  final List<String> connectedEndpoints;
  OfflineMeshState({this.connectedEndpoints = const []});
}

/// Simple LocationStats stub for offline service  
class LocationStats {
  final String? coordsDecimal;
  LocationStats({this.coordsDecimal});
}
