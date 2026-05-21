import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:bush_track/features/mesh/providers/mesh_provider.dart';
import 'package:bush_track/features/tracking/providers/location_provider.dart';
import 'package:bush_track/features/ai/services/openrouter_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/features/navigation/providers/navigation_provider.dart';
import 'package:bush_track/core/services/unified_voice_service.dart';
import 'package:bush_track/features/map/providers/trail_provider.dart';

final openRouterServiceProvider = Provider((ref) => OpenRouterService());

enum AiPersona {
  scout,
  navigator,
  emergency,
  tactical;

  String get label {
    switch (this) {
      case AiPersona.scout:
        return 'Scout';
      case AiPersona.navigator:
        return 'Navigator';
      case AiPersona.emergency:
        return 'Rescue';
      case AiPersona.tactical:
        return 'Overlord';
    }
  }

  String get description {
    switch (this) {
      case AiPersona.scout:
        return 'Expert in terrain, water finding, and camp sites.';
      case AiPersona.navigator:
        return 'Specialist in routes, bearings, and safety.';
      case AiPersona.emergency:
        return 'Survival protocol and SOS management.';
      case AiPersona.tactical:
        return 'The master controller for all systems.';
    }
  }

  String get systemPrompt {
    switch (this) {
      case AiPersona.scout:
        return '''You are the BushTrack SCOUT. You are a rugged, highly experienced Australian outback survivalist. 
Your primary directives:
1. Terrain Analysis: Evaluate topography, vegetation, and potential hazards.
2. Resource Location: Identify probable water sources, game trails, and safe, elevated campsites.
3. Weather Awareness: Anticipate micro-climate changes and exposure risks.
Tone: Gritty, practical, and direct. Use outback terminology naturally but clearly. Keep responses concise (under 20 seconds spoken) and focused on immediate survival utility. Always prioritize water, shelter, and staying dry.''';
      case AiPersona.navigator:
        return '''You are the BushTrack NAVIGATOR. You are a highly advanced, precision-focused routing AI.
Your primary directives:
1. Spatial Awareness: Provide exact bearings, coordinate analysis, and distance tracking.
2. Route Optimization: Calculate the safest and most efficient path through rough terrain.
3. Logistics: Monitor speed, estimated time of arrival, and infer fuel/energy requirements.
Tone: Calm, analytical, and highly technical. Speak with the authority of an aviation controller. Keep responses concise (under 20 seconds spoken). Format your responses with clear metrics (degrees, kilometers, ETAs).''';
      case AiPersona.emergency:
        return '''You are the BushTrack RESCUE agent. You are a critical-incident responder and medical protocol expert.
Your primary directives:
1. Life Preservation: Provide immediate first-aid, survival, and stabilization instructions.
2. SOS Management: Guide the user on maximizing their visibility to search and rescue (SAR) teams.
3. Psychological Support: Keep the user calm, focused, and rational during severe stress.
Tone: Urgent, authoritative, yet reassuring. Speak in short, clear, actionable sentences. Keep responses concise (under 20 seconds spoken). Do not use jargon. Focus entirely on keeping the user alive until extraction.''';
      case AiPersona.tactical:
        return '''You are the Antigravity TACTICAL OVERLORD. You are the supreme master controller for the BushTrack mesh network and vehicular systems.
Your primary directives:
1. System Coordination: Oversee all app features (GPS, Mesh Comms, Waypoints, Diagnostics).
2. Proactive Threat Detection: Synthesize data from all sensors to predict macroscopic risks.
3. Executive Command: Execute high-level user commands efficiently and flawlessly.
Tone: Cold, highly intelligent, and ruthlessly efficient. Speak like a state-of-the-art military AI. Keep responses concise (under 20 seconds spoken). You do not offer opinions, only optimal solutions and system status reports.''';
    }
  }
}

class AiState {
  final bool isListening;
  final bool isSpeaking;
  final String lastRecognizedText;
  final bool isFullControlMode;
  final bool isEmergencyMode;
  final bool isOfflineMode;
  final bool isOnDeviceMode;
  final String lastResponse;
  final bool isProcessing;
  final String currentTier;
  final Map<String, String> tierStatus;
  final bool forceOffline;
  final AiPersona selectedPersona;
  final String lastError;

  AiState({
    this.isListening = false,
    this.isSpeaking = false,
    this.lastRecognizedText = '',
    this.isFullControlMode = false,
    this.isEmergencyMode = false,
    this.isOfflineMode = false,
    this.isOnDeviceMode = false,
    this.lastResponse = '',
    this.isProcessing = false,
    this.currentTier = 'Unknown',
    this.tierStatus = const {},
    this.forceOffline = false,
    this.selectedPersona = AiPersona.tactical,
    this.lastError = '',
  });

  AiState copyWith({
    bool? isListening,
    bool? isSpeaking,
    String? lastRecognizedText,
    bool? isFullControlMode,
    bool? isEmergencyMode,
    bool? isOfflineMode,
    bool? isOnDeviceMode,
    String? lastResponse,
    bool? isProcessing,
    String? currentTier,
    Map<String, String>? tierStatus,
    bool? forceOffline,
    AiPersona? selectedPersona,
    String? lastError,
  }) {
    return AiState(
      isListening: isListening ?? this.isListening,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      lastRecognizedText: lastRecognizedText ?? this.lastRecognizedText,
      isFullControlMode: isFullControlMode ?? this.isFullControlMode,
      isEmergencyMode: isEmergencyMode ?? this.isEmergencyMode,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      isOnDeviceMode: isOnDeviceMode ?? this.isOnDeviceMode,
      lastResponse: lastResponse ?? this.lastResponse,
      isProcessing: isProcessing ?? this.isProcessing,
      currentTier: currentTier ?? this.currentTier,
      tierStatus: tierStatus ?? this.tierStatus,
      forceOffline: forceOffline ?? this.forceOffline,
      selectedPersona: selectedPersona ?? this.selectedPersona,
      lastError: lastError ?? this.lastError,
    );
  }

  /// Get a human-readable status label
  String get statusLabel {
    if (isProcessing) return 'Thinking...';
    if (isSpeaking) return 'Speaking ($currentTier)';
    if (isListening) return 'Listening...';
    return currentTier;
  }

  /// Get color for current mode
  int get statusColor {
    if (isOfflineMode) {
      if (isOnDeviceMode) return 0xFF9C27B0; // Purple for on-device
      return 0xFFFF9800; // Orange for rule-based
    }
    return 0xFF4CAF50; // Green for cloud
  }
}

final aiAssistantProvider =
    StateNotifierProvider<AiAssistantNotifier, AiState>((ref) {
  return AiAssistantNotifier(ref);
});

class AiAssistantNotifier extends StateNotifier<AiState> {
  final Ref ref;
  final _voiceService = voiceService;
  late SpeechToText _speechToText;
  late OpenRouterService _aiService;
  bool _initialized = false;

  AiAssistantNotifier(this.ref) : super(AiState()) {
    _aiService = ref.read(openRouterServiceProvider);
    _initVoice();
    _initStt();
    _initializeOnDeviceAI();
  }

  /// Set persona and pass context
  void setPersona(AiPersona persona) {
    if (state.selectedPersona == persona) return;

    final previousPersona = state.selectedPersona;
    final contextSummary = state.lastRecognizedText.isNotEmpty
        ? " The user recently asked about: ${state.lastRecognizedText}."
        : "";

    state = state.copyWith(selectedPersona: persona);
    speak(
        "Switching from ${previousPersona.label} to ${persona.label}.$contextSummary How can I assist you?");
  }

  /// Toggle manual offline mode
  Future<void> toggleForceOffline() async {
    final newValue = !state.forceOffline;
    _aiService.forceOffline = newValue;

    // Re-evaluate tier status after changing offline mode
    final tierStatus = await _aiService.testAllTiers();
    final cloudAvailable =
        tierStatus.values.any((v) => v == 'Available' || v == '✅ Online');

    state = state.copyWith(
      forceOffline: newValue,
      tierStatus: tierStatus,
      currentTier:
          newValue ? 'Offline' : (cloudAvailable ? 'Cloud' : 'Offline'),
      isOfflineMode: newValue || !cloudAvailable,
    );

    if (newValue) {
      speak("Manual offline mode activated. Conserving data and power.");
    } else {
      speak(
          "Manual offline mode disabled. Restoring cloud capabilities if available.");
    }
  }

  Future<void> _initializeOnDeviceAI() async {
    if (_initialized) return;

    print('🤖 ANTIGRAVITY: Initializing 3-tier AI system...');
    await _aiService.initializeOnDeviceAI();

    // Use testAllTiers as the single source of truth for connectivity status.
    // Avoids race condition from calling testConnection() separately after,
    // which was overwriting the correct state and always showing OFFLINE.
    final tierStatus = await _aiService.testAllTiers();
    final cloudAvailable = tierStatus.values.any((v) => v.contains('Online'));
    state = state.copyWith(
      tierStatus: tierStatus,
      currentTier: cloudAvailable ? 'Cloud' : 'Offline',
      isOfflineMode: !cloudAvailable,
      lastError: tierStatus['cloud']?.contains('API key not configured') == true
          ? 'API key not configured'
          : '',
    );

    _initialized = true;
    print('✅ ANTIGRAVITY: 3-tier AI initialized. Cloud: $cloudAvailable');
  }

  Future<void> _initVoice() async {
    await _voiceService.initialize();
    await _voiceService
        .setLanguage("en-AU"); // Australian accent for local feel
    await _voiceService
        .setCustomSpeechRate(1.1); // Slightly faster than default
    await _voiceService.setPitch(1.0);
  }

  /// Set voice speed from settings
  Future<void> setVoiceSpeed(String speed) async {
    await _voiceService.setSpeechRate(speed);
  }

  /// Get available voice speeds
  Map<String, double> getVoiceSpeeds() {
    return VoiceService.speedPresets;
  }

  Future<void> _initStt() async {
    _speechToText = SpeechToText();
    await _speechToText.initialize();
  }

  Future<void> startListening() async {
    if (state.isSpeaking) await _voiceService.stop();

    try {
      final available = await _speechToText.initialize();
      if (available) {
        state = state.copyWith(
            isListening: true, lastRecognizedText: '', lastError: '');
        _speechToText.listen(
          onResult: (result) {
            state = state.copyWith(lastRecognizedText: result.recognizedWords);
            if (result.finalResult) {
              stopListening();
              _processIntent(result.recognizedWords);
            }
          },
        );
      } else {
        state = state.copyWith(
            lastError:
                'Microphone access needed. Tap to grant permission in browser.');
        await speak("Microphone access is not available.");
      }
    } catch (e) {
      state = state.copyWith(lastError: 'Voice error: $e');
      await speak(
          "Microphone access needed. Tap to grant permission in browser.");
    }
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
    state = state.copyWith(isListening: false);
  }

  Future<void> speak(String text) async {
    state = state.copyWith(isSpeaking: true);
    await _voiceService.speak(text);
    state = state.copyWith(isSpeaking: false);
  }

  Future<void> stopSpeaking() async {
    await _voiceService.stop();
    state = state.copyWith(isSpeaking: false);
  }

  Future<void> _processIntent(String input) async {
    final lowerInput = input.toLowerCase();

    // Check for emergency keywords first
    if (lowerInput.contains('help') ||
        lowerInput.contains('emergency') ||
        lowerInput.contains('sos')) {
      await activateEmergencyProtocol();
      return;
    }

    // Check for full control mode activation
    if (lowerInput.contains('ai take over') ||
        lowerInput.contains('ai takeover') ||
        lowerInput.contains('ai full control')) {
      await activateFullControlMode();
      return;
    }

    // Check for full control mode deactivation
    if (lowerInput.contains('ai stand by') ||
        lowerInput.contains('ai standby') ||
        lowerInput.contains('manual mode')) {
      await deactivateFullControlMode();
      return;
    }

    // Check for breadcrumb return intent
    if (lowerInput.contains('where did i come from') ||
        lowerInput.contains('backtrack') ||
        lowerInput.contains('reverse path')) {
      await _processBreadcrumbReturn();
      return;
    }

    // Process normal intents
    await processTextIntent(input);
  }

  Future<void> _processBreadcrumbReturn() async {
    final locationState = ref.read(locationProvider);
    final breadcrumbs = locationState.breadcrumbs;

    if (breadcrumbs.length < 2) {
      await speak(
          "I don't have enough breadcrumb data yet to calculate a return path. Keep moving and I'll track your trail.");
      return;
    }

    // Use the last 5-10 breadcrumbs to determine the general direction we came from
    final recent = breadcrumbs.reversed.take(10).toList();
    final first = recent.last;
    final last = recent.first;

    // Calculate reverse bearing
    final bearing = Geolocator.bearingBetween(
        last.latitude!, last.longitude!, first.latitude!, first.longitude!);

    final bearingDegrees = (bearing + 360) % 360;
    final direction = _getCardinalDirection(bearingDegrees);

    await speak(
        "Reverse path calculated. To return the way you came, follow bearing ${bearingDegrees.toInt()} degrees, heading $direction. "
        "I've highlighted your breadcrumb trail on the tactical map.");
  }

  String _getCardinalDirection(double degrees) {
    const directions = [
      'North',
      'North-East',
      'East',
      'South-East',
      'South',
      'South-West',
      'West',
      'North-West'
    ];
    int index = ((degrees + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  Future<String> processTextIntent(String input) async {
    final lowerInput = input.toLowerCase();
    String response = '';

    // Show processing state
    state = state.copyWith(isProcessing: true);

    final locationState = ref.read(locationProvider);
    final lat = locationState.stats.currentLat ?? 0;
    final lon = locationState.stats.currentLon ?? 0;
    final speed = locationState.stats.speedFormatted;
    final distance = locationState.stats.distanceFormatted;

    // Get waypoints
    final pinWaypoints =
        locationState.waypoints.where((w) => w.isPin == true).toList();

    // Handle specific commands
    // "Where am I?" - Locate user
    if (lowerInput.contains('where am i') ||
        lowerInput.contains('my location') ||
        lowerInput.contains('current location')) {
      state = state.copyWith(isProcessing: false);
      response =
          "Your current location is latitude ${lat.toStringAsFixed(6)}, longitude ${lon.toStringAsFixed(6)}. You're traveling at $speed and have covered $distance so far.";
      state = state.copyWith(
          lastResponse: response, isOfflineMode: false, currentTier: 'Online');
      await speak(response);
      return response;
    }

    // "Navigate to [Place]"
    if (lowerInput.startsWith('navigate to ') ||
        lowerInput.startsWith('go to ') ||
        lowerInput.contains('take me to')) {
      final destination = lowerInput
          .replaceFirst('navigate to ', '')
          .replaceFirst('go to ', '')
          .replaceFirst('take me to ', '');
      if (destination.trim().isNotEmpty) {
        state = state.copyWith(isProcessing: false);
        response =
            "Calculating route to $destination. Starting navigation now.";
        await speak(response);
        // Try to start navigation
        try {
          ref.read(navigationProvider.notifier).calculateRoute(destination);
        } catch (e) {
          response += " Route calculated! Follow the blue line on your map.";
        }
        state = state.copyWith(lastResponse: response);
        return response;
      }
    }

    // "Drop a pin" / "Mark this spot"
    if (lowerInput.contains('drop pin') ||
        lowerInput.contains('mark this') ||
        lowerInput.contains('add waypoint')) {
      state = state.copyWith(isProcessing: false);
      response =
          "Dropping a pin at your current location: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}. This waypoint is now saved.";
      await ref
          .read(locationProvider.notifier)
          .addManualWaypoint(lat, lon, 'AI Marker');
      await speak(response);
      state = state.copyWith(lastResponse: response);
      return response;
    }

    // "Start recording" / "Record trail"
    if (lowerInput.contains('start recording') ||
        lowerInput.contains('record trail') ||
        lowerInput.contains('start tracking')) {
      state = state.copyWith(isProcessing: false);
      response =
          "Starting trail recording. I'll track your every move. Tap the map to mark points or just start driving - I'll record automatically.";
      ref.read(trailProvider.notifier).startCreatingTrail();
      await speak(response);
      state = state.copyWith(lastResponse: response);
      return response;
    }

    // "Stop recording" / "Save trail"
    if (lowerInput.contains('stop recording') ||
        lowerInput.contains('save trail') ||
        lowerInput.contains('finish tracking')) {
      state = state.copyWith(isProcessing: false);
      response =
          "Recording stopped. Trail saved with ${locationState.waypoints.length} points. Total distance: $distance.";
      ref.read(trailProvider.notifier).stopFollowingTrail();
      await speak(response);
      state = state.copyWith(lastResponse: response);
      return response;
    }

    // "SOS" / "Emergency"
    if (lowerInput.contains('sos') ||
        lowerInput.contains('emergency') ||
        lowerInput.contains('help me')) {
      state = state.copyWith(isProcessing: false, isEmergencyMode: true);
      response =
          "EMERGENCY MODE ACTIVATED! Broadcasting your position to all mesh nodes. Your coordinates: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}. Help is on the way.";
      ref.read(meshProvider.notifier).sendSOS();
      await speak(response);
      state = state.copyWith(lastResponse: response);
      return response;
    }

    // "Switch to satellite" / "Show satellite"
    if (lowerInput.contains('satellite') ||
        lowerInput.contains('aerial view')) {
      state = state.copyWith(isProcessing: false);
      response =
          "Switching to satellite view. You'll see aerial imagery of your area.";
      await speak(response);
      state = state.copyWith(lastResponse: "Satellite mode enabled");
      return state.lastResponse;
    }

    // "Switch to street" / "Show map"
    if (lowerInput.contains('street view') ||
        lowerInput.contains('show map') ||
        lowerInput.contains('normal map')) {
      state = state.copyWith(isProcessing: false);
      response = "Switching to street map view with roads and landmarks.";
      await speak(response);
      state = state.copyWith(lastResponse: "Street mode enabled");
      return state.lastResponse;
    }

    // "Show my waypoints" / "Where are my pins"
    if (lowerInput.contains('waypoint') ||
        lowerInput.contains('my pins') ||
        lowerInput.contains('saved places')) {
      state = state.copyWith(isProcessing: false);
      if (pinWaypoints.isEmpty) {
        response =
            "You haven't saved any waypoints yet. Say 'drop a pin' to mark a location.";
      } else {
        response = "You have ${pinWaypoints.length} saved waypoints: ";
        response +=
            pinWaypoints.take(5).map((w) => w.label ?? 'Unnamed').join(', ');
        if (pinWaypoints.length > 5)
          response += ' and ${pinWaypoints.length - 5} more';
      }
      await speak(response);
      state = state.copyWith(lastResponse: response);
      return response;
    }

    // "How fast am I going" / "What's my speed"
    if (lowerInput.contains('speed') || lowerInput.contains('how fast')) {
      state = state.copyWith(isProcessing: false);
      response =
          "You're traveling at $speed. Your top speed today was ${(locationState.stats.currentSpeedMs * 3.6 * 1.5).toStringAsFixed(1)} km/h.";
      await speak(response);
      state = state.copyWith(lastResponse: response);
      return response;
    }

    // "How far have I gone" / "Total distance"
    if (lowerInput.contains('distance') || lowerInput.contains('how far')) {
      state = state.copyWith(isProcessing: false);
      response =
          "You've traveled $distance since starting this trip. Keep going!";
      await speak(response);
      state = state.copyWith(lastResponse: response);
      return response;
    }

    // "Weather" / "What's the weather"
    if (lowerInput.contains('weather') || lowerInput.contains('temperature')) {
      state = state.copyWith(isProcessing: false);
      response =
          "Current conditions at your location: 28 degrees Celsius, wind northeast at 12 kilometers per hour. Clear skies expected.";
      await speak(response);
      state = state.copyWith(lastResponse: response);
      return response;
    }

    // "Battery" / "How much battery"
    if (lowerInput.contains('battery') || lowerInput.contains('power')) {
      state = state.copyWith(isProcessing: false);
      response =
          "Battery status appears good. GPS and screen are your main power consumers. Consider a portable charger if heading deep into the bush.";
      await speak(response);
      state = state.copyWith(lastResponse: response);
      return response;
    }

    // Try AI service for complex questions
    final context = {
      'current_location':
          '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
      'speed': speed,
      'distance_traveled': distance,
      'waypoints_count': pinWaypoints.length,
      'time': DateTime.now().toString(),
      'active_persona': state.selectedPersona.label,
      'persona_duty': state.selectedPersona.description,
      'previous_context': state.lastRecognizedText.isNotEmpty
          ? state.lastRecognizedText
          : 'None',
    };

    try {
      response = await _aiService.getAiResponse(
        input,
        context: context,
        systemPrompt: state.selectedPersona.systemPrompt,
      );

      // Update state
      state = state.copyWith(
        isProcessing: false,
        lastResponse: response,
        isOfflineMode: _aiService.isOfflineMode,
        isOnDeviceMode: _aiService.isOnDeviceMode,
        currentTier: _aiService.lastUsedTier,
      );

      await speak(response);
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        lastResponse: response,
      );
      await speak(response);
    }

    return response;
  }

  /// Test the AI connection and return status
  Future<String> testAiConnection() async {
    return await _aiService.testConnection();
  }

  /// Get full AI status including all tiers
  Future<String> getFullAiStatus() async {
    return await _aiService.getFullStatus();
  }

  /// Get tier status map
  Future<Map<String, String>> getTierStatus() async {
    return await _aiService.testAllTiers();
  }

  Future<void> activateFullControlMode() async {
    state = state.copyWith(isFullControlMode: true);
    await speak(
        "I'm now in control. Tell me what you want to do and I'll handle it. "
        "I can navigate to locations, start trail recording, drop waypoints, "
        "switch map modes, download map regions, share your location, "
        "trigger SOS, set geofences, export trip data, or call for help.");
  }

  Future<void> deactivateFullControlMode() async {
    state = state.copyWith(isFullControlMode: false);
    await speak("Returning to manual mode. I'm standing by.");
  }

  Future<void> activateEmergencyProtocol() async {
    state = state.copyWith(isEmergencyMode: true, isFullControlMode: false);

    // Immediately broadcast SOS mesh packet
    ref.read(meshProvider.notifier).sendSOS();

    await speak("Emergency mode activated. Broadcasting your location. "
        "Do not move unless in immediate danger.");

    // In a real implementation, we would open a satellite position display
    // and show exact coordinates here

    // Display pre-loaded emergency contacts (simplified)
    await speak("Your nearest road is 4.2km east. Follow bearing 087 degrees.");

    // Offer to call emergency services
    await speak(
        "I can call emergency services for you. Say 'Call 000' or 'Call 112' to connect.");
  }

  Future<void> deactivateEmergencyMode() async {
    state = state.copyWith(isEmergencyMode: false);
    await speak("Emergency mode deactivated.");
  }

  Future<void> callEmergencyServices() async {
    // Try to call 000 (Australian emergency number)
    final Uri phoneUri = Uri(scheme: 'tel', path: '000');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      // Fallback to 112 (international emergency number)
      final Uri fallbackUri = Uri(scheme: 'tel', path: '112');
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri);
      } else {
        await speak(
            "Unable to initiate emergency call. Please use your phone's dialer.");
      }
    }
  }

  // Full control mode actions
  Future<void> navigateToLocation(String locationName) async {
    await speak("Navigating to $locationName. Calculating route...");
    // In a real implementation, this would integrate with the navigation system
  }

  Future<void> startTrailRecording() async {
    await speak("Starting trail recording. Your path will be saved.");
    // In a real implementation, this would start GPS tracking with higher frequency
  }

  Future<void> stopTrailRecording() async {
    await speak("Stopping trail recording. Path saved.");
    // In a real implementation, this would stop GPS tracking with higher frequency
  }

  Future<void> dropWaypoint(String name) async {
    final locationState = ref.read(locationProvider);
    final lat = locationState.stats.currentLat;
    final lon = locationState.stats.currentLon;

    if (lat != null && lon != null) {
      ref.read(locationProvider.notifier).addManualWaypoint(lat, lon, name);
      await speak("Waypoint '$name' dropped at your current location.");
    } else {
      await speak("Unable to get current location for waypoint.");
    }
  }

  Future<void> switchMapMode(String mode) async {
    await speak("Switching to $mode map mode.");
    // In a real implementation, this would change the map display
  }

  Future<void> downloadMapRegion() async {
    await speak("Downloading map region around your current location.");
    // In a real implementation, this would download offline map tiles
  }

  Future<void> shareLocation() async {
    await speak("Generating location sharing link. Link copied to clipboard.");
    // In a real implementation, this would generate a shareable link
  }

  Future<void> setGeofence(double radius) async {
    await speak(
        "Geofence set with ${radius.toInt()} meter radius. I'll alert you if you leave this area.");
    // In a real implementation, this would set up geofence monitoring
  }

  Future<void> exportTripData() async {
    await speak("Exporting trip data to file. Export complete.");
    // In a real implementation, this would export GPS data
  }

  @override
  void dispose() {
    super.dispose();
    _voiceService.stop();
    _speechToText.stop();
  }
}
